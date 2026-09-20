extends SceneTree
## Record one session's score, breath loop and tick track from Godot's own mixer, each on its own capture bus, through
## a pause and resume. tools/check_cue_alignment.py then measures where every tick, breath phase and score second
## actually sounded. Captures run in real time on the headless dummy audio driver.

const SECONDS: float = 24.0
## The pause starts halfway through a score second after this long, so it never cuts a tick short.
const PAUSE_AFTER: float = 11.0
const PAUSE_FOR: float = 0.8

var captures: Dictionary = {}
var stems: Dictionary = {}

func _initialize() -> void:
    run.call_deferred()

func drain() -> void:
    # Packed arrays copy on write, so each stem keeps a list of captured chunks.
    for stem: String in captures:
        var capture: AudioEffectCapture = captures[stem]
        (stems[stem] as Array).append(capture.get_buffer(capture.get_frames_available()))

func run() -> void:
    var id: String = "aurora_lake"
    var start: float = 64.0
    var output: String = ProjectSettings.globalize_path("res://verification/cue_alignment")
    for arg: String in OS.get_cmdline_user_args():
        if arg.begins_with("--experience="):
            id = arg.get_slice("=", 1)
        elif arg.begins_with("--start="):
            start = float(arg.get_slice("=", 1))
        elif arg.begins_with("--output="):
            output = arg.get_slice("=", 1)
    DirAccess.make_dir_recursive_absolute(output)
    root.set_meta("experience_id", id)
    var scene: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    await process_frame
    var director: MeditationDirector = scene.get_node("Director")
    var players: Dictionary = {"music": director.music, "breath": director.breath, "ticks": director.breath_cue.tick_player}
    # Capture effects added under one lock start filling on the same mix step, so frame i of every stem is one moment.
    AudioServer.lock()
    for stem: String in players:
        var player: AudioStreamPlayer = players[stem]
        var index: int = AudioServer.bus_count
        AudioServer.add_bus(index)
        AudioServer.set_bus_name(index, "Capture" + stem.capitalize())
        AudioServer.set_bus_send(index, player.bus)
        var capture: AudioEffectCapture = AudioEffectCapture.new()
        capture.buffer_length = 4.0
        AudioServer.add_bus_effect(index, capture)
        player.bus = AudioServer.get_bus_name(index)
        captures[stem] = capture
        stems[stem] = []
    AudioServer.unlock()
    director.breath_cue.update_cue(0.0, director.clock.display_pattern(), 1.0)
    director.play_session_audio(start)
    var began: int = Time.get_ticks_msec()
    var paused_at: int = -1
    var resumed: bool = false
    var offsets: Array = []
    while float(Time.get_ticks_msec() - began) / 1000.0 < SECONDS:
        await process_frame
        drain()
        var position: float = director.music.get_playback_position()
        if paused_at < 0 and position - start >= PAUSE_AFTER and absf(fposmod(position, 1.0) - 0.5) < 0.1:
            offsets.append(director.audio_offsets_ms())
            director.set_audio_paused(true)
            paused_at = Time.get_ticks_msec()
        elif paused_at >= 0 and not resumed and Time.get_ticks_msec() - paused_at >= int(PAUSE_FOR * 1000.0):
            director.set_audio_paused(false)
            resumed = true
    offsets.append(director.audio_offsets_ms())
    AudioServer.lock()
    for player: AudioStreamPlayer in players.values():
        player.stop()
    AudioServer.unlock()
    await create_timer(0.2).timeout
    drain()
    var report: Dictionary = {
        "id": id, "start": start, "mix_rate": AudioServer.get_mix_rate(), "pattern": director.clock.display_pattern(),
        "loop_seconds": director.clock.loop_seconds, "boundaries": BreathCue.boundaries(director.clock.display_pattern()),
        "music": str(director.experience.get("music", "assets/audio/music.ogg")), "breath": (director.breath.stream as AudioStreamWAV).resource_path,
        "offsets_ms_before_pause_and_at_end": offsets.map(func(value: Vector2) -> Array: return [value.x, value.y]),
        "discarded_frames": {}, "frames": {},
    }
    for stem: String in stems:
        var file: FileAccess = FileAccess.open(output.path_join(id + "_" + stem + ".f32"), FileAccess.WRITE)
        var count: int = 0
        for chunk: PackedVector2Array in stems[stem]:
            file.store_buffer(chunk.to_byte_array())
            count += chunk.size()
        file.close()
        report["discarded_frames"][stem] = (captures[stem] as AudioEffectCapture).get_discarded_frames()
        report["frames"][stem] = count
    var summary: FileAccess = FileAccess.open(output.path_join(id + ".json"), FileAccess.WRITE)
    summary.store_string(JSON.stringify(report, "  "))
    summary.close()
    scene.queue_free()
    await create_timer(0.3).timeout
    print("CUE CAPTURE ", id, " frames=", report["frames"], " discarded=", report["discarded_frames"])
    quit()
