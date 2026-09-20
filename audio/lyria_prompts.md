# Breathwork VR — Lyria 3.5 movements

> **Superseded in version 2.9.** Aurora Lake's score is again three Lyria 3.5 movements, now asked for a pulse on every beat at 60 BPM and placed so Lyria's own beats land on the breath ticks; see `audio/generate_lyria60.py` for the prompts, measurement and provenance. The movement prompts below document the earlier stitched 50 BPM-feel score, which ignored any beat grid.

Model: `lyria-3.5`, Google Gemini Interactions API. Artist credit: Breathwork VR / generated with Google Lyria. Instrumental ambient, D major, 50 BPM feel, no percussion or vocals. Preserve original response audio in `audio/masters/` (excluded from APK). The script requests WAV output. Never publish credentials.

The 10-second equal-power transitions START at cycle boundaries 168 and 336 seconds. Generate overlap handles: calm 178 seconds, deepening 178 seconds, peak_resolve 144 seconds. The resulting length is 178 + 178 + 144 − 20 = 480 seconds. Musical section labels refer to the mix timeline; overlaps extend the earlier section.

## calm
Title: Still Water. Generate 2:58 of instrumental meditation ambient in D major, a 50 BPM feeling without beats. Warm rounded analog pad, deep soft D/A drone, distant glass harmonics, wide gentle stereo, generous dark reverb. No voice, lyrics, percussion, sharp transients, risers, or sudden changes.
[00:00 – 00:12] Fade in softly from silence; establish the warm D drone and vast quiet space.
[00:12 – 01:24] Slowly breathing pad swells in long 12-second phrases. Sparse luminous overtones, intimate and reassuring.
[01:24 – 02:48] Gradually enrich the D major voicing with subtle F sharp and A; retain steady energy and the same drone.
[02:48 – 02:58] Sustain a seamless D/A pad transition handle, no cadence or fade-out.

## deepening
Title: Curtains of Light. Generate 2:58 of instrumental meditation ambient in D major, same warm analog pads, D/A bass drone and distant glass harmonics in a cohesive sound palette. 50 BPM feeling without percussion. Slow 12-second breathing phrases, no voices, no dramatic transients.
[00:00 – 00:10] Open on a sustained warm D/A pad, ready for an overlap with an existing drone.
[00:10 – 01:00] Gently widen stereo and introduce slowly moving suspended D major harmonies.
[01:00 – 02:20] Add a faint soft pad pulse once per 12-second phrase, richer upper harmonics, a feeling of floating attention without rhythmic drums.
[02:20 – 02:58] Become luminous and spacious with gradual harmonic density, sustain a full D major texture for transition, no ending cadence or fade.

## peak_resolve
Title: Return to Stillness. Generate 2:24 of instrumental meditation ambient in D major, warm analog pads, deep D/A drone, delicate glass harmonics, 50 BPM feeling, no drums or voice. Use rich suspended harmonies and a cohesive warm sound palette.
[00:00 – 00:48] The richest gently enveloping texture, slowly blooming stereo pads in 12-second phrases; no sharp peaks, no sudden loudness changes.
[00:48 – 01:24] Hold a luminous D major harmonic cloud then begin removing upper layers.
[01:24 – 02:00] Strip back gradually to the opening D/A drone and soft warm pad; release the faint pulse.
[02:00 – 02:20] Two very quiet closing breaths of the pad, spacious and settled.
[02:20 – 02:24] Fade softly to silence.

Alternative (documented only): one continuous eight-minute Lyria RealTime take, steering prompt weights through calm, deepening, peak and resolve while retaining the D major palette.
