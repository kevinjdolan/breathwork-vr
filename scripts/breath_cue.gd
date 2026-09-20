class_name BreathCue
extends Node3D
## A head-locked "In 4" / "Hold 2" / "Out 8" countdown with a wood-block tick on
## every second and a louder tick on each phase change. Shared by every
## experience since it reads the same BreathClock pattern the audio and visuals
## already follow.
##
## The ticks are one looping track, exactly one breath cycle long, with a tick
## starting on the first sample of every whole second. MeditationDirector
## starts, pauses and resumes it on the same mix step as the breath loop and
## the score, so every tick shares their sample clock and lands on the count,
## the breath phase boundary and the score's 60 BPM beat. A tick started from
## a frame poll instead lands up to a mix buffer late, by a different amount
## each second.

const OFFSET: Vector3 = Vector3(0.0, 0.32, -0.9)
const TICK_GAIN: float = 0.02
const BOUNDARY_GAIN: float = 0.08
const TICK: AudioStreamWAV = preload("res://assets/audio/breath_tick.wav")

var label: Label3D
var tick_player: AudioStreamPlayer
var _last_text: String = ""

func _ready() -> void:
    position = OFFSET
    label = Label3D.new()
    label.font_size = 40
    label.pixel_size = 0.0026
    label.outline_size = 10
    label.outline_modulate = Color(0.02, 0.03, 0.03, 1.0)
    label.no_depth_test = true
    label.render_priority = 101
    label.modulate = Color(0.86, 0.93, 0.92)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    add_child(label)
    tick_player = AudioStreamPlayer.new()
    tick_player.name = "Ticks"
    tick_player.volume_db = linear_to_db(BOUNDARY_GAIN)
    add_child(tick_player)

## Load the tick track for the session's pattern; the director plays it with the score.
func configure(pattern: Array) -> void:
    tick_player.stream = BreathCue.tick_track(pattern)

func update_cue(seconds: float, pattern: Array, visible_intensity: float) -> void:
    var text: String = BreathCue.text_for(seconds, pattern)
    if text != _last_text:
        _last_text = text
        label.text = text
    label.modulate.a = visible_intensity
    label.outline_modulate.a = visible_intensity
    # Boundary ticks are rendered at full scale and the rest at TICK_GAIN / BOUNDARY_GAIN, so one player gain
    # follows the session's visible intensity and silences the track while the menu is open or fully faded.
    tick_player.volume_db = linear_to_db(maxf(BOUNDARY_GAIN * visible_intensity, 0.00001))

## One breath cycle of ticks as a looping 16-bit mono stream at the tick sample's rate. Each tick starts on the first
## sample of its second, at full scale on a phase boundary and at TICK_GAIN / BOUNDARY_GAIN elsewhere.
static func tick_track(pattern: Array) -> AudioStreamWAV:
    assert(TICK.format == AudioStreamWAV.FORMAT_16_BITS and not TICK.stereo, "breath_tick.wav must import as uncompressed mono PCM")
    var rate: int = TICK.mix_rate
    var cycle: int = int(round(pattern.reduce(func(total: float, value: float) -> float: return total + value, 0.0)))
    var loud: PackedByteArray = TICK.data.slice(0, 2 * rate)
    var soft: PackedByteArray = loud.duplicate()
    var scale: float = TICK_GAIN / BOUNDARY_GAIN
    for offset: int in range(0, soft.size(), 2):
        soft.encode_s16(offset, roundi(soft.decode_s16(offset) * scale))
    var gap: PackedByteArray = PackedByteArray()
    gap.resize(2 * rate - loud.size())
    gap.fill(0)
    var accents: Array = BreathCue.boundaries(pattern)
    var data: PackedByteArray = PackedByteArray()
    for second: int in range(cycle):
        data.append_array(loud if accents.has(float(second)) else soft)
        data.append_array(gap)
    var track: AudioStreamWAV = AudioStreamWAV.new()
    track.format = AudioStreamWAV.FORMAT_16_BITS
    track.mix_rate = rate
    track.stereo = false
    track.data = data
    track.loop_mode = AudioStreamWAV.LOOP_FORWARD
    track.loop_begin = 0
    track.loop_end = cycle * rate
    return track

## Real phase-boundary seconds within the loop: 0 (loop start / wrap), the end
## of inhale, the end of the post-inhale hold, and the end of exhale.
static func boundaries(pattern: Array) -> Array:
    var b1: float = float(pattern[0])
    var b2: float = b1 + float(pattern[1])
    var b3: float = b2 + float(pattern[2])
    return [0.0, b1, b2, b3]

## Pure so it can be exercised without a scene tree. `pattern` is
## [inhale, hold_after_inhale, exhale, hold_after_exhale] seconds; `seconds` is
## the position within that loop, matching BreathClock.seconds / display_pattern().
static func text_for(seconds: float, pattern: Array) -> String:
    var hold_in: float = float(pattern[1])
    var hold_out: float = float(pattern[3])
    var b1: float = float(pattern[0])
    var b2: float = b1 + hold_in
    var b3: float = b2 + float(pattern[2])
    var label_text: String
    var phase_end: float
    if seconds < b1:
        label_text = "In"
        phase_end = b1
    elif hold_in > 0.0 and seconds < b2:
        label_text = "Hold"
        phase_end = b2
    elif seconds < b3:
        label_text = "Out"
        phase_end = b3
    else:
        label_text = "Hold"
        phase_end = b3 + hold_out
    var remaining: float = phase_end - seconds
    var count: int = maxi(1, int(ceil(remaining)))
    return label_text + " " + str(count)
