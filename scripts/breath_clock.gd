class_name BreathClock
extends Node
## Derives phase from the audible breath loop; Director supplies session time.

signal inhale_started
signal pause_started
signal exhale_started

@export var ratio_ramp: bool = false
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
    loop_seconds = 12.0 if ratio_ramp else 14.0
    player.stream = _short_stream if ratio_ramp else _long_stream
    _long_loop = not ratio_ramp

func sample(player: AudioStreamPlayer, elapsed: float) -> void:
    # Switch exactly at the first observed boundary, preserving the fractional
    # playback offset instead of restarting the next inhale from zero.
    if ratio_ramp and not _long_loop and elapsed >= 120.0:
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
    is_inhale = seconds < ExperienceMath.INHALE_SECONDS
    is_pause = seconds >= ExperienceMath.INHALE_SECONDS and seconds < ExperienceMath.EXHALE_START
    is_exhale = seconds >= ExperienceMath.EXHALE_START
    inhale_t = clampf(seconds / ExperienceMath.INHALE_SECONDS, 0.0, 1.0)
    exhale_t = clampf((seconds - ExperienceMath.EXHALE_START) / (loop_seconds - ExperienceMath.EXHALE_START), 0.0, 1.0)
    breath_fill = ExperienceMath.smooth_unit(inhale_t) if is_inhale else 1.0 - ExperienceMath.smooth_unit(exhale_t)
    cycle_index = ExperienceMath.cycle_at(elapsed, ratio_ramp)
    var current_phase: int = 0 if is_inhale else (1 if is_pause else 2)
    if current_phase != _previous_phase or cycle_index != _previous_cycle:
        if is_inhale:
            inhale_started.emit()
        elif is_pause:
            pause_started.emit()
        else:
            exhale_started.emit()
    _previous_phase = current_phase
    _previous_cycle = cycle_index
