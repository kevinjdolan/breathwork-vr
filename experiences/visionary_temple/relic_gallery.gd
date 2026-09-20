extends SceneTree
## Review render of every Visionary Temple relic type, turned to three angles, with triangle and crowd statistics.
const Relics = preload("res://experiences/visionary_temple/relics.gd")
const SHADER: String = """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D matcaps : source_color, filter_linear;
uniform sampler2D sprite_sheet : source_color, filter_linear_mipmap;
uniform float primary = 0.0;
uniform float secondary = 0.0;
uniform float sprite_cell = -1.0;
uniform bool sprite_cutout = false;
varying vec2 uv_v;
varying vec4 color_v;
void vertex() { uv_v = UV; color_v = COLOR; }
vec3 matcap(float index, vec2 cap) { return texture(matcaps, (vec2(mod(index, 4.0), floor(index / 4.0)) + cap) * 0.25).rgb; }
void fragment() {
    vec3 n = normalize(FRONT_FACING ? NORMAL : -NORMAL);
    vec2 cap = vec2(n.x, -n.y) * 0.48 + 0.5;
    vec3 base = matcap(primary, cap);
    vec3 color = base * color_v.rgb;
    if (color_v.a < 0.125) {
        color = color_v.rgb * 1.3 + base * 0.3;
    } else if (color_v.a < 0.375) {
        bool inside = all(greaterThanEqual(uv_v, vec2(0.0))) && all(lessThanEqual(uv_v, vec2(1.0)));
        vec4 paint = inside && sprite_cell >= 0.0 ? texture(sprite_sheet, (vec2(mod(sprite_cell, 4.0), floor(sprite_cell / 4.0)) + uv_v) * vec2(0.25, 0.5)) : vec4(0.0);
        if (sprite_cutout && paint.a < 0.4) {
            discard;
        }
        color = mix(color, paint.rgb * (0.7 + 0.5 * dot(base, vec3(0.3, 0.5, 0.2))), paint.a);
    } else if (color_v.a < 0.875) {
        color = matcap(secondary, cap) * color_v.rgb;
    }
    ALBEDO = color;
}
"""

var _frame: int = 0

func _initialize() -> void:
    root.size = Vector2i(1500, 1500)
    DirAccess.make_dir_recursive_absolute("res://verification/visionary_temple")
    var world: Node3D = Node3D.new()
    root.add_child(world)
    var environment: WorldEnvironment = WorldEnvironment.new()
    environment.environment = Environment.new()
    environment.environment.background_mode = Environment.BG_COLOR
    environment.environment.background_color = Color(0.03, 0.02, 0.06)
    world.add_child(environment)
    var camera: Camera3D = Camera3D.new()
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = 15.4
    camera.position = Vector3(0, 0, 10)
    world.add_child(camera)
    var shader: Shader = Shader.new()
    shader.code = SHADER
    var matcaps: Texture2D = load("res://experiences/visionary_temple/tiles/matcaps.png")
    var sprites: Texture2D = load("res://experiences/visionary_temple/tiles/sigils.png")
    for type: int in range(Relics.TYPES.size()):
        var spec: Dictionary = Relics.TYPES[type]
        var mesh: ArrayMesh = Relics.build_mesh(str(spec["name"]))
        print("RELIC ", spec["name"], " triangles=", mesh.get_faces().size() / 3, " aabb=", mesh.get_aabb().size)
        for view: int in range(3):
            var material: ShaderMaterial = ShaderMaterial.new()
            material.shader = shader
            material.set_shader_parameter("matcaps", matcaps)
            material.set_shader_parameter("sprite_sheet", sprites)
            material.set_shader_parameter("primary", float(spec["primary"][view % spec["primary"].size()]))
            material.set_shader_parameter("secondary", float(spec["secondary"][view % spec["secondary"].size()]))
            material.set_shader_parameter("sprite_cell", float(spec["sprite"]))
            material.set_shader_parameter("sprite_cutout", bool(spec.get("cutout", false)))
            var node: MeshInstance3D = MeshInstance3D.new()
            node.mesh = mesh
            node.material_override = material
            var column: int = type % 5
            var row: int = type / 5
            node.position = Vector3(-6.0 + column * 3.0 + (view - 1) * .95, 6.0 - row * 3.0 + (1 - view) * .45, 0)
            node.rotation = [Vector3(0, 0, 0), Vector3(-.6, .7, 0), Vector3(1.2, 2.4, .5)][view]
            node.scale = Vector3.ONE * .9
            world.add_child(node)
    var crowd: int = 0
    var busiest: float = 0.0
    for second: int in range(0, 480, 2):
        var active: int = 0
        for g: int in range(Relics.COUNT):
            if Relics.visible_at(g, float(second)):
                active += 1
        if active > crowd:
            crowd = active
            busiest = float(second)
    print("RELIC CROWD most visible at once=", crowd, " at ", busiest, "s")
    # Every relic inside its drawing window runs the vertex shader, visible or not.
    var triangles: Array[int] = []
    for type: int in range(Relics.TYPES.size()):
        triangles.append(Relics.build_mesh(str(Relics.TYPES[type]["name"])).get_faces().size() / 3)
    var worst_instances: int = 0
    var worst_triangles: int = 0
    for second: int in range(0, 480, 2):
        var drawn: int = 0
        var load: int = 0
        for g: int in range(Relics.COUNT):
            var span: Vector2 = Relics.window(g)
            if float(second) >= span.x and float(second) <= span.y:
                drawn += 1
                load += triangles[Relics.type_of(g)]
        worst_instances = maxi(worst_instances, drawn)
        worst_triangles = maxi(worst_triangles, load)
    print("RELIC DRAW most instances=", worst_instances, " most triangles=", worst_triangles)

func _process(_delta: float) -> bool:
    _frame += 1
    if _frame == 8:
        if DisplayServer.get_name() != "headless":
            RenderingServer.force_draw(false, 0.0)
            root.get_texture().get_image().save_png("res://verification/visionary_temple/relic_gallery.png")
            print("VISIONARY CAPTURE relic_gallery")
        quit()
    return false
