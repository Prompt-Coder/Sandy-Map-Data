-- Zones for prompt_sandy_lod (values from the Sandy survey + harness tests, C:\temp\sandy_fps\RESULTS.md / VISUAL_DECISIONS.md).
-- ladder: {HD, ORPHANHD, LOD/SLOD1/SLOD2} per step (farlod v3.3); the last entry is native (the player's own settings).
-- zones: circles; inside several, the lowest step wins. day = 06:00-19:59, night = 20:00-05:59.
-- high (optional): step used while the camera is >= highAbove metres above the ground right under it (flying, high camera);
-- standing on a roof counts as the ground (the probe hits the roof).
SANDY_LOD_ZONES = {
  ladder = {
    { 1.0, 1.0, 1.0 },      -- 0  default distance for everyone
    { 1.0, 1.0, 1.375 },    -- 1
    { 1.0, 1.0, 1.75 },     -- 2  HD + standalone props at the default distance, LOD/far layer at full max distance
    { 1.0, 1.25, 1.75 },    -- 3
    { 1.25, 1.25, 1.75 },   -- 4  HD + props at 1.25, LOD layer full
    { 1.25, 1.5, 1.75 },    -- 5
    { 1.5, 1.5, 1.75 },     -- 6
    { 1.75, 1.75, 1.75 },   -- 7  full scale per level, lights at default distance
    { 1.75, 1.75, 1.75 },   -- 8  half native (handled in client.lua)
    { 1.75, 1.75, 1.75 },   -- 9  native
  },
  full = 7,
  highAbove = 15.0,
  zones = {
    -- OPTION B (recommended, owner decides): step 2 on the ground (invisible there), step 4 when flying / high camera
    { x = 1700.0, y = 3700.0, r = 900.0,  day = 2, night = 2, high = 4 },   -- town
    { x = 1700.0, y = 3700.0, r = 1500.0, day = 4, night = 4 },             -- outskirts looking back at town
  },
}
