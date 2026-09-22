// MORT cloud bank — fragment shader.
//
// Renders one drifting cloud layer: dark irregular storm/dust banks whose
// UPPER edges catch a silver light. Four instances are loaded per scene
// (one per layer); each layer's look is driven entirely by uniforms,
// matching the float-slot contract in
// `lib/core/atmosphere/mort_cloud_shader.dart`:
//
//   0 uTime        seconds since scene start
//   1 uResolutionX scene width in px
//   2 uResolutionY scene height in px
//   3 uDrift       signed horizontal drift in px/sec
//   4 uDensity     0..1 coverage control
//   5 uPeakAlpha   max alpha for this layer (profile + spec already applied)
//   6 uBandY       0..1 vertical center of the cloud band
//   7 uBandHeight  0..1 vertical extent of the band
//   8 uTintR       layer tint red   (0..1)
//   9 uTintG       layer tint green (0..1)
//  10 uTintB       layer tint blue  (0..1)
//  11 uLift         scene brightness lift off pure black
//  12 uQuality      1 = low-complexity mode (fewer octaves, no warp)
//  13 uLayerSeed    per-layer noise offset so layers never repeat
//
// Screen space: FlutterFragCoord origin is TOP-LEFT, so "screen-up" is
// -uv.y. Silver light falls from above onto the upper boundary of each
// mass. Output is premultiplied alpha, as Flutter expects.

#include <flutter/runtime_effect.glsl>

uniform float uTime;
uniform float uResolutionX;
uniform float uResolutionY;
uniform float uDrift;
uniform float uDensity;
uniform float uPeakAlpha;
uniform float uBandY;
uniform float uBandHeight;
uniform float uTintR;
uniform float uTintG;
uniform float uTintB;
uniform float uLift;
uniform float uQuality;
uniform float uLayerSeed;

out vec4 fragColor;

float hash21(vec2 p) {
  p = fract(p * vec2(234.34, 435.345));
  p += dot(p, p + 34.23);
  return fract(p.x * p.y);
}

float valueNoise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);
  float a = hash21(i);
  float b = hash21(i + vec2(1.0, 0.0));
  float c = hash21(i + vec2(0.0, 1.0));
  float d = hash21(i + vec2(1.0, 1.0));
  return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p, int octaves) {
  float v = 0.0;
  float amp = 0.5;
  for (int i = 0; i < 5; i++) {
    if (i >= octaves) break;
    v += amp * valueNoise(p);
    p = p * 2.03 + vec2(17.7, 9.2);
    amp *= 0.5;
  }
  return v;
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 uv = fragCoord / vec2(max(uResolutionX, 1.0), max(uResolutionY, 1.0));
  float aspect = uResolutionX / max(uResolutionY, 1.0);

  // Horizontal drift in uv units, seeded per layer so stacks never align.
  float driftOffset = uDrift * uTime / max(uResolutionX, 1.0);
  float x = uv.x * aspect + driftOffset + uLayerSeed * 13.17;
  float y = uv.y + uLayerSeed * 7.31;

  bool lowQuality = uQuality > 0.5;
  int massOctaves = lowQuality ? 3 : 5;
  int edgeOctaves = lowQuality ? 2 : 4;

  // Storm/dust coordinates: features stretched wide (y compressed hard)
  // and domain-warped so boundaries shear into ragged, irregular banks
  // instead of round fog blobs. The warp is cheap (2 octaves) and is the
  // first thing dropped in low-quality mode.
  vec2 p = vec2(x * 1.6, y * 4.2);
  if (!lowQuality) {
    float wx = fbm(p * 0.9 + vec2(3.1, 7.7), 2);
    float wy = fbm(p * 0.9 + vec2(9.4, 1.3), 2);
    p += (vec2(wx, wy) - 0.5) * 0.85;
  }

  // Cloud masses.
  float n = fbm(p, massOctaves);

  // Higher density -> lower threshold -> more coverage.
  float threshold = mix(0.78, 0.45, clamp(uDensity, 0.0, 1.0));
  float edge = threshold + 0.28;
  float mass = smoothstep(threshold, edge, n);
  float alpha = mass * clamp(uPeakAlpha, 0.0, 1.0);

  // Soft vertical envelope around the band (applied after the mass test
  // only to alpha, so shapes keep their silhouette inside the band).
  float halfBand = max(uBandHeight * 0.5, 1e-3);
  float dist = abs(y - uBandY) / halfBand;
  float bandEnvelope = exp(-dist * dist * 1.8);
  alpha *= bandEnvelope;

  if (alpha <= 0.003) {
    fragColor = vec4(0.0);
    return;
  }

  // Silver-lit UPPER edge: re-sample the field slightly screen-up; where
  // this pixel is inside the mass but the mass above has ended, the top
  // boundary catches the light. Light strength falls off toward the
  // bottom of the screen.
  float upStep = 0.035 + 0.02 * mass;
  float nUp = fbm(p + vec2(0.0, -upStep), edgeOctaves);
  float massUp = smoothstep(threshold, edge, nUp);
  float topEdge = clamp(mass - massUp, 0.0, 1.0);
  float lightFall = 1.0 - uv.y * 0.35;

  // Interior: the layer tint (graphite/night) with the global black lift.
  vec3 base = vec3(uTintR, uTintG, uTintB) + vec3(uLift);
  // Silver edge: fixed polish-silver, strongest where the boundary is
  // hard (mass 1 -> massUp 0), softly feathered into the interior.
  vec3 silver = vec3(0.72, 0.76, 0.82);
  vec3 color = mix(base, silver, topEdge * 0.55 * lightFall);

  // Dust grain: fine granular modulation so the bank reads as storm
  // dust, never as smooth fog.
  float grain = valueNoise(p * 11.0 + vec2(x * 0.7, 0.0));
  color *= 0.88 + 0.24 * grain;

  fragColor = vec4(color * alpha, alpha);
}
