# Breathwork VR

Eight native Godot meditation worlds for Meta Quest, each eight minutes long. Choose a world from a spatial startup menu, then follow a gently drifting visual breath cue through breath-responsive geometry, fractals, water, clouds, neurons, circuits, or quiet crowds.

The approved **Aurora Lake** remains available with its layered auroras, dynamic water, golden particle orb, and positional sound. All worlds share tracked particle hands and reclining support. Prismatic Sanctuary uses a slow geometric tunnel, pulsing green plasma inhale paths, sixteen rainbow outflow beams, and a permanently visible white destination core. Experiences 3–8 each have their own wordless focal sculpture and directed breath flows: a fractal iris, water lotus, cloud vortex, neural crown, capacitor plates, and a gathering of particle figures. Every world has its own rhythm and cohesive soundtrack.

See [the experience catalog and review notes](docs/EXPERIENCES.md) for all eight directions, rhythms, and the critique/refinement process. The [verification record](docs/VERIFICATION.md) distinguishes desktop checks from headset validation.

![Eight integrated desktop experience previews](docs/screenshots/experiences.jpg)

Experience 2 now has a 90 BPM electronic trance score and a gaze-following particle tunnel:

![Prismatic Sanctuary with the expanded white light during a breath hold](docs/screenshots/prismatic-trance.jpg)

## Choose an experience

In Quest, look at a card for 2.5 seconds; its highlight and percentage show selection progress. The menu anchors to the current gaze, including while lying down. Looking well away for a few seconds brings the menu back in front of you. On desktop, click a card or press **1–8**. Press **R** to re-anchor the desktop menu.

Sessions fade back to the selector when complete. To pause or end early, raise a hand in front of your face with your **palm toward you**, then sweep it sideways in either direction. A confirmation appears with a visible gaze pointer. Hold the pointer over **End session** or **Continue** for 1.8 seconds. Lower your hand before waving again. This works while reclining. Quest 2/3 use head-directed gaze; their hardware does not track the eyes. On desktop, press **M**, then gaze or click a choice. Holding a controller button or Escape/Space for 1.5 seconds also returns early. Follow the breathing comfortably; holds can be gentle pauses.

## Run

Use **Godot 4.6.3** with the Mobile renderer. Open `project.godot` in the editor, or run:

```sh
GODOT_BIN=/path/to/Godot tools/run.sh
```

The local development environment uses `.tools/Godot.app/Contents/MacOS/Godot` by default. Hold Escape or Space for 1.5 seconds to fade out of a desktop preview.

## Build for Quest

The repository includes Godot OpenXR Vendors 5.1.0 and its license notices. Install the matching Godot Android export template through the editor, then configure JDK 17, Android SDK platform 36, build-tools 36.1.0, and NDK 29.0.14206865. The Gradle build directory is `android`; the generated project under `android/build` is local and ignored.

Configure a local debug keystore at `.tools/debug.keystore`, or update the export preset to your own signing configuration. Private keystores, SDKs, APKs, and credentials are not included.

```sh
GODOT_BIN=/path/to/Godot tools/export_quest.sh
QUEST_SERIAL=your_physical_quest_serial tools/deploy_quest.sh
```

The headset needs developer mode and USB debugging authorization. The installer refuses emulator serials. Optical hands and controllers are supported; optical pinch gestures do not trigger the controller hold-to-exit shortcut.

## Verify and develop

Install the packages in `audio/requirements.txt`, FFmpeg/ffprobe, and `oggenc` (Vorbis tools). Set `PYTHON_BIN` and `GODOT_BIN` as needed, then run `tools/verify.sh`. It checks all eight rhythms and scores, silent holds, selector anchoring, session timing, XR joint transforms, tracking loss, final audio transport, generated assets, and GPU address math. Godot can return success after a shader or script error; the verifier also examines its error output.

`scripts/build_scene.gd` regenerates the authored scene. Visual review commands can use `--review-path`, `--review-start`, `--review-duration`, and `--review-recline` after Godot's `--` argument separator. Desktop fixed-timestep review is not a headset frame-rate measurement.

## Audio and provenance

Runtime audio is included under `assets/audio`. Aurora Lake, Tidal Origami, Pilgrim Tides, and the spatial water/mote textures use Google Lyria material mastered locally. Prismatic Sanctuary and the other four scores use authored electronic synthesis with distinct arrangements. Each score is one coherent 480-second delivery. The retained suite Lyria scores use three movements with ten-second crossfades. Authored prompts, generation code, and non-secret provenance are under `audio`. Regeneration requires `GEMINI_API_KEY` or `GOOGLE_API_KEY` in the environment. Untouched generation masters and large verification captures remain local and are excluded from Git and Android exports.

The most recent refinement keeps the approved outbreath samples unchanged while softening the inhale. See the audio contract tests for the preserved sample hashes.


Regenerate the current four themed synthesized scores with `python -m audio.generate_theme_scores`, and Prismatic Sanctuary with `python -m audio.generate_prismatic_trance`. Bake the Mandelbrot fields with `python tools/generate_fractal_fields.py`.

Generate the original suite Lyria audio with `python -m audio.synth_suite_breath` and `python -m audio.generate_suite`. The music batch resumes validated masters and deliveries and uses two concurrent workers. `python -m audio.review_suite` performs an explicitly automated audio audit; it is separate from runtime playback and requires API access. The Quest application itself needs no internet connection.

## Reusable development skill

[godot-quest-breathwork](skills/godot-quest-breathwork/SKILL.md) documents the session's lessons: calm particle timing, mouth-relative presence, reclined composition, hand tracking, mobile rendering, audio mastering, and honest visual/device verification. Copy its folder into your Codex skills directory to reuse it. The companion [session lessons](skills/godot-quest-breathwork/references/session-lessons.md) include a practical review rubric.
