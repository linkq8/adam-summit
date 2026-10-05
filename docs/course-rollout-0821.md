# Adventure course rollout 0.8.21

All 15 adventure chapters now use 120 rows, gravity 2400, launch speed 1200, character height 110.4, arena width 680, and zoom 0.9. At 100% pace the integrated normal jump rises about 290 units, reaching its apex in approximately 0.5 seconds.

Internal main landings are approximately 118-136 units wide; side landings 73-88. Row rises are 56-82 in the first chapter of a world, 60-86 in the second, and 64-90 in the third. Original chapter zero retains its approved layout exactly. Endless retains its independent geometry and physics.

Each chapter has its own deterministic seed shared by all racers. Two short opening bands require steering even if a jump skips rows; the remaining field spreads across the arena without repeating an S throughout the course. New alternate routes are bounded to 210 units from the previous and next main floor and previous alternate, allowing direction reversal. A hazard is omitted when a distinct permanent bypass cannot fit.

Mud occupies the central 32% of its landing and retains clear edges and a permanent alternative. Drop floors vanish on first contact without reversing downward velocity. Other breakable surfaces allow one or two bounces. Checkpoints and summits are permanent. Clouds/coast emphasize moving landings, ice/forest springs, and forest sticky traps. Boxes occupy rows 19/43/73/101, helpers 12/58/96, and flowers 22/62/103.

Snapshot version is 11. Chapter-zero v10 snapshots retain exact position. Older snapshots in changed chapters preserve proportional progress and collected reward counts, resuming safely without another rescue penalty. Old broken-floor state resets for the new layout.

## Validation

- All 45 chapter/difficulty cases reach the summit without rescue along permanent surfaces after every breakable main and alternate surface is removed. Creature collisions are disabled in this geometric test because their stun can deliberately make a careless rider miss. Ordinary route simulation separately exercises hazards.
- Chapter zero and endless match 0.8.20 geometry, physics and player states over 12,000 comparison ticks.
- No-input runs and parked-column trials cannot finish any chapter.
- Mud-edge/bypass, immediate drop, old/current saves, springs, four-player world progression, endless, camera, render cache/budget, UI and 80-200% pace tests passed.
- Visibility matches a full terrain scan in 681 cases.
- Visual review: phone cloud/ice chapters, two-player coast, four-player forest and summit.

## Local performance smoke test

Godot 4.7.2 Compatibility on Mac M1 Pro, internal 1920x1080 with adaptation disabled. 240 sampled frames after 120 warm-up frames per fixture. Player count and simulation progression are asserted. This is not a controlled comparison against the prior release, and does not confirm sustained 60 FPS on Shield or TV Stick. Neither target was connected. Existing adaptive resolution and rendering optimizations are retained.

| Players | Chapter (0-based) | Pace | Median ms | p95 ms | p99 ms | Frames over 16.7 ms |
|---|---|---|---|---|---|---|
| 2 | 0 | 100% | 4.814 | 6.835 | 7.852 | 0.00% |
| 3 | 0 | 100% | 6.448 | 10.466 | 12.173 | 0.00% |
| 4 | 0 | 100% | 6.884 | 7.268 | 7.364 | 0.00% |
| 4 | 3 | 100% | 6.897 | 7.094 | 7.267 | 0.00% |
| 4 | 6 | 100% | 6.880 | 7.239 | 7.366 | 0.00% |
| 4 | 9 | 100% | 6.886 | 7.172 | 7.341 | 0.00% |
| 4 | 12 | 100% | 6.881 | 7.309 | 7.419 | 0.00% |
| 4 | 0 | 200% | 6.900 | 8.211 | 11.961 | 0.42% |

The 200% fixture adds ink, shields, magnets and item flashes to every racer. Raw fixture results are in course-rollout-0821.json.
