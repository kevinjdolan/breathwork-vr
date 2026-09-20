extends SceneTree
## Render deterministic, wordless previews with actual runtime music and breath audio.
var director: MeditationDirector
var frame: int = 0
var scene: Node
var duration: float = 60.0
var start: float = 64.0
## "recline" slowly looks up to show the reclining composition; "forward" wanders gently down the journey.
var view: String = "recline"
var finishing: bool = false
const PREROLL: int = 60

func _initialize() -> void:
    root.size = Vector2i(1280,720)
    root.content_scale_size = Vector2i(1280,720)
    begin.call_deferred()

func begin() -> void:
    var id: String = "aurora_lake"
    for arg: String in OS.get_cmdline_user_args():
        if arg.begins_with("--preview-duration="):
            duration=float(arg.get_slice("=",1))
        if arg.begins_with("--preview-start="):
            start=float(arg.get_slice("=",1))
        if arg.begins_with("--preview-view="):
            view=arg.get_slice("=",1)
        if arg.begins_with("--experience="):
            id=arg.get_slice("=",1)
    root.set_meta("experience_id",id)
    scene = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    await process_frame
    director=scene.get_node("Director")
    director.camera.get_parent().position=Vector3(0,1.4,0)
    director.camera.position=Vector3.ZERO
    director._start_session()
    director.set_process(false)
    director.session_menu.set_process(false)

func _process(_delta: float) -> bool:
    if director==null or finishing:
        return false
    frame+=1
    var t: float = maxf(0.0,float(frame-PREROLL)/30.0)
    if frame==PREROLL:
        director.play_session_audio(start)
    director.elapsed=start+t
    director.clock.update_from_position(fposmod(director.elapsed,director.clock.loop_seconds),director.elapsed)
    director.arc.seek(director.elapsed,true)
    director.fade=0.0
    director.breath_particles_enabled=1.0
    if view=="forward":
        director.camera.rotation.x=deg_to_rad(4.0)*sin(t*.037)
        director.camera.rotation.y=deg_to_rad(9.0)*sin(t*.05)+deg_to_rad(5.0)*sin(t*.013)
    else:
        director.camera.rotation.x=deg_to_rad(80.0)*smoothstep(18.0,48.0,t)
        director.camera.rotation.y=deg_to_rad(5.0)*sin(t*.07)
    director._gaze_direction=-director.camera.global_basis.z
    director._follow_orb(1.0/30.0)
    director._push_visuals(1.0/30.0)
    if frame>=PREROLL+int(duration*30.0)+4:
        finishing=true
        finish.call_deferred()
    return false

func finish() -> void:
    director.music.stop()
    director.breath.stop()
    director.breath_cue.tick_player.stop()
    root.remove_child(scene)
    scene.free()
    director=null
    await process_frame
    quit()
