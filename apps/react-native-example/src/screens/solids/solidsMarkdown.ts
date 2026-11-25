export const PROMPT =
  'How do you draw a 3D shape with nothing but math? Show me.';

export const SOLIDS_MARKDOWN = `# Solids, from one function

Any solid can be one function: a point in, the distance to its surface out. That's a **signed distance function**. Each block below is one in TypeGPU, drawn on the GPU. Drag a solid to turn it, a number to change it.

## A sphere

The distance to a sphere is the distance to its centre, minus the radius. \`Sdf\` wraps it: a point and the time in, a distance out.

$$d(p) = |p| - r$$

\`\`\`typegpu
const sphere = Sdf((p, t) => {
  return std.length(p) - 1;
});
\`\`\`

## A pawn

Solids add up. A *smooth minimum* melts two surfaces together where they meet, so a pawn is a disc, a rim, a cone, a ring and a ball from \`sd\`, one line each. It takes shape as the code arrives.

$$\\operatorname{smin}(a, b) = \\min(a, b) - \\frac{h^2}{4k}$$

\`\`\`typegpu
const pawn = Sdf((p, t) => {
  const y = d.vec3f(0, 1, 0);
  let s = sd.cylinder(p + y, 0.62, 0.08);
  const rim = sd.torus(p + y * 0.86, 0.5, 0.1);
  s = sd.smin(s, rim, 0.08);
  const body = sd.cone(p + y / 3, 0.5, 0.4, 0.1);
  s = sd.smin(s, body, 0.16);
  const ring = sd.torus(p - y / 5, 0.24, 0.07);
  s = sd.smin(s, ring, 0.06);
  const head = sd.sphere(p - y * 0.6, 0.34);
  s = sd.smin(s, head, 0.1);
  return s;
});
\`\`\`

## The Mandelbulb

The Mandelbrot set's 3D cousin. Raise a point to the 8th power in spherical coordinates, add where it started, repeat. A few lines, endless detail. \`trap\` keeps how close each point's orbit came to the centre, and the deepest parts glow.

$$z \\mapsto z^8 + p$$

\`\`\`typegpu
const mandelbulb = Sdf((p, t) => {
  const n = 8 + std.sin(t * 0.4) * 1.5;
  let z = d.vec3f(p);
  let dr = d.f32(1);
  let r = d.f32(0);
  for (let i = 0; i < 8; i++) {
    r = std.length(z);
    if (r > 2) {
      break;
    }
    trap.$ = std.min(trap.$, r);
    const th = std.acos(z.y / r) * n;
    const ph = std.atan2(z.x, z.z) * n;
    dr = std.pow(r, n - 1) * n * dr + 1;
    const s = std.sin(th);
    const dir = d.vec3f(
      s * std.sin(ph),
      std.cos(th),
      s * std.cos(ph),
    );
    z = dir * std.pow(r, n) + p;
  }
  return (0.5 * std.log(r) * r) / dr;
});
\`\`\`

Every solid here is a code block in one markdown answer. Enriched Markdown hands each \`typegpu\` fence to a component, TypeGPU compiles it to WGSL on the device, and WebGPU draws it.
`;
