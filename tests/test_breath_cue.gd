extends SceneTree
## The breath countdown text and its wood-block tick must track the same
## pattern the audio and visuals already follow, on a steady one-tick-per-second
## rhythm with a louder tick at each phase boundary. The ticks, the breath loop
## and the score must share one sample clock in every experience, so each count
## and phase change lands on the score's whole-second beat.

var failures: int = 0

func check(condition: bool, message: String) -> void:
    if not condition:
        failures += 1
        push_error(message)

func close(actual: float, expected: float, message: String, tolerance: float = 0.002) -> void:
    check(absf(actual - expected) <= tolerance, message + ": got " + str(actual) + ", expected " + str(expected))

func _initialize() -> void:
    call_deferred("run")

## Peak magnitude of the first 30 ms of every second, and the first sample of each second above a quarter of that peak.
func second_onsets(track: AudioStreamWAV) -> Array:
    var rate: int = track.mix_rate
    var data: PackedByteArray = track.data
    var result: Array = []
    for second: int in range(track.loop_end / rate):
        var start: int = second * rate
        var values: Array[int] = []
        for frame: int in range(start, start + rate * 30 / 1000):
            values.append(absi(data.decode_s16(frame * 2)))
        var peak: int = values.max()
        result.append([peak, values.find(values.filter(func(value: int) -> bool: return value * 4 > peak)[0])])
    return result

func run() -> void:
    # experiences/prismatic_sanctuary and friends all read this same shape from
    # experiences/catalog.json's "rhythm" field.
    var boxed: Array = [4.0, 2.0, 8.0, 0.0]
    for entry: Array in [[0.0, "In 4"], [0.999, "In 4"], [1.0, "In 3"], [3.0, "In 1"], [3.999, "In 1"],
            [4.0, "Hold 2"], [5.0, "Hold 1"], [5.999, "Hold 1"],
            [6.0, "Out 8"], [7.0, "Out 7"], [13.0, "Out 1"], [13.999, "Out 1"]]:
        check(BreathCue.text_for(entry[0], boxed) == entry[1], "Boxed cue at " + str(entry[0]) + " reads " + str(entry[1]))

    # fractal_garden's [6, 0, 6, 0] skips the hold entirely; the count still
    # runs straight through the missing hold with no gap in the rhythm.
    var unbroken: Array = [6.0, 0.0, 6.0, 0.0]
    check(BreathCue.text_for(5.999, unbroken) == "In 1", "Countdown reaches 1 right up to the boundary")
    check(BreathCue.text_for(6.0, unbroken) == "Out 6", "Exhale count starts immediately, no gap")
    check(BreathCue.text_for(11.999, unbroken) == "Out 1", "Exhale reaches 1 right up to the wrap")

    check(BreathCue.boundaries(boxed) == [0.0, 4.0, 6.0, 14.0], "Boundaries mark loop start, end of inhale, end of hold, end of exhale")

    # The tick track: one breath cycle, a tick starting on the first sample of every whole second.
    check(BreathCue.TICK.format == AudioStreamWAV.FORMAT_16_BITS and not BreathCue.TICK.stereo, "Tick sample imports as uncompressed mono PCM")
    var tick_rate: int = BreathCue.TICK.mix_rate
    # Where the tick sample's own attack crosses a quarter of its peak: every tick in a track must match it exactly.
    var tick_lead: int = second_onsets(BreathCue.tick_track([1.0, 0.0, 0.0, 0.0]))[0][1]
    check(tick_lead > 0 and tick_lead < tick_rate / 50, "Tick sample attacks within its first 20 ms")
    for case: Array in [[boxed, [0, 4, 6]], [unbroken, [0, 6]], [[4.0, 4.0, 6.0, 2.0], [0, 4, 8, 14]], [[5.0, 0.0, 7.0, 0.0], [0, 5]]]:
        var pattern: Array = case[0]
        var cycle: int = int(pattern.reduce(func(total: float, value: float) -> float: return total + value, 0.0))
        var track: AudioStreamWAV = BreathCue.tick_track(pattern)
        check(track.loop_mode == AudioStreamWAV.LOOP_FORWARD and track.loop_begin == 0 and track.loop_end == cycle * tick_rate, "Tick track loops exactly one " + str(cycle) + " s breath cycle")
        check(track.data.size() == cycle * tick_rate * 2 and not track.stereo, "Tick track holds one mono 16-bit cycle")
        var onsets: Array = second_onsets(track)
        for second: int in range(cycle):
            var accent: bool = second in case[1]
            check(onsets[second][1] == tick_lead, "Tick " + str(second) + " of " + str(pattern) + " starts on the first sample of its second")
            var expected_peak: float = 32768.0 * (1.0 if accent else BreathCue.TICK_GAIN / BreathCue.BOUNDARY_GAIN)
            check(absf(float(onsets[second][0]) / expected_peak - 1.0) < 0.05, "Tick " + str(second) + " of " + str(pattern) + (" is a louder boundary tick" if accent else " is a quiet count tick"))

    var camera: XRCamera3D = XRCamera3D.new()
    root.add_child(camera)
    var cue: BreathCue = BreathCue.new()
    camera.add_child(cue)
    cue.configure(boxed)
    cue.update_cue(0.0, boxed, 1.0)
    close(cue.tick_player.volume_db, linear_to_db(0.08), "Tick track plays at the boundary gain at full intensity")
    cue.update_cue(13.999, boxed, 0.5)
    close(cue.tick_player.volume_db, linear_to_db(0.08 * 0.5), "Tick gain follows the session's visible intensity")
    cue.update_cue(0.5, boxed, 0.0)
    check(cue.tick_player.volume_db <= -90.0, "Muted while the session menu is open or fully faded")
    cue.update_cue(6.5, boxed, 0.8)
    check(cue.label.text == "Out 8", "Countdown text reaches the Label3D")
    close(cue.label.modulate.a, 0.8, "Label alpha follows the requested intensity")
    camera.queue_free()
    await process_frame

    # Every experience starts, pauses and resumes its score, breath loop and ticks on one mix step.
    for entry: Dictionary in ExperienceCatalog.all():
        await check_shared_clock(str(entry["id"]))
    # Let the mixer thread release stopped playbacks before exit; the dummy
    # audio driver on a headless runner otherwise reports them as leaked.
    await create_timer(0.3).timeout
    await process_frame
    print("BREATH CUE: ", "PASS" if failures == 0 else str(failures) + " FAILURES")
    quit(1 if failures else 0)

func check_shared_clock(id: String) -> void:
    root.set_meta("experience_id", id)
    var scene: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    await process_frame
    var director: MeditationDirector = scene.get_node("Director")
    var ticks: AudioStreamPlayer = director.breath_cue.tick_player
    var pattern: Array = director.clock.display_pattern()
    check((ticks.stream as AudioStreamWAV).loop_end == int(director.clock.loop_seconds) * BreathCue.TICK.mix_rate, id + " tick track spans its breath cycle")
    check(BreathCue.boundaries(pattern).all(func(boundary: float) -> bool: return is_equal_approx(boundary, roundf(boundary))), id + " breath phases change on whole seconds, which are the score's beats")
    # The score's resampler decodes up to 128 frames (2.7 ms) ahead of what it has mixed; WAV players report exactly.
    var tolerance: float = 3.5
    for start: float in [0.0, 97.25]:
        director.play_session_audio(start)
        await create_timer(0.35).timeout
        var offsets: Vector2 = director.audio_offsets_ms()
        check(absf(offsets.x) <= tolerance and absf(offsets.y) <= tolerance, id + " breath loop and ticks start with the score from " + str(start) + " s: " + str(offsets))
        check(ticks.playing and director.breath.playing and director.music.playing, id + " score, breath loop and ticks all play")
        for cycle: int in range(4):
            director.set_audio_paused(true)
            check(director.music.stream_paused and director.breath.stream_paused and ticks.stream_paused, id + " pause holds all three clocks")
            await create_timer(0.05 + 0.03 * cycle).timeout
            director.set_audio_paused(false)
            await create_timer(0.07 + 0.02 * cycle).timeout
        offsets = director.audio_offsets_ms()
        check(absf(offsets.x) <= tolerance and absf(offsets.y) <= tolerance, id + " pausing and resuming keeps one clock: " + str(offsets))
    # The settle cues no further breath: the ticks stop before the tick that would start another cycle.
    var settle: float = director.clock.settle_at()
    director.play_session_audio(settle - 0.3)
    director._started = true
    await create_timer(0.02).timeout
    director._process(0.016)
    check(not ticks.playing, id + " tick track releases before the settle at " + str(settle) + " s")
    director.music.stop()
    director.breath.stop()
    ticks.stop()
    scene.queue_free()
    await process_frame
    root.remove_meta("experience_id")
