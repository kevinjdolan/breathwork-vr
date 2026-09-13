class_name ExperienceCatalog
extends RefCounted
## Single authored catalog shared by the selector, rhythm clock, and music build.

static func all() -> Array:
    return JSON.parse_string(FileAccess.get_file_as_string("res://experiences/catalog.json")) as Array

static func find(id: String) -> Dictionary:
    for entry: Dictionary in all():
        if entry["id"] == id:
            return entry
    return all()[0]

static func background(id: String) -> Color:
    return {"prismatic_sanctuary": Color(0.0015, 0.0018, 0.007), "fractal_garden": Color(0.006, 0.018, 0.012), "tidal_origami": Color(0.003, 0.011, 0.021), "cloud_atelier": Color(0.060, 0.085, 0.135), "neural_constellation": Color(0.007, 0.009, 0.023), "circuit_garden": Color(0.006, 0.012, 0.018), "pilgrim_tides": Color(0.016, 0.019, 0.026), "visionary_temple": Color(0.012, 0.004, 0.022)}.get(id, Color.BLACK)

static func rhythm_text(entry: Dictionary) -> String:
    var r: Array = entry["rhythm"]
    var result: String = "%ds in" % r[0]
    if r[1] > 0:
        result += " · %ds hold" % r[1]
    result += " · %ds out" % r[2]
    if r[3] > 0:
        result += " · %ds rest" % r[3]
    return result
