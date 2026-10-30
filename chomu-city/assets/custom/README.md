# Drop-in custom models (e.g. from Triverse AI or Blender)

Put a `.glb` here with one of these exact names and the game picks it up automatically
(restart / re-import in CHoMU Engine first):

| File name            | Replaces                         | Notes |
|----------------------|----------------------------------|-------|
| `hero_car.glb`       | the drivable player car          | Car must face **+Z**. Wheels as separate nodes named `wheel-front-left`, `wheel-front-right`, `wheel-back-left`, `wheel-back-right` (pivot at wheel centre) so they spin/steer. Auto-scaled to ~1.95 m width. |
| `player.glb`         | the player character             | Must contain an AnimationPlayer with animations named `idle`, `walk`, `sprint`, `jump`, `fall`. Auto-scaled to 1.75 m. |

Static props/buildings: add the path to the lists in `scripts/Assets.gd`
(DOWNTOWN / COMMERCIAL / SUBURBAN) - they are auto-scaled to the lot size and get box collision.

Phone budget tips: <= 30k triangles per hero model, 1024 px textures, one material if possible.
