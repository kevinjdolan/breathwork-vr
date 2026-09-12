extends SceneTree
## Rebuilds the authored scene and import resources with Godot's typed APIs.

func material(path: String) -> ShaderMaterial:
    var result: ShaderMaterial = ShaderMaterial.new()
    result.shader = load(path) as Shader
    return result

func attach(parent: Node, node: Node, label: String, scene: Node) -> void:
    node.name = label
    parent.add_child(node)
    node.owner = scene

func particles(parent: Node, label: String, count: int, lifetime: float, shader: String, scene: Node, draw: Material) -> GPUParticles3D:
    var result: GPUParticles3D = GPUParticles3D.new()
    attach(parent, result, label, scene)
    result.amount = count
    result.lifetime = lifetime
    result.local_coords = false
    result.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    result.visibility_aabb = AABB(Vector3(-65, -10, -65), Vector3(130, 90, 130))
    result.fixed_fps = 0
    result.process_material = material(shader)
    var quad: QuadMesh = QuadMesh.new()
    quad.size = Vector2.ONE
    quad.material = draw
    result.draw_pass_1 = quad
    return result

func curtain_mesh(radius: float, height: float, base: float) -> ArrayMesh:
    var vertices: PackedVector3Array = PackedVector3Array()
    var uvs: PackedVector2Array = PackedVector2Array()
    var indices: PackedInt32Array = PackedInt32Array()
    for y: int in range(13):
        for x: int in range(193):
            var u: float = float(x) / 192.0
            var v: float = float(y) / 12.0
            vertices.append(Vector3(cos(u * TAU) * radius, base + v * height, sin(u * TAU) * radius))
            uvs.append(Vector2(u, v))
    for y: int in range(12):
        for x: int in range(192):
            var i: int = y * 193 + x
            indices.append_array(PackedInt32Array([i, i + 1, i + 193, i + 1, i + 194, i + 193]))
    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_TEX_UV] = uvs
    arrays[Mesh.ARRAY_INDEX] = indices
    var mesh: ArrayMesh = ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    return mesh

func _initialize() -> void:
    var scene: Node3D = Node3D.new()
    scene.name = "Main"
    var origin: XROrigin3D = XROrigin3D.new()
    attach(scene, origin, "XROrigin3D", scene)
    var camera: XRCamera3D = XRCamera3D.new()
    camera.near = 0.02
    camera.far = 500.0
    camera.fov = 85.0
    camera.position.y = 1.4
    attach(origin, camera, "XRCamera3D", scene)
    var mouth: Marker3D = Marker3D.new()
    mouth.position = Vector3(0, -0.08, -0.06)
    attach(camera, mouth, "MouthTarget", scene)
    var director: Node = Node.new()
    director.set_script(load("res://scripts/director.gd"))
    attach(scene, director, "Director", scene)
    var clock: Node = Node.new()
    clock.set_script(load("res://scripts/breath_clock.gd"))
    attach(scene, clock, "BreathClock", scene)
    var animation: AnimationPlayer = AnimationPlayer.new()
    attach(director, animation, "AnimationPlayer", scene)
    var library: AnimationLibrary = AnimationLibrary.new()
    library.add_animation("arc", SessionArc.create_animation())
    animation.add_animation_library("", library)
    var environment: Environment = Environment.new()
    environment.background_mode = Environment.BG_SKY
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
    environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
    environment.glow_enabled = false
    environment.ssao_enabled = false
    environment.ssr_enabled = false
    environment.fog_enabled = true
    environment.fog_density = 0.003
    environment.fog_light_color = Color(0.013, 0.026, 0.042)
    environment.fog_light_energy = 1.0
    environment.fog_sky_affect = 0.0
    var sky: Sky = Sky.new()
    sky.radiance_size = Sky.RADIANCE_SIZE_32
    sky.sky_material = material("res://shaders/sky.gdshader")
    environment.sky = sky
    var world: WorldEnvironment = WorldEnvironment.new()
    world.environment = environment
    attach(scene, world, "WorldEnvironment", scene)
    var curtains: Node3D = Node3D.new()
    attach(scene, curtains, "NearAuroras", scene)
    for layer: int in range(3):
        var curtain: MeshInstance3D = MeshInstance3D.new()
        curtain.mesh = curtain_mesh([7.5, 13.0, 23.0][layer], 7.0 + layer * 3.0, 3.2 + layer * 0.6)
        var curtain_material: ShaderMaterial = material("res://shaders/aurora_curtain.gdshader")
        curtain_material.set_shader_parameter("layer", float(layer))
        curtain.material_override = curtain_material
        curtain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        curtain.extra_cull_margin = 3.0
        attach(curtains, curtain, "Curtain" + str(layer), scene)
    var water: MeshInstance3D = MeshInstance3D.new()
    var plane: PlaneMesh = PlaneMesh.new()
    plane.size = Vector2(400, 400)
    plane.subdivide_width = 128
    plane.subdivide_depth = 128
    water.mesh = plane
    water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var water_material: ShaderMaterial = material("res://shaders/water.gdshader")
    water_material.set_shader_parameter("ripple_normal", load("res://assets/textures/ripple_normal.png"))
    water.material_override = water_material
    attach(scene, water, "Water", scene)
    var orb: Node3D = Node3D.new()
    orb.position = Vector3(0, 1.4, -ExperienceMath.ORB_DISTANCE)
    attach(scene, orb, "Orb", scene)
    var draw: ShaderMaterial = material("res://shaders/particle_draw.gdshader")
    draw.set_shader_parameter("soft_dot", load("res://assets/textures/soft_dot.png"))
    var hands: Node3D = Node3D.new()
    attach(scene, hands, "ParticleHands", scene)
    var hand_draw: ShaderMaterial = material("res://shaders/hand_draw.gdshader")
    for hand_name: String in ["Left", "Right"]:
        var hand: GPUParticles3D = particles(hands, hand_name, 768, 600.0, "res://shaders/hand_particles.gdshader", scene, hand_draw)
        hand.explosiveness = 1.0
    var core: GPUParticles3D = particles(orb, "Core", 192, 600.0, "res://shaders/orb_core.gdshader", scene, draw)
    core.local_coords = true
    core.explosiveness = 1.0
    core.scale.y = 1.6
    var halo: GPUParticles3D = particles(orb, "Halo", 300, 600.0, "res://shaders/halo.gdshader", scene, draw)
    halo.local_coords = true
    halo.explosiveness = 1.0
    var breath_draw: ShaderMaterial = draw.duplicate() as ShaderMaterial
    breath_draw.set_shader_parameter("flow_stretch", 2.0)
    var trail: GPUParticles3D = particles(orb, "MovementTrail", 180, 1.15, "res://shaders/orb_trail.gdshader", scene, breath_draw)
    trail.amount_ratio = 0.0
    var inhale: GPUParticles3D = particles(orb, "InhaleStream", 600, 600.0, "res://shaders/inhale.gdshader", scene, breath_draw)
    var inhale_draw: ShaderMaterial = breath_draw.duplicate() as ShaderMaterial
    inhale_draw.set_shader_parameter("flow_stretch", 1.35)
    inhale.draw_pass_1.material = inhale_draw
    inhale.explosiveness = 1.0
    inhale.amount_ratio = 1.0
    var exhale: GPUParticles3D = particles(mouth, "ExhaleStream", 1500, 4.8, "res://shaders/exhale.gdshader", scene, breath_draw)
    exhale.amount_ratio = 0.0
    var field: GPUParticles3D = particles(scene, "FractalField", 12000, 600.0, "res://shaders/fractal_field.gdshader", scene, draw)
    field.explosiveness = 1.0
    field.preprocess = 0.1
    var ambient: GPUParticles3D = particles(scene, "AmbientMotes", 360, 600.0, "res://shaders/ambient_motes.gdshader", scene, draw)
    ambient.explosiveness = 1.0
    var audio: Node = Node.new()
    attach(scene, audio, "Audio", scene)
    var music: AudioStreamPlayer = AudioStreamPlayer.new()
    music.stream = load("res://assets/audio/music.ogg")
    attach(audio, music, "Music", scene)
    var breath: AudioStreamPlayer = AudioStreamPlayer.new()
    breath.stream = load("res://assets/audio/breath_14s.wav")
    breath.volume_db = -18.0
    breath.bus = "Breath"
    attach(audio, breath, "Breath", scene)
    for index: int in range(3):
        var water_audio: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
        water_audio.stream = load("res://assets/audio/water_lyria_" + str(index) + ".wav")
        water_audio.position = Vector3(cos(float(index) * TAU / 3.0) * 5.0, 0.15, sin(float(index) * TAU / 3.0) * 5.0)
        water_audio.volume_db = -14.0
        water_audio.unit_size = 3.0
        water_audio.max_distance = 25.0
        water_audio.pitch_scale = 0.94 + float(index) * 0.057
        attach(audio, water_audio, "Water" + str(index), scene)
    for cluster: int in range(5):
        var mote_audio: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
        mote_audio.stream = load("res://assets/audio/mote_voice_" + str(cluster) + ".wav")
        mote_audio.volume_db = -21.0
        mote_audio.unit_size = 2.5
        mote_audio.max_distance = 18.0
        attach(audio, mote_audio, "MoteVoice" + str(cluster), scene)
    var fade: MeshInstance3D = MeshInstance3D.new()
    fade.mesh = QuadMesh.new()
    var fade_material: ShaderMaterial = material("res://shaders/fade.gdshader")
    fade_material.render_priority = 127
    fade.material_override = fade_material
    fade.extra_cull_margin = 16384.0
    fade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    attach(scene, fade, "Fade", scene)
    var packed: PackedScene = PackedScene.new()
    packed.pack(scene)
    ResourceSaver.save(packed, "res://scenes/main.tscn")
    var bus: AudioBusLayout = AudioBusLayout.new()
    bus.set("bus/1/name", "Breath")
    bus.set("bus/1/send", "Master")
    var lowpass: AudioEffectLowPassFilter = AudioEffectLowPassFilter.new()
    lowpass.cutoff_hz = 6000.0
    bus.set("bus/1/effect/0/effect", lowpass)
    bus.set("bus/1/effect/0/enabled", true)
    ResourceSaver.save(bus, "res://assets/audio/buses.tres")
    var actions: OpenXRActionMap = OpenXRActionMap.new()
    actions.create_default_action_sets()
    ResourceSaver.save(actions, "res://assets/actions.tres")
    scene.free()
    print("Scene, timeline, audio bus, and OpenXR actions saved.")
    quit()
