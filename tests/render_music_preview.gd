extends SceneTree
## Render a world with a music track driving it in place of the breath.
##
## The shipped worlds take one scalar from the breath clock and modulate the warp with
## it. Feeding that same scalar from a baked loudness table turns them into ordinary
## audio visualizers without touching a shader, which is also how MilkDrop worked: the
## FFT never drew anything itself, it only moved the coefficients of the warp.

var director: MeditationDirector
var scene: Node
var frame: int = 0
var duration: float = 30.0
var finishing: bool = false
var drive: Array = []
var start_seconds: float = 0.0
var gain: float = 1.0
const PREROLL: int = 60
const FPS: float = 30.0

func _initialize() -> void:
    begin.call_deferred()

func begin() -> void:
    var id: String = "spiral_aperture"
    var table_path: String = "res://build/music/track_bands.json"
    var stream_path: String = "res://build/music/track.mp3"
    for argument: String in OS.get_cmdline_user_args():
        if argument.begins_with("--experience="):
            id = argument.get_slice("=", 1)
        if argument.begins_with("--preview-duration="):
            duration = float(argument.get_slice("=", 1))
        if argument.begins_with("--music-start="):
            start_seconds = float(argument.get_slice("=", 1))
        if argument.begins_with("--music-table="):
            table_path = argument.get_slice("=", 1)
        if argument.begins_with("--music-stream="):
            stream_path = argument.get_slice("=", 1)
        if argument.begins_with("--music-gain="):
            gain = float(argument.get_slice("=", 1))
    var table: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(table_path))
    drive = table["drive"]
    root.set_meta("experience_id", id)
    scene = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    await process_frame
    director = scene.get_node("Director")
    director.camera.get_parent().position = Vector3(0, 1.4, 0)
    director.camera.position = Vector3.ZERO
    director._start_session()
    director.set_process(false)
    director.session_menu.set_process(false)
    # The world's own score and the breath guide would both fight the track.
    director.music.stream = load(stream_path)
    director.breath.stream = null
    director.breath.volume_db = -80.0

func modulation(index: int) -> float:
    """Map the track's loudness onto the range the breath used to occupy.

    The bands are already relative to the track's own long-term average, so 1.0 is a
    typical moment. A saturating curve keeps a loud passage expressive while stopping a
    transient — this track peaks seventeen times its own average — from throwing the
    warp into noise.
    """
    if drive.is_empty():
        return 0.0
    var value: float = float(drive[clampi(index, 0, drive.size() - 1)])
    var excess: float = maxf(0.0, (value - 0.6)/1.4)
    return minf(1.8, 1.5*excess/(1.0 + 0.55*excess))*gain

func _process(_delta: float) -> bool:
    if director == null or finishing:
        return false
    frame += 1
    var seconds: float = maxf(0.0, float(frame - PREROLL)/FPS)
    if frame == PREROLL:
        director.music.play(start_seconds)
    director.elapsed = start_seconds + seconds
    director.clock.update_from_position(fposmod(director.elapsed, director.clock.loop_seconds), director.elapsed)
    director.arc.seek(director.elapsed, true)
    director.fade = 0.0
    # The warp reads this one value; the track now supplies it instead of the lungs.
    director.clock.breath_fill = modulation(int((start_seconds + seconds)*FPS))
    # A gentler sweep than the breath previews: the motion should be the music's.
    director.camera.rotation.x = deg_to_rad(42.0)*smoothstep(6.0, 30.0, seconds)
    director.camera.rotation.y = deg_to_rad(7.0)*sin(seconds*0.09)
    director._gaze_direction = -director.camera.global_basis.z
    director._follow_orb(1.0/FPS)
    director._push_visuals(1.0/FPS)
    if frame >= PREROLL + int(duration*FPS) + 4:
        finishing = true
        finish.call_deferred()
    return false

func finish() -> void:
    director.music.stop()
    root.remove_child(scene)
    # Freeing before the quit keeps the renderer from reporting leaked pages and
    # shaders, which would otherwise look like a failed render in the batch log.
    scene.free()
    # Movie Maker only finalizes the file on a clean quit, and nothing else ends this
    # loop, so a run that does not quit here records until it fills the disk.
    quit()
