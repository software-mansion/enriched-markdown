# Movement textures

The instruments on the Movement screen are baked images: a plate bed, the
turning parts, and a static layer of bridges and jewels above them. The app
only rotates and slides them.

Re-bake after changing `bake.html`:

    node scripts/movement-textures/generate.mjs

It draws every layer on a canvas in headless Chrome and writes WebP files to
`src/screens/movement/assets/`. No packages are needed; set `CHROME` if Chrome
is not in `/Applications`.

The geometry constants at the top of `bake.html` (wheel centres, tooth counts,
box sizes) mirror the ones in `src/screens/movement/works.tsx`. Change them in
both places.
