extends SceneTree
## Exercise the real audio-finished path from the last second of the session.

var frames: int = 0

func _initialize() -> void:
    start.call_deferred()

func start() -> void:
    var scene: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(scene)
    var director: MeditationDirector = scene.get_node("Director")
    director.tree_exiting.connect(func() -> void:
        if director.elapsed >= 480.0 and director.fade >= 0.999 and director._quitting:
            print("NATURAL AUDIO END: PASS")
        else:
            push_error("Exit occurred before the final fade completed")
    )
    director.music.play(479.0)
    director.breath.play(11.0)
    director._started = true
    director.set_process(true)

func _process(_delta: float) -> bool:
    frames += 1
    if frames > 900:
        push_error("Natural ending failed to exit within ten seconds")
        quit(1)
    return false
