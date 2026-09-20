---
name: breath-visualization-patterns
description: Build or refine Godot/OpenXR breath visualizations, including inhale paths, exhale emission, shared body anchors, experience-specific offsets, and reclining behavior. Use when changing breathing particles or lines in Breathwork VR.
---

# Breath visualization patterns

## Shared body reference — MUST

- **Every experience MUST use the universal neck breath center as the reference for its inhale destination and exhale origin.** In Breathwork VR, `scripts/breath_geometry.gd` defines `BreathGeometry.BREATH_CENTER_OFFSET`; this is the single source of truth for the headset-relative neck location.
- **All final endpoints MUST derive from that common point.** The director computes its world position each render frame and supplies `state["breath_center"]`. Consumers use `BreathGeometry.from_state(state)`; its standalone-preview fallback also uses the universal constant. Never reconstruct an independent mouth, nose, heart, or neck point in an experience or shader.
- **An experience-specific offset MUST be explicit and relative to the shared center**, transformed by the normalized headset basis exactly once: `BreathGeometry.offset(center, head_basis, local_offset)`. A zero offset is the default. Keep incoming and outgoing offsets separate when their intended locations differ. Prismatic Sanctuary's lower inhale is an example; its exhale still starts at the neck.
- **Apply the same convention across every catalog experience, including newly added ones.** This includes Aurora's GPU particles, Prismatic's plasma/rainbow curves, Visionary Temple's golden/violet paths, and the six shared themed flows. Feed the derived values to `inhale_target` and `exhale_origin`; do not embed anatomical coordinates in shaders. Keep scene generation, debug markers, preview helpers and runtime contracts aligned.

The neck location is an estimate from the headset, not tracked anatomy. Keep it headset-relative for reclining poses; a fixed world-down offset fails when the user lies back. The canonical center must move with the current head pose, not the delayed gaze-following focal object.

## Direction, timing and comfort

Use audible transport to drive inhale, full hold, exhale and empty rest. Keep the source and direction legible: incoming motion leads toward the shared endpoint, while outgoing motion starts at its shared origin. Curves may arc, spiral or branch between these endpoints. Preserve approved phase timing and audio unless the user asks to change them.

Reveal established paths smoothly before the phase starts and taper them into holds. Avoid endpoint acceleration, abrupt source switching, or restarting particle motion at each phase boundary. Thin/fade geometry near the viewer and preserve the near-eye exclusion region even when the endpoint is below the face. Retain bounded particle, triangle and overdraw budgets.

## Verify the contract

Exercise every catalog entry’s live material routes with translated headset/rig positions, yaw, roll and a reclined pose. Check both incoming and outgoing endpoints and at least one nonzero local offset. Supply a deliberately shifted `breath_center` in a layer test: its endpoints must follow that point rather than silently recomputing a body location. Existing suite contracts are in `tests/test_suite.gd` and Aurora particle contracts are in `tests/test_session.gd`.

Render actual inhale/exhale phases with the Mobile renderer, including reclining, and inspect shader/script error logs even when Godot exits successfully. A desktop render verifies that viewport; it does not establish stereo comfort or sustained Quest performance. Follow the user's existing deployment authorization when testing on a headset.
