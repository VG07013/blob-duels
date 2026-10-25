# Arena posters

Drop your own poster images here (PNG or JPG), then re-run
`generate_skyline.py` in Blender. Each file takes one random eye-level wall
bay (40 in total, 10 per wall). The shuffle is seeded (`POSTER_SEED` in the
script), so every export puts the same files in the same places. Adding or
removing a file reshuffles them; change the seed to try a different layout.

Prefix a file name with `orange_` or `blue_` to keep that poster on its
team's half of the hall (orange = red/+z half, blue = blue/-z half).
Unprefixed files can land anywhere.

Every bay without a custom image is plain solid orange on the red half of the
hall and solid blue on the blue half.

**Poster size:** 16 × 24 world units (2:3 portrait; a blob is about 5.8
units across). Make the images **1024 × 1536 px** (or any 2:3 size).
Transparent areas are not supported - flatten images onto a background first.
