# 0.7.5 compact seven-phase jump

Four new 3×3 atlases (assets/characters/adam-*-v6.png) contain idle, seven jump poses and victory. Jump phases are takeoff, early rise, late rise, apex, early descent, landing approach and contact. Wardrobe.jump_frame selects these from vertical velocity and the existing contact squash timer. No physics or collision rules changed.

Feet stay close and nearly level under the torso, replacing the previous split-leg leap. Per-frame normalized feet and head anchors use grid-cell coordinates. Backpack color selection now uses local cell UV coordinates for all three rows. Hats keep per-frame position and mirrored facing. Obsolete v4/v5 atlases are excluded from packages.

Character tests verify all nine cells and the seven ordered jump phases. UI and four-player progression tests passed. All 36 poses were reviewed in-engine with wardrobe variants. Desktop rendering checks do not constitute physical-TV testing. Generated source backgrounds remain magenta and are removed by the character shader. Prompts: JUMP-075.json.
