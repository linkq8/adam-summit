# Multiplayer performance — 0.8.19

60 FPS is the target, not a measured hardware guarantee. No Android TV device was attached during this change. A 60 FPS cap cannot establish a minimum frame rate.

## Measured comparison

Apple M1 Pro, Godot 4.7.2 editor, OpenGL Compatibility through Metal, 1920×1080 internal rendering, normal difficulty, low-detail mode off, VSync disabled, uncapped. Each fixture runs 360 frames, discards 120 warm-up frames, and measures the remaining 240. Frame intervals include the fixture's fixed physics advance and scene/render processing. Desktop scheduling and unrelated system work can affect tails. These are short controlled fixtures, not sustained thermal/device tests.

The baseline ran the unmodified public v0.8.18 project. The final renderer uses native consecutive atlas-rectangle commands and cached triangle submissions. Measurements are genuine single runs, not selected best-case values.

| First-stage fixture | Before median / p95 ms | After median / p95 ms | Before / after draw calls | Frames over 16.67 ms, before / after |
|---|---:|---:|---:|---:|
| Four players, 100% | 23.775 / 35.566 | 11.561 / 17.171 | 824 / 84 | 98.33% / 7.92% |
| Four players, 200%, simultaneous ink, shields, magnets and repeated weapon flashes | 32.104 / 38.261 | 14.738 / 19.837 | 1188 / 96 | 100% / 24.58% |

The stress fixture deliberately keeps ink active on every player and triggers a flash and particle burst every 30 frames. It exceeds ordinary attack-immunity constraints. The improvement is substantial, but the uncapped desktop tails do **not** meet a strict 60 FPS minimum. Adaptive resolution and Release binaries still need sustained measurement on the actual Shield and TV Stick models.

## Implementation

- One cached keyed terrain triangle batch per player pane; scroll by transform and invalidate for visibility, moving platforms, course changes and broken floors.
- Cached world-space durability marks; invalidate damage and debris correctly.
- Smooth vector triangles instead of numerous unbatchable antialiased line commands. Atlas images use adjacent native texture rectangles so C++ constructs their vertices.
- Separate cached ink layer, redrawn for a new seed, size, fade or expiry. Weapon flashes animate independently. Ink coverage and duration remain unchanged.
- Shared TV resolution budget, 1080p → 900p → 720p. Ignore startup and isolated loading stalls; respond to sustained near-target misses or severe low FPS. All racers retain their logical bounds, camera, input, physics and effects. Never infer recovery/headroom from capped FPS and raise resolution mid-race.
- Avoid horizontal contact math for surfaces outside the exact swept vertical collision interval. Preserve row ordering, continuous fractions and fall-through behavior. Skip unused spring-profile allocation on ordinary jumps.

Triangle submissions follow the [Godot RenderingServer API](https://docs.godotengine.org/en/4.7/classes/class_renderingserver.html#class-renderingserver-method-canvas-item-add-triangle-array). Android Release signing can use the [official export environment variables](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_android.html#environment-variables); no signing configuration is included here.

## Validation and reproduction

Physics equivalence: 104,580 exact ticks across 45 stage/difficulty cases and three endless cases, including four independently moving racers, item use, drops, springs and rescues. Existing race, pace, stage-layout, surprise, mud, camera, controller/UI and TV-world progression tests passed. New tests cover resolution changes without UI rebuilds or gameplay changes, FPS navigation, cached floor disappearance, durability updates, moving floors, independent ink/flash drawing and large adjacent ink seeds. Two visual review batches checked phone, four-player TV, ink, forest, summit, 900p layout and settings.

```sh
Godot --headless --path . --script tests/test_render_budget.gd -- --test
Godot --headless --path . --script tests/test_stage_cache.gd -- --test
Godot --path . --script tests/benchmark_multiplayer.gd -- --test
Godot --path . --script tests/benchmark_multiplayer.gd -- --test --stress-only --adaptive
```

For the physics oracle, save the previous `scripts/race_model.gd` under a local ignored `builds/` path, then run `tests/test_physics_equivalence.gd` with `--reference=res://builds/reference-race-model.gd`. Do not publish private build artifacts.

On an actual TV, enable **عرض FPS** in the game's settings and measure 2/3/4 players in every world, at 100% and 200%, including ink and simultaneous items. Record device/firmware, refresh rate, internal resolution, average FPS, p95/p99 frame time and sustained session duration. The overlay is useful for testing; screenshot-capture fixtures are not performance measurements.
