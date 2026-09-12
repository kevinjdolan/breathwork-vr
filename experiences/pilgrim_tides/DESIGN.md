# Pilgrim Tides

Eight minutes of quiet companionship: 640 small ivory, sage, sand and lavender people walk on floating promenades around the viewer. The arrangement evokes the collective simplicity of Humanity without copying its assets, levels or challenges. There is no destination to reach and no crowd to manage.

The 6-second inhale, 2-second full pause, 6-second exhale and 2-second empty rest are supplied by the shared transport. An inhale gently gathers each promenade by nine percent, subtly groups the people, and brings their arms toward the chest. Exhalation opens the procession again. Walking continues slowly with independent phases, so the pauses feel still without abruptly freezing people. Long-period path ripples vary independently from breathing.

The nearest low promenade carries readable heads, torsos, arms and alternating legs. A more distant infinity path and softly squared side promenades vary the silhouette. Two inward-facing overhead promenades keep the population visible while reclining. Warm pastel people occupy actual three-dimensional positions; the camera never travels. The clear center is reserved for the shared breath source and mouth-directed particles.

## Music direction

Intimate chamber-minimalist ambient: felt piano with widely spaced irregular notes, soft bowed cello harmonic clouds, sustained reed-organ warmth, and occasional tiny celesta responses. Quiet companionship and shared breathing, with long gaps, rounded attacks and long decays. No audible footsteps, percussion, rhythmic pulse, voices, abrupt accents or climactic crescendo. Shared music production and spatial sound integration are owned by the parent session.

Recommended background: `Color(0.006, 0.012, 0.023)`, a deep blue night. The material lighting is deliberately low contrast within each person, maintaining a readable figure without a bright white crowd.

## Review and changes

The first Mobile/Vulkan review showed recognizable people and convincing near/overhead separation, but all eight promenades read as similar ovals. That repetition weakened the sense of a populated world. One path now folds into a loose infinity shape and the two side paths use softened corners. The initial figures were also brighter than needed; their final luminance is reduced by 18 percent.

I also asked whether the people merely walked while an unrelated orb provided the breath. Their small hands now move toward their chest on inhale, and the promenade gathers with the same continuous breath fill. This creates a collective response without fast synchronized marching or sudden pose changes. The floating gravity is intentionally dreamlike: people face inward on the overhead paths, allowing their silhouettes to read from below.

Verified with the actual Godot 4.6.3 Forward Mobile renderer on Apple M5: seated exhale, seated full hold, and an 80-degree reclined full hold. `verification/pilgrim_tides/` contains the PNGs and engine log. The standalone review does not include the shared orb, hand particles or soundtrack; integrated captures and Quest validation remain parent-session checks. These desktop images establish composition and shader compilation, not headset frame rate or stereo comfort.

## Rendering budget

One instanced humanoid mesh for all 640 people and one combined ribbon mesh. All path travel, gait, gathering and subtle arm movement run in shaders. Eight ribbons use 192 segments each. There are no individual physics bodies, navigation agents, lights, shadows, textures or full-screen effects. Positions never approach the head closer than the designed promenades; an additional 0.9–1.7-meter distance fade protects the moving viewer's immediate space.
