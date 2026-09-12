# Approved side-facing jump

Local development change after 0.7.5; no new release has been published by this change.

The four `assets/characters/adam-*-v7.png` atlases preserve the approved compact legs and overhead fist, with Adam looking toward travel instead of the camera. Each 1254×1254 atlas has nine 418×418 cells: idle, seven jump phases, victory. Original generated pixels are preserved; magenta removal and backpack selection use the existing runtime shader. v6 atlases remain archived and are excluded from exports.

`Wardrobe.FOOT_ANCHORS` contains measured sole midpoints for all 36 cells. Both axes are registered to the actor origin; horizontal anchors mirror with facing. The existing jump selector, collision geometry, physics and camera remain unchanged. Head/hand positions and bent knees supply the visible motion while the shoe footprint remains compact.

Hat drawing, selection controls, unlock costs and saved fields are removed. Older hat fields are ignored on load and omitted on subsequent save, preserving other customization and progress. TV selection now has three controls per player (outfit, backpack, controller assignment), with focus preserved after each choice. The backpack yellow mask is tightened to avoid recoloring the side-facing cheeks.

Validation: character/sole alignment and mirrored facing; controller selection for all four players; UI unlock/persistence and legacy-hat save migration; camera regression. All passed. All 36 poses reviewed in-engine in `builds/characters-v7.png`. These are desktop checks, not physical TV or phone performance measurements.

Generation: built-in image_gen. Exact base and variant prompts are in [JUMP-V7.json](JUMP-V7.json). Approved review reference is retained in the conversation; generated assets are copied into the project. No original child photo is included in these assets or documentation.
