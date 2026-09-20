# Version 2.9 — counts, breath and beats on one clock

In all nine worlds, the breath cue's count ticks, the breath guide and the score now play from one sample clock. Aurora Lake, Tidal Origami and Pilgrim Tides are regenerated so that the music itself moves at 60 BPM.

- **Ticks on the beat.**
  - Before: the once-a-second tick (louder at each phase change) started when a frame noticed the second had turned. On Quest that lands up to one audio mix buffer late, by a different amount each second.
  - Now: the ticks are a looping track exactly one breath cycle long, with each tick on the first sample of its second. The score, the breath guide and the ticks start, pause and resume on the same mix step.
  - Result: every count, every breath phase change and every beat sound together, from the first second, and after the session menu or a headset focus change.
- **Lyria scores that play 60 BPM themselves.**
  - Before: Lyria RealTime ignored its tempo setting, so 2.8 laid a synthesized pulse over beds that moved at their own pace.
  - Lyria 3.5 keeps a tempo written into its prompt. Each score is now three Lyria 3.5 movements that play their own soft pulse on every beat: a felt mallet (Aurora Lake), felt-piano droplets (Tidal Origami) and a felt-piano walking pulse (Pilgrim Tides).
  - Each take is measured with librosa. Takes whose beat wandered are rejected. Each take is corrected by its tiny period error (at most 32 parts per million in the chosen takes) and placed so its beats land on the ticks.
  - Movements join on bar lines, at the points where both sides are at full level. The gain is ridden through each join, so no join sags or lurches. No pulse is added.
- **Verification from the mixer.** `tools/check_cue_alignment.py` records each world's score, breath guide and ticks from Godot's own mixer, through a pause. It checks that every tick sounds with a whole second of the score and the matching moment of the breath guide.

## Previous release records

# Version 2.8 — every score on the breath ticks

All nine scores are regenerated on a strict 60 BPM grid. Every beat lands on a whole second, where the breath cue's ticks sound, and the grid holds through every movement change, crossfade and dissolve.

- **Prismatic Sanctuary** moves from 50 to 60 BPM. Each sixteen-beat phrase now spans exactly one 4/4/4/4 breath cycle, and its heartbeat kick is firmer. The tunnel's light pulses follow the new tempo.
- **Visionary Temple** now has eight one-minute harmonic passages that dissolve with the tunnel's 30-second dissolves, and its heartbeat plays on every tick.
- **Fractal Garden, Cloud Atelier, Neural Constellation and Circuit Garden** keep their themes. Motifs, echoes and chord changes move onto whole beats, over a gentle pulse that suits each theme: a glass pluck, a low bloom, a cellular blip and a sequenced analogue tone.
- **Aurora Lake, Tidal Origami and Pilgrim Tides** are regenerated as continuous Lyria RealTime beds steered through their movements by prompt blending. Under each bed a sample-exact felt-mallet, water-droplet or felt-piano pulse follows the bed's harmony and accents each breath cycle. Lyria RealTime did not honour its BPM setting in measurement, so the beds are beatless and the pulse defines the grid.

`python -m audio.beat_grid` checks every delivery with librosa against the tick sample measured the same way. It requires a 60 BPM tempo, onsets folding at exactly 1.000 s, a beat peak with the tick, at least nine in ten tracked beats within 50 ms, and alignment held in every 16-second window and every transition. `tests/test_suite_audio.py` runs the same check.

## Previous release records

# Version 2.7 — Visionary Temple in eight sculpted passages

**Visionary Temple** now travels through eight one-minute passages instead of four two-minute ones. Four new AI-painted passages join the procedural eye lattice, flame mandala, kaleidoscope rings and temple: *Indra's Net* (golden cords and jewels over a nebula void), *Peacock Vault* (overlapping feathers laid like roof tiles), *Lotus Garden* (layered blossoms on lapis water) and *Crystal Geode* (amethyst and citrine mandalas), in the order eyes, net, flames, peacock, rings, lotus, geode, temple. gpt-image-2 painted the new tiles and four matching sigils; wrap seams were repaired by repainting a feathered central cross.

The tunnel wall now follows the contours of its paintings. Nano Banana Pro produced a pixel-aligned height map for every passage, including the procedural four. The vertex shader displaces a denser tube by up to 0.75 m, and the fragment shader lights the relief from the same maps. Vertices move with the travelling and turning surface, so relief does not swim. Besides the temple's flat-floored hall, the net has a soft hexagonal cross-section, the peacock vault is scalloped, the lotus garden is a tall ellipse and the geode is an octagon with one mandala per facet.

Flat drifting sigils are replaced by 384 modelled 3D relics of 25 types, from eye orbs and gem lattices to armillary spheres, lotus flowers, crystal clusters and temple bells. Nano Banana Pro material-capture spheres give them gold and gemstone surfaces. They tumble freely and follow six kinds of path across the tunnel; some linger ahead and some overtake the viewer from behind.

Dissolves last 30 seconds (previously 24) and now have depth. The outgoing passage opens along its own contours, ground first, so its ornament floats for a while. Behind it the next passage waits on a wider, dimmer shell, turning in a different direction, then settles into place. The breath rhythm, plasma inhale, petal outflow, destination light and score are unchanged; the score's four harmonic sections now each span two passages. See `experiences/visionary_temple/DESIGN.md`. Desktop captures establish composition only; headset comfort and frame rate during the two-shell dissolves need headset review.

# Version 2.6 — Visionary Temple

A ninth world, **Visionary Temple**, joins the selector. It is a gaze-following painted tunnel in the manner of Prismatic Sanctuary, but its walls are an original visionary-art surface that paths through four two-minute passages: a lattice of staring eyes woven by golden geometry, a turning flame-and-feather mandala with dotted mushrooms, nested kaleidoscope ring cells in gold octagon frames, and a painted temple hall of fluted columns, starry pointed arches, a blue-green diamond floor and a rosette dome. Each passage dissolves into the next along its raised ornament over 24 seconds, and the tunnel cross-section eases into a flat-floored hall for the temple. Drifting painted sigils (eye, flame lotus, ring cell, rosette) carry the current passage's motif and serve as golden inhale sources; sixteen violet-to-cyan petals leave the mouth on the exhale; the white destination light keeps its 500 ms hold-growth and exhale-collapse rays.

The rhythm is a long-release box (4 s in, 4 s hold, 6 s out, 2 s rest; thirty cycles). The score is a new deterministic 60 BPM transcendental psybient journey whose sixteen-beat bars coincide with the breath cycle: a tanpura-like drone, a sub heartbeat that rests in the empty pause, breath-shaped plucked sixteenth arpeggios, hold-time glass shimmer and slow pads that move through four harmonic passages with the visuals. The supplied reference clips informed original procedural ornament baked by `tools/bake_visionary_tiles.py`; no reference frames are bundled. See `experiences/visionary_temple/DESIGN.md` for the tile mapping, breath timings and budgets. Desktop captures establish composition only; headset comfort and sustained frame rate are unverified.


# Version 2.5 — cloud tunnel and video previews

Prismatic Sanctuary now encloses the viewer in 98,304 procedural cloud grains and 32,768 detached filaments. Three radial strata retain dense coverage while adding real thickness, curved drift, raised geometric ornament, and small satellite flecks. The previous tiled surface has been removed. The approved breath streams, persistent white destination, gaze lag, fog level and single trance score are retained.

Eight one-minute desktop preview videos are generated with actual runtime music and breathing audio. Each smoothly looks from seated level toward an 80-degree upward view, with no instructional overlays.

## Previous release records

# Version 2.4 — wordless themed worlds

Experiences 3–8 now have different visual breath languages, full surrounding particle ecologies, and stronger overhead compositions. All are eight minutes, with their existing individual rhythms. Words remain only in the selector and deliberate exit confirmation.

| World | Visual breath language | Surrounding scene |
|---|---|---|
| Fractal Garden | A six-fold particle iris opens on inhale and closes on exhale. | A sculpted kaleidoscope of evolving Mandelbrot fields |
| Tidal Origami | A particle lotus lifts and opens liquid petals during inhale, then drains inward on release. | Suspended liquid loops and breathing water petals |
| Cloud Atelier | A soft particle vortex expands and contracts with the breath. | Layered cloud islands with a breathing vortex |
| Neural Constellation | A twelve-arm dendritic particle crown gathers and radiates breath signals. | A deeper living network of converging signals |
| Circuit Garden | Seven nested particle capacitor plates charge and expand during inhale, releasing amber current on exhale. | Nested circuit assemblies with flowing charge |
| Pilgrim Tides | A ring of twenty-four tiny particle figures gathers and raises its arms on inhale, then opens on release. | Braided processions and a gathering of lantern figures |

Four mismatched scores have been replaced: recursive glass harmonics for Fractal Garden, airy harmonic swells for Cloud Atelier, responsive cellular tones for Neural Constellation, and warm oscillator sequences for Circuit Garden. The aquatic and humanist chamber scores remain. Each is one mastered arrangement, not an extra overlay.

Prismatic Sanctuary adds sixteen curved rainbow outflow beams and directional traveling pulses on both flows. Fog is lighter and instruction labels are removed. The bright white destination core persists through every phase; its surrounding rays grow during the full hold and vanish during exhale over 500 ms.

The review found and corrected a transparent-vault ordering bug that hid near fractal particles, excessive fine fractal contrast, and oversized near-face particles. All six reclining compositions now show their focal cue and multiple surrounding depth layers. Desktop evidence cannot establish subjective stereo comfort.

## Previous release history

# Eight worlds, one gentle breath

Each world supports reclining, lasts exactly eight minutes, and renders tracked particle hands. Prismatic Sanctuary uses slow forward optic flow toward a distant star; Aurora Lake retains its golden orb, while experiences 3–8 now have distinct wordless particle sculptures and delayed gaze following. Breathing sounds—not a separate visual metronome—provide the phase clock. The original Aurora Lake retains its approved outgoing particles and outbreath recording.

The new worlds were authored in seven separate implementation subsessions. Each owns a small procedural scene layer and consumes the same breath state. All were rendered in contrasting phases and reclining views before integration; review findings drove a second pass where necessary.

| Experience | Creative direction | Seconds: in / full pause / out / empty pause | Cycles | Music direction |
|---|---|---:|---:|---|
| Aurora Lake | Close layered auroras above irregular breathing waves; a giving and recovering golden particle orb | 4 / 2 / 8 / 0 | 34 + 4s settling | 60 BPM: three Lyria 3.5 movements in D major with a soft felt-mallet note on every beat, positional water and particle voices |
| Prismatic Sanctuary | A gaze-following geometric tunnel: sixteen shape families, green plasma inhale, sixteen rainbow outflow beams and a bright white center | 4 / 4 / 4 / 4 | 30 | 60 BPM transcendental electronica: warm choir-like synths, slow legato melody, heartbeat pulse and a gradual minor-to-major opening |
| Fractal Garden | Actual Barnsley fern and tetrahedral IFS structures; seedpods gather, branch and dissolve | 6 / 0 / 6 / 0 | 40 | 60 BPM recursive glass harmonics over a quiet glass pulse |
| Tidal Origami | Water folds into impossible suspended arches and smaller floating liquid forms | 6 / 2 / 8 / 0 | 30 | 60 BPM: three Lyria 3.5 movements of singing bowls, bowed glass and warm bass with felt-piano droplets on every beat |
| Cloud Atelier | Clouds sculpt a breathing vault; irregular stratus islands and nearby whorls part and gather | 5 / 0 / 5 / 0 | 48 | 60 BPM airborne harmonics over a soft low breathing bloom |
| Neural Constellation | Organic dendrites connect particle somas; gentle signals propagate with the breath | 5 / 0 / 7 / 0 | 40 | 60 BPM cellular resonances answering over a gentle firing pulse |
| Circuit Garden | Floating circuit lattices store charge and release a slow, soft current | 4 / 0 / 6 / 0 | 48 | 60 BPM warm analogue chords over a softly sequenced pulse |
| Pilgrim Tides | Hundreds of simple humanoids walk floating promenades, gather, and bring their hands inward on inhalation | 6 / 2 / 6 / 2 | 30 | 60 BPM: three Lyria 3.5 chamber movements, strings and low clarinet over a felt-piano walking pulse |
| Visionary Temple | A sculpted, painted tunnel through eight one-minute passages: eye lattice, Indra's net, flame mandala, peacock vault, kaleidoscope rings, lotus garden, crystal geode and a temple hall, with layered contour dissolves; golden plasma inhale, violet petal outflow, white destination light | 4 / 4 / 6 / 2 | 30 | 60 BPM transcendental psybient clocked to the breath |

These are gentle pacing invitations. The startup menu explicitly invites comfortable breathing and treating holds as gentle pauses. Nothing requires the user to perform a forced breath or keep pace to continue.

## Pause or return at any time

Raise a palm toward your face and sweep it sideways in either direction to pause and open the confirmation. No persistent control is displayed during the session. A visible gaze pointer and progress ring let you choose End session or Continue with a 1.8-second dwell. Lower your hand before the next wave. The gesture and confirmation follow the head orientation, including while reclining; Quest 2/3 use head-directed gaze because those headsets have no eye tracker. Tracking jumps, back-facing palms, distant hands, stationary poses and controller-synthesized hands are rejected. Desktop supports M and mouse selection; the controller hold shortcut remains available.

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


### Prismatic refinement — version 2.2

Prismatic Sanctuary now travels through a 16,384-point vault, follows gaze with approximately sixteen seconds of lag, contracts 40% with inhalation, pulses gently during the full hold, and expands on exhalation. Visible source objects feed two green plasma arcs to the nose; blue mouth particles branch toward the walls in four directions. Distant objects and walls dissolve into directional haze. The unfogged white center grows during the full hold and shrinks to zero at exhalation, using 500 ms transitions. The score is a distinct 90 BPM electronic trance composition with new Lyria stems. See the experience’s DESIGN.md for budgets and timing.


### Version 2.3 refinement

The Prismatic walls now combine 32,768 dense relief tiles with 8,192 floating filament particles. Deep radial folds carry nested rosettes, curling filigree and woven geometry. Occasional stylized eyes and geckos emerge during separate long passages, with gradual palette and relief changes. The music has also been rebuilt as one clocked electronic arrangement: generated backing recordings and keyboard-like plucks were removed after headset feedback found them jarring against the 90 BPM beat. A runtime test confirms that lake and mote players do not accompany this experience.

## Heart-directed inhale and transcendental score

Prismatic Sanctuary’s two green inhale arcs now descend toward a heart-directed offset 14 cm below and 12 cm forward of the shared neck breath center, including when reclining. Its current score is an authored 50 BPM electronic arrangement in five 96-second movements: Awakening, Longing, Opening, Radiance and Homecoming. Slowly changing suspended harmony opens from minor into major, with sustained melodic responses, warm choir-like synth pads, quiet heartbeat pulses, bass and diffused echoes. The tunnel’s subtle light pulses follow the catalog tempo. The eight-minute session and 4/4/4/4 breathing rhythm stay the same. Earlier 90 BPM descriptions above document previous iterations.

## Universal breath center

Every world now receives one world-space neck reference computed from `BreathGeometry.BREATH_CENTER_OFFSET`, 18 cm below the headset in headset space. Aurora’s particles, Prismatic’s curves, Visionary Temple’s paths and all six themed flows use it for incoming destinations and outgoing origins. Optional offsets are applied in the headset basis relative to this shared point, never reconstructed from independent mouth/nose coordinates. Prismatic retains a lower incoming offset; its outgoing rainbow starts at the neck. The reusable `breath-visualization-patterns` skill records this as a MUST.
