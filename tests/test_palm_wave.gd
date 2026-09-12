extends SceneTree
## Verify intentional palm sweeps and rejection of common accidental movements.
var failures: int = 0

func check(condition: bool, message: String) -> void:
    if not condition:
        failures += 1
        push_error(message)

func sweep(wave: PalmWave, direction: float, facing: float = 1.0, depth: float = -0.45) -> int:
    var hits: int = 0
    for frame: int in range(30):
        if wave.sample(Vector3(direction*(-0.20 + frame*0.014),0,depth), facing, true, 1.0/60.0):
            hits += 1
    return hits

func _initialize() -> void:
    for direction: float in [-1.0, 1.0]:
        var wave: PalmWave = PalmWave.new()
        check(sweep(wave,direction) == 1, "Both sweep directions open exactly once")
        check(sweep(wave,-direction) == 0, "Continued waving cannot repeatedly open the dialog")
        wave.sample(Vector3.ZERO,0,false,0.5)
        check(sweep(wave,-direction) == 1, "Leaving the face region rearms the gesture")
    check(sweep(PalmWave.new(),1,-1) == 0, "Back of hand cannot open menu")
    check(sweep(PalmWave.new(),1,1,-1.2) == 0, "Distant palm cannot open menu")
    var still: PalmWave = PalmWave.new()
    for frame: int in range(180):
        check(not still.sample(Vector3(0,0,-0.4),1,true,1.0/60.0), "A stationary palm never opens menu")
    var jump: PalmWave = PalmWave.new()
    jump.sample(Vector3(-0.3,0,-0.4),1,true,0.016)
    check(not jump.sample(Vector3(0.3,0,-0.4),1,true,0.016), "Tracking jumps cannot open menu")
    jump.sample(Vector3.ZERO,0,false,0.016)
    check(not jump.sample(Vector3(0.3,0,-0.4),1,true,0.016), "Reacquisition begins a fresh gesture")
    print("PALM WAVE: ", "PASS" if failures == 0 else "FAIL")
    quit(failures)
