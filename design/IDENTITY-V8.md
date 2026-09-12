# Restore Adam's photographic likeness

Local development after atlas v7; no new APK or GitHub release is implied.

The v7 character accumulated facial stylization across edits: oversized eyes, rounded cheeks and sculpted curls. This revision returns to the original user-supplied photograph as the authoritative identity reference, with the earlier v3 naturalistic portrait as a finish reference. A first atlas correction was rejected internally because it remained too cartoon-like. A new full-size identity master was generated directly from the original photo, then used to generate the production atlas. Each clothing variant also received the original photo directly.

The resulting four `assets/characters/adam-*-v8.png` files preserve natural facial proportions, almond eyes, black wavy hair and the recognizable smile. Adam looks toward travel. Compact feet, overhead fist, seven jump phases, idle and victory remain. Hats remain removed.

Each source is 1024×1536, with three columns and three rows. Normalized sole anchors were remeasured per outfit. A 12-pixel gutter adjustment between descent and victory preserves the victory fist without leaking it into the preceding frame. Generated pixels are unchanged; region selection and magenta removal occur in the existing renderer. Old v7 assets remain archived but are excluded from exports.

The original photograph remains outside the project. The generated identity master is `design/adam-v8/adam-identity-master.png`. Exact prompts for all attempts, master, production atlas and clothing variants are in [IDENTITY-V8.json](IDENTITY-V8.json); all images used built-in image_gen.

Validation: all 36 poses reviewed in-engine in `builds/characters-v8.png`. Character alignment, mirrored facing, controller-menu and UI/save tests passed. No physics changes, new features, package builds or public release in this revision. Likeness assessment is visual, not a claim of exact identity reproduction.
