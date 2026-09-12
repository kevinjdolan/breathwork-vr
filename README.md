# Breathwork VR

An eight-minute, native Godot meditation for Meta Quest. A particle orb shares a slow breath with the viewer above a living aurora lake. The experience includes tracked particle hands, delayed gaze following, layered auroras, breath-responsive water, drifting particle constellations, and positional audio.

The current rhythm is four seconds in, two seconds held, and eight seconds out. The session settles and fades after its final complete breath. The viewer can sit or recline; the headset's position and orientation drive the mouth target and orb placement.

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

Install the packages in `audio/requirements.txt` and FFmpeg. Set `PYTHON_BIN` and `GODOT_BIN` as needed, then run `tools/verify.sh`. It checks session timing, XR joint transforms, tracking loss, final audio transport, generated assets, and GPU address math. Godot can return success after a shader or script error; the verifier also examines its error output.

`scripts/build_scene.gd` regenerates the authored scene. Visual review commands can use `--review-path`, `--review-start`, `--review-duration`, and `--review-recline` after Godot's `--` argument separator. Desktop fixed-timestep review is not a headset frame-rate measurement.

## Audio and provenance

Runtime audio is included under `assets/audio`. The soundtrack and eight spatial water/mote textures were generated with Google Lyria, then mastered locally. Authored prompts, generation code, and non-secret provenance are under `audio`. Regeneration requires `GEMINI_API_KEY` or `GOOGLE_API_KEY` in the environment. Untouched generation masters and large verification captures remain local and are excluded from Git and Android exports.

The most recent refinement keeps the approved outbreath samples unchanged while softening the inhale. See the audio contract tests for the preserved sample hashes.
