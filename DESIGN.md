# Adam’s Summit design and implementation

## v0.8.2 route choice and useful springs

The second and third stages of most worlds now place raised gold alternate landings beside the broad main route. Their height, spacing and three alternating widths make them faster when executed cleanly, while the wider main route remains the safer choice. Gold double chevrons identify only routes verified to save time; unmarked side branches still reward exploration with stars. Route and spring simulations cover every chapter and difficulty.

Spring launch speed is calculated from the current landing and a reachable target two or three platforms above. Each stage therefore uses a different launch height rather than the former global multiplier. The launch target can be a raised shortcut when it is reachable, and the control model keeps that target through the jump. Tests compare each chapter against ordinary jumps and require a material time saving. The spring artwork is upright in `assets/ui/surprise-items-v2.png`, with a horizontal base and vertical coil; subtle gold chevrons indicate its intended direction.

Touch platforms have a 86×76 action button for surprise multiplayer. It displays the held painted item, stays disabled while inventory is empty, does not capture the steering drag, and triggers the same balanced item logic as controller A. It is omitted from single-player because attack items have no valid opponent. Phone and tablet play otherwise remain single-player as previously specified.

## v0.8.1 visual effects

Surprise-race items use the hand-painted transparent atlas `assets/ui/surprise-items-v2.png`: chest, shield, ink bottle, sticky pod, upright spring and invisibility cloak. It preserves the storybook forest palette and remains readable in four-player TV splits. Collection, activation and impact show a short icon pulse; shield, boosted jumps and landing delays have distinct in-world markers.

Ink now renders above the character as nine seeded organic splats distributed across a three-by-three screen field. Smooth irregular outlines, satellite drops and drips approximate 40% coverage without fixed edge bands. The seed changes for each hit and remains stable during the 1.8-second effect. Reduced-effects mode uses fewer contour points while retaining coverage. Each world also has subtle low-cost ambient motes, and every HUD card has a colored climb-progress rail plus the held item's painted icon.

## v0.7.3 character artwork

Current character rendering uses four five-pose atlases under `assets/characters`, replacing the old two-row sheet. See [character implementation and measurements](design/CHARACTERS-073.md). Earlier asset descriptions below are historical.

## v0.7.1 menu and rendering refinement

The 0.7.1 release refines the existing menu and rendering without adding features or changing physics, rules, routes, or progression. A painterly camp scene places Adam and the adventure landscape opposite a clear Arabic action column on TV. World selection uses five illustrated island dioramas; player selection keeps the existing wardrobe and controller choices. Cream surfaces, dark teal ink (`#173f3e`), honey highlights and coral accents connect the menus to the game world. Phone backgrounds use aspect-preserving cover cropping.

Display text uses bundled Lalezar and body/control text uses bundled Vazirmatn, with OFL license files under `assets/fonts`. Original generated artwork lives at `assets/ui/menu-camp-v1.png` and `assets/ui/world-islands-v1.png`; the island atlas uses individual runtime crop bounds to prevent adjacent islands appearing in a preview. Prompts are retained in [ART-080.md](design/ART-080.md); its filename is an art-record identifier, not a release-version claim.

The [Mobbin reference](https://mobbin.com/screens/2656db04-1eb5-4568-9e7d-132256423855) and UI UX Pro Max recommendations informed the menu direction. The retro pixel-art recommendation was rejected in favor of the user's illustrated visual preference. The artwork is original generated imagery, not a reproduction of the reference.

Rendering now configures static terrain textures, crops and scale once per model, updates avatar styling and caps only when their inputs change, and uses a shared SVG icon atlas for repeated stars, flowers and power symbols. Menu artwork loads on demand; the application releases its references when a race starts. See [PERFORMANCE-071.md](design/PERFORMANCE-071.md) for the comparable benchmark and validation limits.

## Visual language

A warm illustrated climbing garden frames Adam, with blue (`#167a95`) and orange (`#cc6542`) costumes and dark teal (`#214c4e`) interface ink. Arabic text uses the bundled display and body fonts. Both players depict Adam; costume color differentiates them. Five worlds contain three stages each. The garden, cloud, ice, coast and luminous forest worlds use distinct background/platform artwork; routes and obstacle spacing vary across all fifteen stages.

Active artwork is `assets/garden-v2.png`, `assets/platform-v2.png` and `assets/adam-motion.png`. The character atlas contains four poses in two costume rows, selected for waiting, rising, falling and landing. Small rotation, squash and particles add motion; the reduced-motion/effects setting suppresses decorative motion. A chroma shader removes keyed backgrounds and shared mipmapped textures serve both players. The original portrait is excluded from exports.

## Layout and interaction

Portrait is the default mobile orientation. Phone, tablet and foldable layouts stay single-player, adapt to window size and account for mobile safe areas. A relative horizontal finger drag steers Adam anywhere below the top HUD. The footer displays a short drag hint; there are no movement buttons. Release, pause and resize clear the gesture. TV uses landscape and supports one centered playfield or up to four independently scrolling playfields. Android system television mode, not aspect ratio, selects the TV profile. Keyboard and controller focus complement touch interaction.

The UI separates lobby, tutorial, countdown, racing, pause, settings and result states. First-play onboarding combines an illustrated automatic jump explanation with bundled Arabic narration recorded from the Majed system voice. Music and effects have separate sliders. Backgrounding clears held input, pauses active play and stops sound. Controller disconnection pauses the race and permits replacement.

## Architecture and rendering

- `scripts/race_model.gd`: graphics-independent simulation, routes, collisions, automatic jumping, rescue/checkpoints, collection, finish timing and save snapshots. Physics runs at 60Hz.
- `scripts/main.gd`: application states, Arabic UI, input/device profile, layout, persistence and audio. Single-player progress is saved to `user://journey.json` at checkpoints, pauses and approximately five-second intervals.
- `scripts/stage.gd`: camera-relative stage rendering, atlas pose selection and effects. Offscreen platform sprites are hidden.
- `scripts/prepare_android.py`: prepares Android launcher behavior and Java television-mode detection. `getCommandLine` passes `--tv-device` into Godot.

Godot 4.7.2 uses the Compatibility renderer. Mobile `canvas_items` preserves native-resolution drawing. TV defaults to balanced 1080p rendering, with economical 720p and native-display options; fixed-resolution viewports follow aspect ratio. The frame cap is 60FPS. Lower internal resolution does not remove the OpenGL ES 3.0 requirement.

## Earlier validation and remaining device checks

The following measurements and package checks predate 0.7.1; current refinement evidence is recorded in [PERFORMANCE-071.md](design/PERFORMANCE-071.md). They do not establish that 0.7.1 packages have been built or distributed.

Earlier stage/difficulty simulation combinations and UI resize/save checks passed. Desktop TV reached the 60FPS cap with p95 approximately 16.7ms and tracked memory 119MB. Android software-emulator results were approximately 26FPS, p95 61.4ms and tracked memory 45MB; these are not physical-device benchmarks or total GPU/system memory measurements.

Android debug and macOS packages were built. iOS exported to Xcode, compiled for ARM64, and signed with the local development identity. Simulator launch failed for the built x64 template on the available Apple Silicon iOS 26.5 simulator. Real iPhone/iPad, foldable, Xiaomi, Shield and controller validation remains open.

First-generation Mi TV Stick is outside this renderer’s compatibility range because Mali-450 provides OpenGL ES 2.0. Newer Stick versions must be tested by exact model. Hardware performance, sustained thermals and controller interoperability are not certified.


The stage map scrolls vertically with three stage buttons per world, ordered right to left. Focus scrolling supports TV controllers. New coast/forest atlases share a material; only visible platforms draw. Soft crossing orbs have an outlined glossy silhouette; beach crabs and forest beetles replace snails in the new worlds. No screen flashes or punitive lives are added.

## v0.5 platforms

Every course has large, medium and small landing widths. One-use rose platforms and two-use gold platforms show cracks and one/two remaining-use dots; final contact still launches the character before removing the platform. Cracks/dots draw above the existing art; a brief debris animation accompanies collapse and is disabled in reduced-effects mode. Durability is independent per racer and persisted in snapshot v4. Rescue rebuilds the retried section, resetting the advanced climb target to its checkpoint; collectibles remain collected. Start/checkpoint/summit never break. Fragile surfaces do not also move or carry creatures, crossing orbs or springs. Older saves restore safely on the updated course.

## v0.6 content and cooperation

Three optional fork sections pay three stars per outer landing; narrow one-use branches reconnect to wide main platforms. Main and alternate routes are tested across all15 stages ×3 difficulties. Shield (12s/one hit), magnet (8s) and one-fall rescue bubble activate on collection and persist in save v5. Cooperative TV mode shares pickups/checkpoints/protection and waits for both finishers; race mode still ends on first arrival. Single-player in-progress save remains the only resumable mode.

World finales vary the last six jumps and summit silhouette: treehouse, cloud palace, ice spires, lighthouse, luminous tree. Wardrobe preview unlocks four outfit colors, three backpack choices and three hat choices from best-stage star totals without spending or purchases. Palette changes include the coordinated shirt star; caps attach to each animation pose. Five original procedural scores and surface-specific bounce/crack/crumble/power effects are generated by scripts/generate_world_audio.py. Low-effects mode still suppresses debris and celebration movement.

## v0.6.1 steering

No automatic lateral landing assistance. Five gate pairs alternate x170/x390 with150/140/128px widths by difficulty, leaving disjoint landing intervals including body allowance. Optional forks reconnect to the updated approaches; controlled main and bonus routes remain reachable. Idle simulations cover all15 stages and3 difficulties.


## Approved jump art, atlas v7 (local development)

Four v7 atlases now share the approved compact jump, raised fist above the head and gaze in the direction of travel. Nine cells contain idle, seven jump phases and victory. Per-outfit sole midpoints align both axes, including mirrored facing. Hats have been removed from rendering, wardrobe and TV player selection; legacy save fields are ignored without changing earned progress. See [JUMP-V7.md](design/JUMP-V7.md).

## Natural likeness correction, atlas v8 (local development)

The v7 facial style is superseded by four naturalistic v8 atlases derived directly from the original photo and a corrected full-size identity master. They retain the approved compact jump and overhead fist, with natural eye and facial proportions. See [IDENTITY-V8.md](design/IDENTITY-V8.md) for generation, frame registration and validation.
