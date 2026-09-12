# 0.7.1 performance and menu refinement

This release improves rendering cost and redesigns existing menus. It introduces no new gameplay features and changes no physics, rules, routes, or progression.

## Comparable benchmark

Both measurements use `tests/benchmark_perf.gd` on a desktop Apple M1 Pro, Godot Compatibility renderer, four play views and balanced 1080p rendering. The script opens a 1280×720 window, selects stage index 13 and uses the same workload before and after the changes.

| Metric | Before | After |
| --- | ---: | ---: |
| Four-view scene-update CPU median | 278.6658 µs | 130.2775 µs |
| Uncapped frame median | 16.570 ms | 3.970 ms |
| Uncapped frame p95 | 20.788 ms | 5.051 ms |
| Median draw calls per frame | 799 | 187 |
| Godot tracked static memory | 119.6457 MB | 115.7635 MB |

CPU time falls approximately 53%; median draw calls fall approximately 77%. These are observations from this desktop workload, not a prediction of physical-TV frame rate.

The CPU measurement disables automatic simulation and stage processing, then directly updates all four stages for seven batches of 1,200 iterations, reporting the median batch cost per iteration. The frame test restores stage processing, disables the frame cap and VSync, advances the model with four autopilots for 420 frames, discards the first 120 and summarizes 300 samples. Memory is `OS.get_static_memory_usage()` divided by 1,048,576, not total process, GPU or system memory. The normal game remains capped at 60 FPS.

## Rendering changes

- Static terrain textures, atlas regions, scale and offsets are configured once per model. Per-frame work retains camera-relative movement and visibility checks.
- Outfit styling, sprite regions and hat drawing update only when the relevant selection or animation pose changes.
- `assets/ui/game-icons.svg` supplies shared atlas regions for repeated star, flower and power-symbol drawing, reducing procedural draw commands.
- Menu and world artwork load when needed. Starting a race clears menu nodes and releases the application's artwork references; this does not assert immediate driver-memory reclamation.

## Menu changes

`assets/ui/menu-camp-v1.png` provides the painterly camp backdrop, while `assets/ui/world-islands-v1.png` supplies five world previews. Runtime crop bounds isolate each island. Phone backgrounds preserve aspect ratio while covering the available area. Lalezar titles and Vazirmatn body text provide a consistent Arabic hierarchy; both are bundled with OFL licensing.

The redesign retains the existing adventure, world, player, wardrobe, difficulty, cooperation, settings and tutorial actions. TV focus and controller navigation remain part of the interface. The reference and design rationale are recorded in [DESIGN.md](../DESIGN.md), and image-generation prompts in [ART-080.md](ART-080.md).

## Verification and limits

The coordinating implementation and review passes reported successful UI, controller, simulation and feature tests, plus four-player route checks. The visual reviewer confirmed that all material fixes were resolved with no open visual issues. A network-test cleanup warning appeared at exit; this record does not claim a zero-leak run.

No physical NVIDIA Shield or Xiaomi TV hardware was tested. Desktop results do not certify sustained performance, thermals, controller interoperability or frame pacing on those devices. Earlier emulator and package evidence in the project remains historical; this document does not claim new 0.7.1 Android, macOS or iOS builds, signing, installation or publication. Release packaging and device validation must be reported from their own completed checks.

## Android package verification

The 0.7.1 debug APK was exported successfully with versionCode 10 for arm64-v8a and armeabi-v7a. Archive integrity and Android signature verification passed; both new font licenses are bundled. Package size: 83,609,809 bytes. SHA-256: `bcbc75f751be3c655a39151fa00883402d2af362985a369b65bf1ad16b056d83`. Installation and physical-device measurements for this build remain unverified.
