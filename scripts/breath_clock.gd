class_name BreathClock
extends Node
## Derives phase from the audible breath loop; Director supplies session time.

signal inhale_started
signal pause_started
signal exhale_started

@export var ratio_ramp: bool = false
var pattern: Array = [4.0, 2.0, 8.0, 0.0]
var custom_pattern: bool = false
var custom_stream: AudioStreamWAV
var is_empty_pause: bool = false
var phase: float = 0.0
var is_inhale: bool = true
var is_pause: bool = false
var is_exhale: bool = false
var breath_fill: float = 0.0
var inhale_t: float = 0.0
var exhale_t: float = 0.0
var cycle_index: int = 0
var loop_seconds: float = 14.0
var seconds: float = 0.0
var _previous_cycle: int = -1
var _previous_phase: int = -1
var _long_loop: bool = false
var _long_stream: AudioStreamWAV = preload("res://assets/audio/breath_14s.wav")
var _short_stream: AudioStreamWAV = preload("res://assets/audio/breath_12s.wav")

func configure(player: AudioStreamPlayer) -> void:
    if custom_pattern:
        loop_seconds = pattern.reduce(func(total: float, value: float) -> float: return total + value, 0.0)
        player.stream = custom_stream
        return
    loop_seconds = 12.0 if ratio_ramp else 14.0
    player.stream = _short_stream if ratio_ramp else _long_stream
    _long_loop = not ratio_ramp

func sample(player: AudioStreamPlayer, elapsed: float) -> void:
    # Switch exactly at the first observed boundary, preserving the fractional
    # playback offset instead of restarting the next inhale from zero.
    if not custom_pattern and ratio_ramp and not _long_loop and elapsed >= 120.0:
        var carry: float = maxf(0.0, elapsed - 120.0)
        player.stream = _long_stream
        player.play(fmod(carry, 14.0))
        loop_seconds = 14.0
        _long_loop = true
    var audible: float = player.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
    if elapsed < 0.1 and cycle_index == 0:
        audible = maxf(0.0, audible)
    update_from_position(audible, elapsed)

func update_from_position(playback: float, elapsed: float) -> void:
    seconds = fposmod(playback, loop_seconds)
    phase = seconds / loop_seconds
    var incoming: float = float(pattern[0]) if custom_pattern else 4.0
    var outgoing_start: float = incoming + (float(pattern[1]) if custom_pattern else 2.0)
    var outgoing_end: float = outgoing_start + float(pattern[2]) if custom_pattern else loop_seconds
    is_inhale = seconds < incoming
    is_exhale = seconds >= outgoing_start and seconds < outgoing_end
    is_empty_pause = seconds >= outgoing_end
    is_pause = not is_inhale and not is_exhale
    inhale_t = clampf(seconds / incoming, 0.0, 1.0)
    exhale_t = clampf((seconds - outgoing_start) / (outgoing_end - outgoing_start), 0.0, 1.0)
    breath_fill = ExperienceMath.smooth_unit(inhale_t) if is_inhale else 1.0 - ExperienceMath.smooth_unit(exhale_t)
    cycle_index = int(elapsed / loop_seconds) if custom_pattern else ExperienceMath.cycle_at(elapsed, ratio_ramp)
    var current_phase: int = 3 if is_empty_pause else (0 if is_inhale else (1 if is_pause else 2))
    if current_phase != _previous_phase or cycle_index != _previous_cycle:
        if is_inhale:
            inhale_started.emit()
        elif is_pause:
            pause_started.emit()
        else:
            exhale_started.emit()
    _previous_phase = current_phase
    _previous_cycle = cycle_index

func settle_at() -> float:
    return floor(480.0 / loop_seconds) * loop_seconds if custom_pattern else (470.0 if ratio_ramp else 476.0)

func incoming_visibility() -> float:
    if not custom_pattern:
        return ExperienceMath.inhale_visibility(seconds, loop_seconds)
    var lead: float = seconds - loop_seconds if seconds >= loop_seconds - 1.5 else seconds
    var duration: float = pattern[0]
    if lead >= duration:
        return 0.0
    return ExperienceMath.softer_unit((lead + 1.5) / 2.7) * (1.0 - ExperienceMath.softer_unit((lead - duration + 1.6) / 1.6))

func incoming_front() -> float:
    if not custom_pattern:
        return ExperienceMath.inhale_front(seconds, loop_seconds)
    var lead: float = seconds - loop_seconds if seconds >= loop_seconds - 1.5 else seconds
    return 1.14 * ExperienceMath.smooth_unit((lead + 1.5) / 1.8) if lead < float(pattern[0]) else 0.0

func outgoing_end() -> float:
    return float(pattern[0]) + float(pattern[1]) + float(pattern[2]) if custom_pattern else loop_seconds

func outgoing_gate() -> float:
    if not custom_pattern:
        return ExperienceMath.exhale_gate(seconds, loop_seconds)
    var start: float = float(pattern[0]) + float(pattern[1])
    return ExperienceMath.smooth_unit((seconds - start) / 0.45) * (1.0 - ExperienceMath.smooth_unit((seconds - outgoing_end() + 2.0) / 2.0)) if is_exhale else 0.0
