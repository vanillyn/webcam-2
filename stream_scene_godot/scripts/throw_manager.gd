










extends Node3D


var _character: Node3D = null


var _active_throws: Array[RigidBody3D] = []


const SPAWN_POS   := Vector3(-3.5, 1.5, 0.4)
const TARGET_POS  := Vector3(-0.1, 1.1, 0.4)
const THROW_SPEED := 9.0
const ITEM_LIFETIME := 6.0


func _ready() -> void:

	await get_tree().process_frame
	_character = get_tree().current_scene.get_node_or_null("World/CharacterRoot")


func throw_item(item_name: String) -> void:
	var name_lower := item_name.strip_edges().to_lower()

	var item: RigidBody3D
	match name_lower:
		"book":
			item = _make_book()
		"tomato":
			item = _make_tomato()
		"plushie", "plushy":
			item = _make_plushie()
		"chair":
			item = _make_chair()
		_:
			item = _make_pillow()

	add_child(item)
	item.position = SPAWN_POS


	var spread := Vector3(
		randf_range(-0.15, 0.15),
		randf_range(-0.10, 0.10),
		randf_range(-0.05, 0.05)
	)
	var direction: Vector3 = (TARGET_POS + spread - SPAWN_POS).normalized()
	item.linear_velocity = direction * THROW_SPEED
	item.angular_velocity = Vector3(randf_range(-8,8), randf_range(-8,8), randf_range(-8,8))

	_active_throws.append(item)


	var area: Area3D = item.get_node_or_null("HitArea")
	if area:
		area.body_entered.connect(_on_hit.bind(item))


	var timer := get_tree().create_timer(ITEM_LIFETIME)
	timer.timeout.connect(_remove_throw.bind(item))

	print("[ThrowManager] Threw: %s" % (name_lower if name_lower != "" else "pillow"))




func _make_base_rb(size: Vector3, color: Color, mass: float = 0.4) -> RigidBody3D:
	var rb := RigidBody3D.new()
	rb.mass = mass
	rb.gravity_scale = 0.6

	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	rb.add_child(mi)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size * 1.05
	col.shape = shape
	rb.add_child(col)


	var area := Area3D.new()
	area.name = "HitArea"
	var acol := CollisionShape3D.new()
	var ashape := SphereShape3D.new()
	ashape.radius = maxf(size.x, maxf(size.y, size.z)) * 0.7
	acol.shape = ashape
	area.add_child(acol)
	rb.add_child(area)

	return rb


func _make_sphere_rb(radius: float, color: Color, mass: float = 0.3) -> RigidBody3D:
	var rb := RigidBody3D.new()
	rb.mass = mass
	rb.gravity_scale = 0.6

	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	rb.add_child(mi)

	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = radius
	col.shape = shape
	rb.add_child(col)

	var area := Area3D.new()
	area.name = "HitArea"
	var acol := CollisionShape3D.new()
	var ashape := SphereShape3D.new()
	ashape.radius = radius * 1.2
	acol.shape = ashape
	area.add_child(acol)
	rb.add_child(area)

	return rb


func _make_pillow() -> RigidBody3D:
	var rb := _make_base_rb(Vector3(0.38, 0.25, 0.12), Color(1.0, 0.75, 0.82), 0.15)
	rb.name = "Pillow"

	var mi := rb.get_child(0) as MeshInstance3D
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.13
	mesh.height = 0.38
	mi.mesh = mesh
	mi.rotation_degrees.z = 90.0
	return rb


func _make_book() -> RigidBody3D:
	var rb := _make_base_rb(Vector3(0.22, 0.30, 0.06), Color(0.88, 0.19, 0.29), 0.5)
	rb.name = "Book"
	rb.gravity_scale = 0.9

	var cover := MeshInstance3D.new()
	var cmesh := BoxMesh.new()
	cmesh.size = Vector3(0.22, 0.30, 0.015)
	cover.mesh = cmesh
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = Color(0.75, 0.10, 0.20)
	cover.material_override = cmat
	cover.position.z = 0.024
	rb.add_child(cover)
	return rb


func _make_tomato() -> RigidBody3D:
	var rb := _make_sphere_rb(0.11, Color(0.88, 0.18, 0.14), 0.2)
	rb.name = "Tomato"

	var stem := MeshInstance3D.new()
	var smesh := CylinderMesh.new()
	smesh.top_radius = 0.01
	smesh.bottom_radius = 0.01
	smesh.height = 0.06
	stem.mesh = smesh
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.2, 0.6, 0.1)
	stem.material_override = smat
	stem.position.y = 0.12
	rb.add_child(stem)
	return rb


func _make_plushie() -> RigidBody3D:

	var rb := RigidBody3D.new()
	rb.mass = 0.12
	rb.gravity_scale = 0.4
	rb.name = "Plushie"

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.76, 0.85)


	var center := MeshInstance3D.new()
	var cmesh := SphereMesh.new()
	cmesh.radius = 0.10
	cmesh.height = 0.20
	center.mesh = cmesh
	center.material_override = mat
	rb.add_child(center)


	for i in 5:
		var angle := float(i) / 5.0 * TAU - PI / 2.0
		var pt := MeshInstance3D.new()
		var pmesh := SphereMesh.new()
		pmesh.radius = 0.06
		pmesh.height = 0.12
		pt.mesh = pmesh
		pt.material_override = mat
		pt.position = Vector3(cos(angle) * 0.13, sin(angle) * 0.13, 0.0)
		rb.add_child(pt)

	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.18
	col.shape = shape
	rb.add_child(col)

	var area := Area3D.new()
	area.name = "HitArea"
	var acol := CollisionShape3D.new()
	var ashape := SphereShape3D.new()
	ashape.radius = 0.22
	acol.shape = ashape
	area.add_child(acol)
	rb.add_child(area)

	return rb


func _make_chair() -> RigidBody3D:

	var rb := _make_base_rb(Vector3(0.6, 0.5, 0.5), Color(0.94, 0.78, 0.85), 5.0)
	rb.name = "Chair"
	rb.gravity_scale = 1.2
	rb.mass = 5.0

	return rb




func _on_hit(body: Node, throw_rb: RigidBody3D) -> void:

	if _character != null and (body == _character or body.is_ancestor_of(_character)):
		if _character.has_method("register_hit"):
			_character.register_hit(-throw_rb.linear_velocity.normalized())


		throw_rb.linear_velocity = throw_rb.linear_velocity.bounce(Vector3(0, 0, 1)) * 0.5
		throw_rb.angular_velocity *= 1.5


	var area := throw_rb.get_node_or_null("HitArea")
	if area and area.body_entered.is_connected(_on_hit):
		area.body_entered.disconnect(_on_hit)


func _remove_throw(rb: RigidBody3D) -> void:
	if is_instance_valid(rb):
		_active_throws.erase(rb)
		var tween := create_tween()
		tween.tween_property(rb, "scale", Vector3.ZERO, 0.3)
		tween.tween_callback(func(): if is_instance_valid(rb): rb.queue_free())
