# Eight worlds, one gentle breath

Each world is stationary, supports reclining, lasts exactly eight minutes, and retains the shared particle orb, near-mouth breathing paths, delayed gaze following, and tracked particle hands. Breathing sounds—not a separate visual metronome—provide the phase clock. The original Aurora Lake retains its approved outgoing particles and outbreath recording.

The new worlds were authored in seven separate implementation subsessions. Each owns a small procedural scene layer and consumes the same breath state. All were rendered in contrasting phases and reclining views before integration; review findings drove a second pass where necessary.

| Experience | Creative direction | Seconds: in / full pause / out / empty pause | Cycles | Music direction |
|---|---|---:|---:|---|
| Aurora Lake | Close layered auroras above irregular breathing waves; a giving and recovering golden particle orb | 4 / 2 / 8 / 0 | 34 + 4s settling | Warm evolving ambient, positional water and particle voices |
| Prismatic Sanctuary | High-contrast psychedelic geometry: folded rosettes, open jewel facets and nested crystals, with no strobing | 4 / 4 / 4 / 4 | 30 | Crystalline chamber ambient and warm suspended harmony |
| Fractal Garden | Actual Barnsley fern and tetrahedral IFS structures; seedpods gather, branch and dissolve | 6 / 0 / 6 / 0 | 40 | Organic woodland electroacoustic textures |
| Tidal Origami | Water folds into impossible suspended arches and smaller floating liquid forms | 6 / 2 / 8 / 0 | 30 | Rounded resonant bowls, fluid glass and soft waterlike tones |
| Cloud Atelier | Clouds sculpt a breathing vault; irregular stratus islands and nearby whorls part and gather | 5 / 0 / 5 / 0 | 48 | Airborne neoclassical ambient and soft suspended strings |
| Neural Constellation | Organic dendrites connect particle somas; gentle signals propagate with the breath | 5 / 0 / 7 / 0 | 40 | Intimate bioelectronic harmonics and answering echoes |
| Circuit Garden | Floating circuit lattices store charge and release a slow, soft current | 4 / 0 / 6 / 0 | 48 | Warm analog synths and sparse electric-piano-like tones |
| Pilgrim Tides | Hundreds of simple humanoids walk floating promenades, gather, and bring their hands inward on inhalation | 6 / 2 / 6 / 2 | 30 | Patient humanist chamber minimalism |

These are gentle pacing invitations. The startup menu explicitly invites comfortable breathing and treating holds as gentle pauses. Nothing requires the user to perform a forced breath or keep pace to continue.

## Pause or return at any time

A small Menu target sits beside the breathing view. Hold your gaze on it for 1.2 seconds to pause the soundtrack and breath guide. The confirmation appears in the current head orientation, including while reclining. Look at End session for 1.8 seconds to fade to the selector, or Continue to resume. Progress resets when looking away. Desktop supports M and mouse selection; the controller hold shortcut remains available.

![Return confirmation](screenshots/session-menu.jpg)

## Review criteria carried forward

- Incoming particles must gather before the cue, travel from the orb toward the tracked mouth, and fade without a deadline-driven rush. Outgoing and incoming populations remain distinguishable.
- A central source should feel alive: bounded drift, continuous shape response, restrained color variation, and particles rather than an opaque ball.
- Nearby, middle-distance and overhead elements must provide depth. A seated screenshot alone does not establish a reclining composition.
- Repetition needs variation in spacing, scale, timing, shape and formation. Independent motion should remain slow enough to sustain attention on breathing.
- Musical difference comes from actual timbre and arrangement, not renamed copies. Edges and transitions must remain soft.
- A desktop render establishes composition and shader correctness, not stereoscopic comfort or sustained Quest performance.

## Independent review and revision

**Prismatic Sanctuary:** The first independent review found thin line-art rosettes too flat for the requested geometric richness. The revision adds cyan/copper/violet facet panels, recessed crystals, nearby lanterns, and folded rosette surfaces. Their deformation uses continuous breath fill rather than a phase switch. Brightness checks found no white overdraw patches in the reviewed frames.

**Fractal Garden:** The initial fern field was too faint and empty below the horizon; the reclining view mostly caught peripheral tips. The revision increases point legibility, moves canopy forms around the zenith, and adds five compact tetrahedral seedpods with long gathering and unraveling cycles. The central breathing lane remains open.

**Tidal Origami:** Initial stripes were too repetitive and the overhead view too sparse. The implementation first gained cellular caustics and crossing overhead sheets. Independent review then found that the water still read too much like translucent fabric. The next revision adds six nearby liquid lenses and 54 larger beads: inhalation thickens and gathers them, and exhalation spreads them into suspended pools. Rolled sheet edges make the folds less flat.

**Cloud Atelier:** A regular lower cloud ring read as a chain of puffs. The revision replaces it with overlapping, tapered stratus islands at varied depths, adds closer side whorls, and varies the main banks' density and thickness. The overhead aperture remains open around the orb.

**Neural Constellation:** The initial network had almost invisible somas. A first pass strengthened particle centers and tied propagation to the supplied breath phase; independent review then led to three nearer, denser somas, thicker main axons, and slow lobed core motion. Fine dendrites remain delicate; gathering and dispersion are staggered between nodes.

**Circuit Garden:** The first internal render read as repeated chips with disconnected antennae. It was revised into connected routed buses, varied chip sizes, and selective nested capacitors. Independent inspection found a clear circuit identity and a populated overhead view; shared orb integration is checked separately.

**Pilgrim Tides:** The first paths were too similarly oval and figures too bright. The revision varies paths with an infinity loop and softer squared forms, reduces figure luminance, and introduces gentle hands-to-chest breathing motion. Independent renders show recognizable small figures in seated and overhead views.

Each folder's `DESIGN.md` retains implementation details, its own critique, and the corresponding limitations. Large raw verification captures and untouched audio masters are intentionally excluded from the public runtime repository.
