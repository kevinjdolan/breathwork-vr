class_name PrismaticShapes
extends RefCounted
## Sixteen bounded, genuinely different mesh families with open chromatic facets.

const NAMES: Array[String] = ["Tetrahedral lantern", "Cube window", "Octahedral crystal", "Icosahedral jewel", "Dodecahedral lantern", "Cuboctahedral cage", "Truncated tetrahedron", "Pentagonal antiprism", "Hexagonal bipyramid", "Stellated octahedron", "Five-point prism", "Triangular torus", "Trefoil knot", "Mobius ribbon", "Double helix", "Gyroscopic rings"]
const COLORS: Array[Color] = [Color(0.06,0.65,0.96), Color(0.96,0.22,0.055), Color(0.50,0.075,0.90), Color(0.95,0.075,0.42), Color(0.10,0.88,0.62), Color(0.94,0.55,0.07)]

static func build(kind: int) -> ArrayMesh:
    var st: SurfaceTool = SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    st.set_normal(Vector3.UP)
    if kind < 10:
        var points: Array[Vector3] = _vertices(kind)
        var faces: Array = _hull(points)
        for face_index: int in range(faces.size()):
            var face: Array = faces[face_index]
            var center: Vector3 = Vector3.ZERO
            for point: Vector3 in face:
                center += point
            center /= float(face.size())
            var tint: Color = COLORS[(face_index + kind) % COLORS.size()]
            for edge: int in range(face.size()):
                var a: Vector3 = face[edge]
                var b: Vector3 = face[(edge+1)%face.size()]
                if kind == 9:
                    _triangle(st, a, b, center.normalized()*1.12, tint*0.65)
                    _bar(st, a, center.normalized()*1.12, .010, tint)
                else:
                    var ai: Vector3 = center.lerp(a,.59)
                    var bi: Vector3 = center.lerp(b,.59)
                    _triangle(st,a,b,bi,tint*.62)
                    _triangle(st,a,bi,ai,tint*.46)
                    _triangle(st,center*.47,a*.47,b*.47,COLORS[(face_index+2)%6]*.46)
                    _bar(st,a,b,.009,tint)
    elif kind == 10:
        for i: int in range(10):
            var a: float = TAU*i/10.0
            var b: float = TAU*(i+1)/10.0
            var p: Vector3 = Vector3(cos(a),sin(a),0)*(.95 if i%2==0 else .43)
            var q: Vector3 = Vector3(cos(b),sin(b),0)*(.95 if (i+1)%2==0 else .43)
            var c: Color = COLORS[i%6]
            _triangle(st,p+Vector3(0,0,.25),q+Vector3(0,0,.25),q-Vector3(0,0,.25),c*.6)
            _triangle(st,p+Vector3(0,0,.25),q-Vector3(0,0,.25),p-Vector3(0,0,.25),c*.6)
            _bar(st,p+Vector3(0,0,.25),q+Vector3(0,0,.25),.015,c)
            _bar(st,p-Vector3(0,0,.25),q-Vector3(0,0,.25),.015,c)
    elif kind in [11,12]:
        var count: int = 32 if kind==11 else 64
        for i: int in range(count):
            var t: float = TAU*i/count
            var next: float = TAU*(i+1)/count
            var p: Vector3 = _curve(kind,t)
            var q: Vector3 = _curve(kind,next)
            var tangent: Vector3 = (q-p).normalized()
            var u: Vector3 = tangent.cross(Vector3.UP).normalized()
            if u.length()<.1:
                u = tangent.cross(Vector3.RIGHT).normalized()
            var v: Vector3 = tangent.cross(u).normalized()
            for side: int in range(3 if kind==11 else 5):
                var sides: int = 3 if kind==11 else 5
                var a: float = TAU*side/sides
                var b: float = TAU*(side+1)/sides
                var radius: float = .16 if kind==11 else .095
                var offset_a: Vector3 = (u*cos(a)+v*sin(a))*radius
                var offset_b: Vector3 = (u*cos(b)+v*sin(b))*radius
                var tint: Color = COLORS[(i/8+side)%6]
                _triangle(st,p+offset_a,q+offset_a,q+offset_b,tint*.65)
                _triangle(st,p+offset_a,q+offset_b,p+offset_b,tint*.65)
                if side==0:
                    _bar(st,p+offset_a,q+offset_a,.009,tint)
    elif kind==13:
        for i: int in range(64):
            var t: float = TAU*i/64.0
            var n: float = TAU*(i+1)/64.0
            var a: Vector3 = _mobius(t,-.24)
            var b: Vector3 = _mobius(t,.24)
            var c: Vector3 = _mobius(n,.24)
            var d: Vector3 = _mobius(n,-.24)
            var tint: Color = COLORS[(i/8)%6]
            _triangle(st,a,b,c,tint*.62)
            _triangle(st,a,c,d,tint*.62)
            _bar(st,a,d,.012,tint)
    elif kind==14:
        for i: int in range(48):
            var t: float = float(i)/48.0
            var n: float = float(i+1)/48.0
            for strand: int in range(2):
                var p: Vector3 = Vector3(.43*cos(t*TAU*2+strand*PI),t*1.8-.9,.43*sin(t*TAU*2+strand*PI))
                var q: Vector3 = Vector3(.43*cos(n*TAU*2+strand*PI),n*1.8-.9,.43*sin(n*TAU*2+strand*PI))
                _bar(st,p,q,.032,COLORS[(strand*2+i/12)%6])
                if i%4==0 and strand==0:
                    _bar(st,p,Vector3(-p.x,p.y,-p.z),.012,COLORS[(i/8+1)%6]*.65)
    else:
        for ring: int in range(3):
            var basis: Basis = Basis(Vector3.RIGHT,ring*PI/3.0)*Basis(Vector3.UP,ring*.7)
            for i: int in range(32):
                var a: float = TAU*i/32.0
                var b: float = TAU*(i+1)/32.0
                _bar(st,basis*Vector3(cos(a),sin(a),0)*.88,basis*Vector3(cos(b),sin(b),0)*.88,.045,COLORS[(ring*2+i/8)%6])
    return st.commit()

static func _vertices(kind: int) -> Array[Vector3]:
    var points: Array[Vector3] = []
    var phi: float = (1.0+sqrt(5.0))/2.0
    if kind in [0,6]:
        var tetra: Array[Vector3] = [Vector3(1,1,1),Vector3(-1,-1,1),Vector3(-1,1,-1),Vector3(1,-1,-1)]
        if kind==0:
            points = tetra
        else:
            for a: Vector3 in tetra:
                for b: Vector3 in tetra:
                    if a!=b:
                        points.append(a.lerp(b,1.0/3.0))
    elif kind in [1,4]:
        for x: float in [-1.0,1.0]:
            for y: float in [-1.0,1.0]:
                for z: float in [-1.0,1.0]:
                    points.append(Vector3(x,y,z))
        if kind==4:
            for a: float in [-1.0,1.0]:
                for b: float in [-1.0,1.0]:
                    points.append(Vector3(0,a/phi,b*phi))
                    points.append(Vector3(a/phi,b*phi,0))
                    points.append(Vector3(b*phi,0,a/phi))
    elif kind in [2,9]:
        points = [Vector3.RIGHT,Vector3.LEFT,Vector3.UP,Vector3.DOWN,Vector3.FORWARD,Vector3.BACK]
    elif kind in [3,5]:
        for a: float in [-1.0,1.0]:
            for b: float in [-1.0,1.0]:
                var value: float = phi if kind==3 else 1.0
                points.append(Vector3(0,a,b*value))
                points.append(Vector3(a,b*value,0))
                points.append(Vector3(b*value,0,a))
    elif kind==7:
        for row: int in range(2):
            for i: int in range(5):
                var a: float = TAU*i/5.0+row*PI/5.0
                points.append(Vector3(cos(a),.55 if row==0 else -.55,sin(a)))
    else:
        points = [Vector3(0,1.2,0),Vector3(0,-1.2,0)]
        for i: int in range(6):
            points.append(Vector3(cos(TAU*i/6.0),0,sin(TAU*i/6.0)))
    var extent: float = 0.0
    for point: Vector3 in points:
        extent = maxf(extent,point.length())
    for i: int in range(points.size()):
        points[i] /= extent
    return points

static func _hull(points: Array[Vector3]) -> Array:
    var result: Array = []
    var planes: Array[Plane] = []
    for a: int in range(points.size()):
        for b: int in range(a+1,points.size()):
            for c: int in range(b+1,points.size()):
                var normal: Vector3 = (points[b]-points[a]).cross(points[c]-points[a])
                if normal.length()<.0001:
                    continue
                normal = normal.normalized()
                if normal.dot(points[a])<0:
                    normal = -normal
                var distance: float = normal.dot(points[a])
                var valid: bool = true
                for point: Vector3 in points:
                    if normal.dot(point)>distance+.0001:
                        valid = false
                        break
                if not valid:
                    continue
                for plane: Plane in planes:
                    if plane.normal.dot(normal)>.9999 and absf(plane.d-distance)<.0001:
                        valid = false
                        break
                if not valid:
                    continue
                planes.append(Plane(normal,distance))
                var face: Array[Vector3] = []
                var center: Vector3 = Vector3.ZERO
                for point: Vector3 in points:
                    if absf(normal.dot(point)-distance)<.0001:
                        face.append(point)
                        center += point
                center /= face.size()
                var u: Vector3 = (face[0]-center).normalized()
                var v: Vector3 = normal.cross(u)
                face.sort_custom(func(p: Vector3,q: Vector3) -> bool: return atan2((p-center).dot(v),(p-center).dot(u))<atan2((q-center).dot(v),(q-center).dot(u)))
                result.append(face)
    return result

static func _curve(kind: int,t: float) -> Vector3:
    if kind==11:
        return Vector3(cos(t),sin(t),0)*.76
    return Vector3((2+cos(3*t))*cos(2*t),(2+cos(3*t))*sin(2*t),sin(3*t))*.26

static func _mobius(t: float,width: float) -> Vector3:
    return Vector3((.72+width*cos(t*.5))*cos(t),(.72+width*cos(t*.5))*sin(t),width*sin(t*.5))

static func _triangle(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,tint: Color) -> void:
    st.set_color(tint)
    st.set_normal((b-a).cross(c-a).normalized())
    for point: Vector3 in [a,b,c]:
        st.add_vertex(point)

static func _bar(st: SurfaceTool,a: Vector3,b: Vector3,width: float,tint: Color) -> void:
    var direction: Vector3 = (b-a).normalized()
    var u: Vector3 = direction.cross(Vector3.UP if absf(direction.y)<.9 else Vector3.RIGHT).normalized()*width
    var v: Vector3 = direction.cross(u).normalized()*width
    for side: int in range(4):
        var x: Vector3 = u*cos(TAU*side/4.0)+v*sin(TAU*side/4.0)
        var y: Vector3 = u*cos(TAU*(side+1)/4.0)+v*sin(TAU*(side+1)/4.0)
        _triangle(st,a+x,b+x,b+y,tint)
        _triangle(st,a+x,b+y,a+y,tint)
