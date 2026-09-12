# Adam character animation — 0.7.3

Four original illustrated atlases based on Adam’s approved character designs, with five registered poses per outfit: standing, rising, falling, crouched landing and victory. Art is in assets/characters/adam-{blue,orange,green,purple}-v4.png. The clothing has distinct garment designs, not palette substitutions. Built-in image_gen prompts are in CHARACTERS-073.json. The original photograph is not included.

The four 2172×724 source images use a uniform magenta key, removed in scripts/character.gdshader at rendering time; the source PNGs do not have transparent backgrounds. The runtime hue key preserves dark hair and the green/violet clothing, with edge spill suppression. Generated RGB checkerboard portrait previews are not used by the game.

Wardrobe.pose registers each frame to the feet; scale is shared across poses and all four outfits. Per-pose head anchors attach existing hats. Backpack recoloring is restricted to the torso band. Gameplay physics, collision widths, unlock thresholds and the 0.7.2 camera fix are unchanged. The existing lightweight squash/rotation accompanies the five drawn animation poses; this is not skeletal animation.

## Validation

Character atlas, UI, controller-menu, four-player progression and camera tests passed. Reviewed TV and phone menus and all twenty poses with alternate hats/backpacks. Android package validation is recorded in release notes.

Comparable desktop four-player workload (tests/benchmark_perf.gd), before / after:

- Scene update CPU median: 134.454 / 131.328 microseconds.
- Uncapped frame median: 5.648 / 5.009 ms.
- Uncapped p95: 8.241 / 8.206 ms.
- Draw calls: 187 / 187.
- Godot tracked static memory: 115.774 / 115.811 MiB; this excludes GPU texture memory and is not total process memory.

No physical Shield/Xiaomi tests were performed. The larger artwork adds texture storage; four RGBA atlases at source resolution are approximately 24 MiB before mipmaps, so stable desktop timings do not establish memory/thermal behavior on TV sticks.
