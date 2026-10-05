# Multiplayer performance — 0.8.20

The user reported that 0.8.19 still felt unsatisfactory on NVIDIA Shield. No FPS, player count or exact workload was supplied, and no Android TV was attached for profiling. This change reduces measured recurring CPU work; it does not certify 60 FPS on Shield or Xiaomi hardware.

## Implementation

- Cache monotonically ordered platform depths. Two binary searches delimit the rows near each camera. Only the current/previous window is visited each frame so rows leaving the screen are hidden; distant rows remain untouched. Include the maximum branch offset in the margin. Rebuild the cache for a new course or endless rebase, and synchronize a course change occurring after the process callback before drawing.
- Replace up to 145 freshly generated circle/ellipse vertices with a four-vertex quad sampling a shared 160×128 alpha-mask texture. Its white patch also serves other vector triangles, preserving their ordering in the existing submission. Mipmaps retain small-circle antialiasing. No character or terrain images are rescaled or replaced.
- Cache arc geometry and index offsets within bounded dictionaries. Native packed-array transforms move the prepared vertices rather than rebuilding each segment in GDScript. Colors, stroke width and edge feathering remain attached to their geometry.
- Model, input, speed, quality controller and camera rules are unchanged. Both Android and game update versions advance to 0.8.20/build 36. Android uses the same Release template and signing certificate for upgrade compatibility.

## Controlled desktop measurements

Apple M1 Pro, Godot 4.7.2 editor, OpenGL Compatibility through Metal, 1920×1080 internal rendering, normal difficulty, low detail off, VSync disabled, uncapped. Same fixtures as 0.8.19: 360 frames, discard 120, measure 240, frame timer includes the fixed physics advance. Actual before measurements were taken from unmodified 0.8.19 in this session; hardware scheduling differs from the previous release's measurements. No cherry-picking or device extrapolation.

| Four-player first-stage fixture | Before median / p95 / p99 ms | After median / p95 / p99 ms | Frames >16.67 ms before / after |
|---|---:|---:|---:|
| 100% | 9.501 / 13.937 / 15.982 | 7.656 / 11.060 / 12.580 | 0.833% / 0% |
| 200%, simultaneous ink/shields/magnets and repeated weapon flash/bursts | 11.370 / 16.092 / 18.138 | 9.539 / 12.938 / 18.797 | 3.75% / 1.25% |

Draw calls remain 84 and 96 respectively. The stress fixture exceeds ordinary attack-immunity constraints. Stress p99 is still over budget and did not improve; the sample is short and cannot establish sustained minimum 60 FPS.

CPU instrumentation around actual `_process`/`_draw` callbacks sums the four stage medians after 120 warm-up frames; the fixed physics advance is timed separately. All values below are microseconds. It changes measurement overhead equally before and after, and is separate from the frame benchmark.

| World stage | Four-stage update before / after | Four-stage draw preparation before / after |
|---|---:|---:|
| First stage | 1112 / 503 | 3360 / 1791 |
| Clouds | 861 / 419 | 1488 / 1052 |
| Forest | 908 / 397 | 1429 / 1004 |

## Validation and reproduction

`test_visible_rows.gd` compares the optimized visibility to a full-platform scan at 359 positions/teleports across all 15 chapters and an endless rebase, including moving platforms and branches and the transition from a 121-floor chapter to shorter ones. `test_canvas_batch.gd` checks translated arc topology/colors, cache limits and valid index offsets after clearing. Existing cache, extended course, camera, quality budget, UI, speed, surprise, endless and four-player world-progression tests passed. Physics model bytes match 0.8.19. A batched visual comparison checked phone, four-player TV, ink/shield, forest and summit; only tiny vector edge changes were present.

```sh
Godot --headless --path . --script tests/test_visible_rows.gd -- --test
Godot --headless --path . --script tests/test_canvas_batch.gd -- --test
Godot --path . --script tests/benchmark_multiplayer.gd -- --first-only --test
```

Next hardware validation: enable the in-game FPS overlay and record actual player count, game speed, world, internal resolution and sustained frame times on the specific Shield/TV Stick. Continue optimizing based on that evidence; do not equate a 60 FPS cap with a 60 FPS minimum.
