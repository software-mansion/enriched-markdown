import tgpu, { d, std, type TgpuFn } from 'typegpu';

export type Shape = TgpuFn<(p: d.Vec3f, t: d.F32) => d.F32>;

// Everything the shader reads per frame, as vec4s so the layout is plain:
// eye.w is the time, right.w the reveal (0 to 1), up.w the aspect ratio,
// forward.w the focal length, tint.w the radius the solid fits in, probe a
// point on the surface the CPU found (w is how strongly it shows).
export const Scene = d.struct({
  eye: d.vec4f,
  right: d.vec4f,
  up: d.vec4f,
  forward: d.vec4f,
  tint: d.vec4f,
  probe: d.vec4f,
});
export const SCENE_FLOATS = 24;

// The numbers in a code block, live: each literal reads its own slot, so
// dragging one only writes this buffer.
export const KNOBS = 32;

export const layout = tgpu.bindGroupLayout({
  scene: { uniform: Scene },
  knobs: { uniform: d.arrayOf(d.vec4f, KNOBS / 4) },
});

// An orbit trap a solid can write as it goes: how close its point came to
// the centre. The surface is coloured by it; 1 leaves the tint as it is.
export const trap = tgpu.privateVar(d.f32, 1);

const STEPS = 110;
const FAR = 9;

const vertex = tgpu.vertexFn({
  in: { vid: d.builtin.vertexIndex },
  out: { pos: d.builtin.position, uv: d.vec2f },
})((input) => {
  const corners = [d.vec2f(-1, -1), d.vec2f(3, -1), d.vec2f(-1, 3)];
  const uv = corners[input.vid];
  return { pos: d.vec4f(uv, 0, 1), uv };
});

// A cosine palette: the surface takes its colour from where it faces.
const palette = tgpu.fn(
  [d.f32, d.vec3f],
  d.vec3f
)((x, tint) => {
  const phase = d.vec3f(0, 0.33, 0.67);
  return std.mix(tint, std.cos((phase + x) * 6.2831) * 0.5 + 0.5, d.f32(0.35));
});

/**
 * The raymarcher around a solid from a code block. The solid is cut by a
 * plane that sweeps up as it is revealed, glowing where it slices through.
 */
export function raymarcher(shape: Shape) {
  const map = tgpu.fn(
    [d.vec3f],
    d.f32
  )((p) => {
    const scene = layout.$.scene;
    const radius = scene.tint.w;
    const cut = std.mix(-radius - 0.05, radius + 0.05, scene.right.w);
    return std.max(shape(p, scene.eye.w), p.y - cut);
  });

  const normalAt = tgpu.fn(
    [d.vec3f],
    d.vec3f
  )((p) => {
    const k = d.f32(0.0009);
    const a = d.vec3f(k, -k, -k);
    const b = d.vec3f(-k, -k, k);
    const c = d.vec3f(-k, k, -k);
    const e = d.vec3f(k, k, k);
    return std.normalize(
      a * map(p + a) + b * map(p + b) + c * map(p + c) + e * map(p + e)
    );
  });

  const softShadow = tgpu.fn(
    [d.vec3f, d.vec3f],
    d.f32
  )((origin, dir) => {
    let lit = d.f32(1);
    let t = d.f32(0.02);
    for (let i = 0; i < 40; i++) {
      const h = map(origin + dir * t);
      lit = std.min(lit, (8 * h) / t);
      t += std.clamp(h, 0.02, 0.2);
      if (lit < 0.004 || t > 4) {
        break;
      }
    }
    return std.clamp(lit, 0, 1);
  });

  const occlusion = tgpu.fn(
    [d.vec3f, d.vec3f],
    d.f32
  )((p, n) => {
    let dark = d.f32(0);
    let weight = d.f32(1);
    for (let i = 1; i < 6; i++) {
      const h = d.f32(i) * 0.06;
      dark += (h - map(p + n * h)) * weight;
      weight *= 0.7;
    }
    return std.clamp(1 - 1.6 * dark, 0, 1);
  });

  const shade = tgpu.fn(
    [d.vec3f, d.vec3f],
    d.vec3f
  )((p, ray) => {
    const scene = layout.$.scene;
    const tint = scene.tint.xyz;
    const n = normalAt(p);
    trap.$ = 1;
    shape(p, scene.eye.w);
    const k = trap.$;
    const key = std.normalize(d.vec3f(0.6, 0.9, 0.4));
    const diffuse =
      std.max(std.dot(n, key), 0) * softShadow(p + n * 0.002, key);
    const ao = occlusion(p, n);
    const halfway = std.normalize(key - ray);
    const spec = std.pow(std.max(std.dot(n, halfway), 0), 40) * diffuse;
    const fresnel = std.pow(1 - std.max(std.dot(n, -ray), 0), 3);
    let base =
      tint *
      (0.55 +
        0.45 * palette(std.dot(n, d.vec3f(0.3, 0.6, 0.2)) + p.y * 0.3, tint));

    // Deep in the orbit trap the surface turns to embers, glowing in shadow.
    const outer = std.smoothstep(0.7, 0.95, k);
    const ember = d.vec3f(1, 0.3, 0.06);
    base = std.mix(ember, base, outer);

    let color = base * (0.08 + 1.05 * diffuse) * (0.35 + 0.65 * ao);
    color += base * d.vec3f(0.3, 0.35, 0.55) * (0.5 + 0.5 * n.y) * 0.35 * ao;
    color += d.vec3f(1, 0.97, 0.92) * spec * 0.9;
    color += std.mix(tint, d.vec3f(1, 1, 1), 0.35) * fresnel * 0.6 * ao;
    color += ember * (1 - outer) * 0.12;

    // Where a tap landed, as the CPU found it: a ring on the surface.
    const probe = scene.probe;
    const dp = std.length(p - probe.xyz);
    const ring =
      std.exp(-(dp - 0.09) * (dp - 0.09) * 3500) +
      std.exp(-dp * dp * 2500) * 0.9;
    // In TypeGPU's violet, so it reads on every solid's colour.
    color = std.mix(
      color,
      d.vec3f(0.42, 0.25, 1.2),
      std.min(ring, 1) * probe.w
    );

    // Where the reveal's plane slices the solid, the cut glows in the colour
    // of what it cuts through. The cut is a flat cap, so the glow is blended
    // in rather than added, and a whole cap never burns out to white.
    const r = scene.tint.w;
    const cut = std.mix(-r - 0.05, r + 0.05, scene.right.w);
    const edge =
      std.exp(-std.abs(p.y - cut) * 60) * (1 - scene.right.w * scene.right.w);
    const glow = std.min(base * 1.15 + 0.04, d.vec3f(1));
    return std.mix(color, glow, edge * 0.85);
  });

  // The solid as the floor mirrors it: lit and coloured by its trap, without
  // the shadows and occlusion a direct view pays for.
  const mirrored = tgpu.fn(
    [d.vec3f],
    d.vec3f
  )((p) => {
    const scene = layout.$.scene;
    const n = normalAt(p);
    trap.$ = 1;
    shape(p, scene.eye.w);
    const outer = std.smoothstep(0.7, 0.95, trap.$);
    const base = std.mix(d.vec3f(1, 0.3, 0.06), scene.tint.xyz, outer);
    const key = std.normalize(d.vec3f(0.6, 0.9, 0.4));
    return base * (0.12 + 0.88 * std.max(std.dot(n, key), 0));
  });

  // What the glossy floor shows of the solid from `q`, looking along `ray`
  // bounced up: nothing unless the bounce passes through the solid's sphere.
  const reflection = tgpu.fn(
    [d.vec3f, d.vec3f],
    d.vec3f
  )((q, ray) => {
    const scene = layout.$.scene;
    const mirror = d.vec3f(ray.x, -ray.y, ray.z);
    const radius = scene.tint.w * 1.3;
    const b = std.dot(q, mirror);
    const c = std.dot(q, q) - radius * radius;
    const disc = b * b - c;
    if (disc < 0) {
      return d.vec3f();
    }
    let t = std.max(-b - std.sqrt(disc), 0.02);
    const far = -b + std.sqrt(disc);
    for (let i = 0; i < 48; i++) {
      const p = q + mirror * t;
      const h = map(p);
      // Coarser than a direct view, so fine detail softens as on a floor
      // that is not quite a mirror.
      if (h < 0.004 + 0.01 * t) {
        return mirrored(p) * std.exp(-t * 1.1);
      }
      t += h;
      if (t > far) {
        break;
      }
    }
    return d.vec3f();
  });

  const fragment = tgpu.fragmentFn({
    in: { uv: d.vec2f },
    out: d.vec4f,
  })((input) => {
    const scene = layout.$.scene;
    const eye = scene.eye.xyz;
    const ray = std.normalize(
      scene.right.xyz * (input.uv.x * scene.up.w) +
        scene.up.xyz * input.uv.y +
        scene.forward.xyz * scene.forward.w
    );

    // The backdrop: a soft glow behind the solid, darker towards the corners.
    const glow = std.exp(-std.dot(input.uv, input.uv) * 1.4);
    let color = std.mix(
      d.vec3f(0.003, 0.0035, 0.007),
      d.vec3f(0.016, 0.015, 0.034),
      glow
    );

    // The floor under the solid catches its shadow, a little of its light and,
    // being glossy, its reflection.
    const floorY = -scene.tint.w - 0.12;
    if (ray.y < 0) {
      const tf = (floorY - eye.y) / ray.y;
      const q = eye + ray * tf;
      const fade = std.exp(-std.dot(q.xz, q.xz) * 0.35);
      const key = std.normalize(d.vec3f(0.6, 0.9, 0.4));
      const lit = softShadow(q, key);
      const gap = std.max(map(q), 0);
      const near = std.exp(-gap * 2.5);
      // Darker still where the solid all but touches it.
      const contact = std.mix(0.35, 1, std.smoothstep(0, 0.3, gap));
      // Glossy: the solid shows in it, more so at a glancing angle.
      const gloss = 0.3 + 0.4 * std.pow(1 + ray.y, 4);
      const floorColor =
        d.vec3f(0.02, 0.02, 0.038) * (0.3 + 0.7 * lit) * contact +
        scene.tint.xyz * near * 0.03 +
        reflection(q, ray) * gloss;
      color = std.mix(color, floorColor, fade * 0.9);
    }

    // Skip straight to the sphere the solid lives in, with room for the
    // corners of a box that fits the radius face to face.
    const radius = scene.tint.w * 1.3;
    const b = std.dot(eye, ray);
    const c = std.dot(eye, eye) - radius * radius;
    const disc = b * b - c;
    if (disc < 0) {
      return d.vec4f(std.pow(color, d.vec3f(0.4545)), 1);
    }
    let t = std.max(-b - std.sqrt(disc), 0);
    const far = std.min(-b + std.sqrt(disc), d.f32(FAR));
    let hit = false;
    for (let i = 0; i < STEPS; i++) {
      const h = map(eye + ray * t);
      if (h < 0.0005 * t) {
        hit = true;
        break;
      }
      t += h * 0.85;
      if (t > far) {
        break;
      }
    }
    if (hit) {
      color = shade(eye + ray * t, ray);
    }
    return d.vec4f(std.pow(color, d.vec3f(0.4545)), 1);
  });

  return { vertex, fragment };
}

export function resolveShader(shape: Shape) {
  const { vertex, fragment } = raymarcher(shape);
  return tgpu.resolve([vertex.$name('vs'), fragment.$name('fs')]);
}
