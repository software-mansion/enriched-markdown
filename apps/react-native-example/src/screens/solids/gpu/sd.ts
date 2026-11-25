import tgpu, { d, std } from 'typegpu';

// The few primitives a code block can build a solid from, as `sd.*`.

const sphere = tgpu.fn(
  [d.vec3f, d.f32],
  d.f32
)((p, r) => {
  return std.length(p) - r;
});

const box = tgpu.fn(
  [d.vec3f, d.vec3f],
  d.f32
)((p, b) => {
  const q = std.abs(p) - b;
  return (
    std.length(std.max(q, d.vec3f())) +
    std.min(std.max(q.x, std.max(q.y, q.z)), 0)
  );
});

// Upright, `h` up and down from its centre.
const cylinder = tgpu.fn(
  [d.vec3f, d.f32, d.f32],
  d.f32
)((p, r, h) => {
  const q = std.abs(d.vec2f(std.length(p.xz), p.y)) - d.vec2f(r, h);
  return std.min(std.max(q.x, q.y), 0) + std.length(std.max(q, d.vec2f()));
});

// Upright, radius `r1` at the bottom and `r2` at the top.
const cone = tgpu.fn(
  [d.vec3f, d.f32, d.f32, d.f32],
  d.f32
)((p, h, r1, r2) => {
  const q = d.vec2f(std.length(p.xz), p.y);
  const k1 = d.vec2f(r2, h);
  const k2 = d.vec2f(r2 - r1, 2 * h);
  const ca = d.vec2f(
    q.x - std.min(q.x, std.select(r2, r1, q.y < 0)),
    std.abs(q.y) - h
  );
  const cb =
    q - k1 + k2 * std.clamp(std.dot(k1 - q, k2) / std.dot(k2, k2), 0, 1);
  const inside = cb.x < 0 && ca.y < 0;
  return (
    std.select(d.f32(1), d.f32(-1), inside) *
    std.sqrt(std.min(std.dot(ca, ca), std.dot(cb, cb)))
  );
});

// Lying flat, ring radius `big`, tube radius `small`.
const torus = tgpu.fn(
  [d.vec3f, d.f32, d.f32],
  d.f32
)((p, big, small) => {
  return std.length(d.vec2f(std.length(p.xz) - big, p.y)) - small;
});

// A minimum that melts the two surfaces together over `k`.
const smin = tgpu.fn(
  [d.f32, d.f32, d.f32],
  d.f32
)((a, b, k) => {
  const h = std.max(k - std.abs(a - b), 0);
  return std.min(a, b) - (h * h) / (4 * k);
});

export const sd = { sphere, box, cylinder, cone, torus, smin };
