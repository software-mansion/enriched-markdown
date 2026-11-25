import { useEffect, useMemo, useState } from 'react';
import {
  Dimensions,
  PixelRatio,
  StyleSheet,
  type ViewStyle,
} from 'react-native';
import { Gesture, GestureDetector } from 'react-native-gesture-handler';
import Animated, {
  Easing,
  measure,
  runOnJS,
  runOnUI,
  useAnimatedRef,
  useAnimatedStyle,
  useFrameCallback,
  useSharedValue,
  withDecay,
  withDelay,
  withSpring,
  withTiming,
  type AnimatedRef,
  type SharedValue,
} from 'react-native-reanimated';
import {
  Canvas,
  useCanvasRef,
  type RNCanvasContext,
} from 'react-native-webgpu';
import { KNOBS, SCENE_FLOATS } from './raymarch';

let devicePromise: Promise<GPUDevice> | null = null;

// One device for every solid on the screen.
function getDevice() {
  devicePromise ??= navigator.gpu.requestAdapter().then((adapter) => {
    if (!adapter) throw new Error('No GPU adapter');
    return adapter.requestDevice();
  });
  return devicePromise;
}

// What a solid keeps across shaders: its canvas, its buffers and the layout
// every shader it draws shares.
type Surface = {
  device: GPUDevice;
  context: RNCanvasContext;
  format: GPUTextureFormat;
  layout: GPUPipelineLayout;
  bindGroup: GPUBindGroup;
  scene: GPUBuffer;
  knobs: GPUBuffer;
};

type Shader = { pipeline: GPURenderPipeline; id: number };

export const RADIUS = 1.15;
const DISTANCE = 3.7;
const PITCH = 0.32;
// How fast an untouched solid turns, in radians a second.
const IDLE_SPIN = 0.32;
const FADE_MS = 260;
const REVEAL_MS = 1500;
// Never more than 2x: a raymarcher's cost grows with every pixel.
const SCALE = Math.min(PixelRatio.get(), 2);

let shaders = 0;

/**
 * A solid from a compiled code block, raymarched on the UI thread every frame
 * it is on screen. It fades in over the stage behind it once its first frame
 * is drawn, and its reveal starts then, however long the pipeline took. A new
 * shader, as the block grows, takes over from the old one without a gap.
 * `knobs` are the block's numbers. With no
 * shader yet, it sets up its canvas and waits, so the first one draws sooner.
 * Drag to turn it, it keeps turning with the drag's speed; pinch to come
 * closer; double tap to bring the camera back.
 */
export function SolidView({
  wgsl,
  tint,
  knobs,
  probe,
  onProbe,
  style,
}: {
  wgsl: string | null;
  tint: [number, number, number];
  knobs: SharedValue<number[]>;
  // A point on the surface to ring, xyz and how strongly, and where a tap
  // asks for one: the ray's origin and direction, and the solid's time.
  probe: SharedValue<number[]>;
  onProbe?: (ray: number[], time: number) => void;
  style?: ViewStyle;
}) {
  const ref = useCanvasRef();
  const frame = useAnimatedRef<Animated.View>();
  const [surface, setSurface] = useState<Surface | null>(null);
  const [shader, setShader] = useState<Shader | null>(null);
  const [size, setSize] = useState<{ width: number; height: number } | null>(
    null
  );
  const laidOut = size !== null;
  const aspect = useSharedValue(1);
  const yaw = useSharedValue(0.6);
  const pitch = useSharedValue(PITCH);
  const distance = useSharedValue(DISTANCE);
  const held = useSharedValue(false);
  const shown = useSharedValue(0);
  const reveal = useSharedValue(0);
  const started = useSharedValue(false);
  // When the first frame was drawn: the block's `t` counts from there, on
  // through every shader that follows.
  const epoch = useSharedValue(0);
  // The block's `t` as last drawn, so a tap asks about the solid on screen.
  const clock = useSharedValue(0);

  useEffect(() => {
    if (!laidOut) return;
    let cancelled = false;
    (async () => {
      const device = await getDevice();
      const context = ref.current?.getContext('webgpu');
      if (cancelled || !context) return;
      const format = navigator.gpu.getPreferredCanvasFormat();
      const uniform = (binding: number) => ({
        binding,
        visibility: GPUShaderStage.VERTEX | GPUShaderStage.FRAGMENT,
        buffer: { type: 'uniform' as const },
      });
      const group = device.createBindGroupLayout({
        entries: [uniform(0), uniform(1)],
      });
      const scene = device.createBuffer({
        size: SCENE_FLOATS * 4,
        usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
      });
      const knobsBuffer = device.createBuffer({
        size: KNOBS * 4,
        usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
      });
      setSurface({
        device,
        context,
        format,
        layout: device.createPipelineLayout({ bindGroupLayouts: [group] }),
        bindGroup: device.createBindGroup({
          layout: group,
          entries: [
            { binding: 0, resource: { buffer: scene } },
            { binding: 1, resource: { buffer: knobsBuffer } },
          ],
        }),
        scene,
        knobs: knobsBuffer,
      });
    })();
    return () => {
      cancelled = true;
    };
  }, [laidOut, ref]);

  useEffect(() => {
    if (!surface || !wgsl) return;
    let cancelled = false;
    (async () => {
      const { device, format, layout } = surface;
      const module = device.createShaderModule({ code: wgsl });
      const pipeline = await device.createRenderPipelineAsync({
        layout,
        vertex: { module, entryPoint: 'vs' },
        fragment: { module, entryPoint: 'fs', targets: [{ format }] },
        primitive: { topology: 'triangle-list' },
      });
      if (cancelled) return;
      warm(surface, pipeline);
      setShader({ pipeline, id: ++shaders });
    })();
    return () => {
      cancelled = true;
    };
  }, [surface, wgsl]);

  // The canvas keeps its pixels when the view changes size, so it is sized to
  // the layout, and again on every change, on the UI thread, which owns its
  // layer and draws to it.
  useEffect(() => {
    if (!surface || !size) return;
    const { context, device, format } = surface;
    const width = Math.round(size.width * SCALE);
    const height = Math.round(size.height * SCALE);
    runOnUI(() => {
      'worklet';
      const canvas = context.canvas as unknown as {
        width: number;
        height: number;
      };
      canvas.width = width;
      canvas.height = height;
      context.configure({ device, format, alphaMode: 'opaque' });
    })();
  }, [surface, size]);

  const gesture = useMemo(() => {
    const pan = Gesture.Pan()
      .activeOffsetX([-8, 8])
      .failOffsetY([-12, 12])
      .onBegin(() => {
        held.value = true;
      })
      .onChange((e) => {
        yaw.value -= e.changeX * 0.012;
        pitch.value = Math.min(
          1.2,
          Math.max(-0.5, pitch.value + e.changeY * 0.008)
        );
      })
      .onEnd((e) => {
        yaw.value = withDecay({
          velocity: -e.velocityX * 0.012,
          deceleration: 0.994,
        });
      })
      .onFinalize(() => {
        held.value = false;
      });
    const pinch = Gesture.Pinch().onChange((e) => {
      distance.value = Math.min(
        6,
        Math.max(2.2, distance.value / e.scaleChange)
      );
    });
    // A tap's ray through the camera, as the shader casts it.
    const tap = Gesture.Tap()
      .maxDuration(250)
      .onEnd((e) => {
        if (!onProbe || !size) return;
        const u = (e.x / size.width) * 2 - 1;
        const v = 1 - (e.y / size.height) * 2;
        const cp = Math.cos(pitch.value);
        const dist = distance.value;
        const ex = dist * cp * Math.sin(yaw.value);
        const ey = dist * Math.sin(pitch.value);
        const ez = dist * cp * Math.cos(yaw.value);
        const fx = -ex / dist;
        const fy = -ey / dist;
        const fz = -ez / dist;
        const rl = Math.hypot(fz, fx);
        const rx = -fz / rl;
        const rz = fx / rl;
        const ux = -rz * fy;
        const uy = rz * fx - rx * fz;
        const uz = rx * fy;
        const a = u * aspect.value;
        const dx = rx * a + ux * v + fx * 1.9;
        const dy = uy * v + fy * 1.9;
        const dz = rz * a + uz * v + fz * 1.9;
        const dl = Math.hypot(dx, dy, dz);
        runOnJS(onProbe)([ex, ey, ez, dx / dl, dy / dl, dz / dl], clock.value);
      });
    const reset = Gesture.Tap()
      .numberOfTaps(2)
      .onEnd(() => {
        pitch.value = withSpring(PITCH, { damping: 18 });
        distance.value = withSpring(DISTANCE, { damping: 18 });
      });
    return Gesture.Simultaneous(pan, pinch, Gesture.Exclusive(reset, tap));
  }, [distance, held, pitch, yaw, aspect, clock, onProbe, size]);

  const canvasStyle = useAnimatedStyle(() => ({
    opacity: shown.value,
  }));

  return (
    <GestureDetector gesture={gesture}>
      <Animated.View
        ref={frame}
        collapsable={false}
        style={[styles.frame, style]}
        onLayout={(e) => {
          const { width, height } = e.nativeEvent.layout;
          aspect.value = width / height;
          setSize({ width, height });
        }}
      >
        <Animated.View style={[StyleSheet.absoluteFill, canvasStyle]}>
          <Canvas ref={ref} style={StyleSheet.absoluteFill} />
        </Animated.View>
        {surface && shader && size && (
          <FrameLoop
            key={shader.id}
            surface={surface}
            pipeline={shader.pipeline}
            frame={frame}
            tint={tint}
            knobs={knobs}
            started={started}
            epoch={epoch}
            clock={clock}
            probe={probe}
            shown={shown}
            reveal={reveal}
            aspect={aspect}
            yaw={yaw}
            pitch={pitch}
            distance={distance}
            held={held}
          />
        )}
      </Animated.View>
    </GestureDetector>
  );
}

// Draws once off screen on the JS thread, so the driver finishes the shader
// here rather than on the UI thread's first frame with it.
function warm(surface: Surface, pipeline: GPURenderPipeline) {
  const { device, format, bindGroup } = surface;
  const target = device.createTexture({
    size: [4, 4],
    format,
    usage: GPUTextureUsage.RENDER_ATTACHMENT,
  });
  const encoder = device.createCommandEncoder();
  const pass = encoder.beginRenderPass({
    colorAttachments: [
      { view: target.createView(), loadOp: 'clear', storeOp: 'discard' },
    ],
  });
  pass.setPipeline(pipeline);
  pass.setBindGroup(0, bindGroup);
  pass.draw(3);
  pass.end();
  device.queue.submit([encoder.finish()]);
  target.destroy();
}

const SCREEN_HEIGHT = Dimensions.get('screen').height;

function FrameLoop({
  surface,
  pipeline,
  frame,
  tint,
  knobs,
  started,
  epoch,
  clock,
  probe,
  shown,
  reveal,
  aspect,
  yaw,
  pitch,
  distance,
  held,
}: {
  surface: Surface;
  pipeline: GPURenderPipeline;
  frame: AnimatedRef<Animated.View>;
  tint: [number, number, number];
  knobs: SharedValue<number[]>;
  started: SharedValue<boolean>;
  epoch: SharedValue<number>;
  clock: SharedValue<number>;
  probe: SharedValue<number[]>;
  shown: SharedValue<number>;
  reveal: SharedValue<number>;
  aspect: SharedValue<number>;
  yaw: SharedValue<number>;
  pitch: SharedValue<number>;
  distance: SharedValue<number>;
  held: SharedValue<boolean>;
}) {
  useFrameCallback((info) => {
    'worklet';
    // Off screen, the solid costs nothing.
    const box = measure(frame);
    if (!box || box.pageY > SCREEN_HEIGHT || box.pageY + box.height < 0) return;

    const dt = Math.min(info.timeSincePreviousFrame ?? 16, 50) / 1000;
    if (!held.value) yaw.value += IDLE_SPIN * dt;
    if (!started.value) epoch.value = info.timestamp;
    const time = (info.timestamp - epoch.value) / 1000;
    clock.value = time;
    const ring = probe.value;
    const cp = Math.cos(pitch.value);
    const dist = distance.value;
    const ex = dist * cp * Math.sin(yaw.value);
    const ey = dist * Math.sin(pitch.value);
    const ez = dist * cp * Math.cos(yaw.value);
    // forward looks at the origin; right is level; up completes the frame
    const fx = -ex / dist;
    const fy = -ey / dist;
    const fz = -ez / dist;
    const rl = Math.hypot(fz, fx);
    const rx = -fz / rl;
    const rz = fx / rl;
    const ux = -rz * fy;
    const uy = rz * fx - rx * fz;
    const uz = rx * fy;
    const { device, context, bindGroup, scene } = surface;
    device.queue.writeBuffer(
      scene,
      0,
      new Float32Array([
        ex,
        ey,
        ez,
        time,
        rx,
        0,
        rz,
        reveal.value,
        ux,
        uy,
        uz,
        aspect.value,
        fx,
        fy,
        fz,
        1.9,
        tint[0],
        tint[1],
        tint[2],
        RADIUS,
        ring[0] ?? 0,
        ring[1] ?? 0,
        ring[2] ?? 0,
        ring[3] ?? 0,
      ])
    );
    const values = new Float32Array(KNOBS);
    values.set(knobs.value.slice(0, KNOBS));
    device.queue.writeBuffer(surface.knobs, 0, values);
    const encoder = device.createCommandEncoder();
    const pass = encoder.beginRenderPass({
      colorAttachments: [
        {
          view: context.getCurrentTexture().createView(),
          loadOp: 'clear',
          storeOp: 'store',
          clearValue: [0, 0, 0, 1],
        },
      ],
    });
    pass.setPipeline(pipeline);
    pass.setBindGroup(0, bindGroup);
    pass.draw(3);
    pass.end();
    device.queue.submit([encoder.finish()]);
    context.present();

    if (!started.value) {
      started.value = true;
      shown.value = withTiming(1, { duration: FADE_MS });
      reveal.value = withDelay(
        FADE_MS,
        withTiming(1, {
          duration: REVEAL_MS,
          easing: Easing.inOut(Easing.cubic),
        })
      );
    }
  });
  return null;
}

const styles = StyleSheet.create({
  frame: {
    overflow: 'hidden',
  },
});
