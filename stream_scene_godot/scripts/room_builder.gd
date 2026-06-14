

extends Node3D


const MODES := {
	"live":     {"sky": Color(1.000, 0.910, 0.941), "amb": 1.1,  "amb_color": Color(1.000, 0.878, 0.925), "key": 1.3,  "key_color": Color(1.000, 0.957, 0.910), "lamp": 1.6, "lamp_color": Color(1.000, 0.800, 0.533), "fog_d": 20.0, "fairy": true},
	"brb":      {"sky": Color(0.847, 0.847, 0.878), "amb": 0.35, "amb_color": Color(0.784, 0.784, 0.847), "key": 0.2,  "key_color": Color(0.816, 0.816, 0.910), "lamp": 0.4, "lamp_color": Color(0.533, 0.533, 0.627), "fog_d": 12.0, "fairy": false},
	"starting": {"sky": Color(1.000, 0.894, 0.878), "amb": 0.9,  "amb_color": Color(1.000, 0.800, 0.769), "key": 1.1,  "key_color": Color(1.000, 0.722, 0.596), "lamp": 2.0, "lamp_color": Color(1.000, 0.600, 0.400), "fog_d": 20.0, "fairy": true},
	"ending":   {"sky": Color(0.094, 0.063, 0.094), "amb": 0.18, "amb_color": Color(0.125, 0.063, 0.157), "key": 0.12, "key_color": Color(0.125, 0.031, 0.094), "lamp": 0.5, "lamp_color": Color(0.290, 0.094, 0.188), "fog_d": 7.0,  "fairy": false},
}


var _current_mode: String = "live"
var _lights_off: bool = false
var _time: float = 0.0

var _ambient_light: OmniLight3D = null
var _sun_light: DirectionalLight3D = null
var _lamp_light: OmniLight3D = null
var _fill_light: DirectionalLight3D = null
var _rim_light: DirectionalLight3D = null
var _fairy_lights: Array[OmniLight3D] = []
var _fairy_meshes: Array[MeshInstance3D] = []
var _world_env: WorldEnvironment = null

var _from_mode: Dictionary = {}
var _to_mode: Dictionary = {}
var _mode_t: float = 1.0


func build() -> void:
	_build_world_env()
	_build_floor()
	_build_ceiling()
	_build_walls()
	_build_rug()
	_build_molding()
	_build_window()
	_build_desk()
	_build_bookshelf()
	_build_bed()
	_build_fairy_lights()
	_build_wall_art()
	_build_lights()
	print("[RoomBuilder] Room built.")



func set_scene_mode(mode: String) -> void:
	if not MODES.has(mode) or mode == _current_mode:
		return
	_from_mode = MODES[_current_mode].duplicate()
	_to_mode   = MODES[mode].duplicate()
	_current_mode = mode
	_mode_t = 0.0


func set_lights_off(off: bool) -> void:
	_lights_off = off



func _process(delta: float) -> void:
	_time += delta

	if _mode_t < 1.0:
		_mode_t = min(1.0, _mode_t + delta * 0.8)
		_apply_mode_lerp(_mode_t)


	if _lamp_light and not _lights_off:
		_lamp_light.light_energy += sin(_time * 7.1) * 0.04 + sin(_time * 19.3) * 0.015


	var fairy_active: bool = MODES[_current_mode].get("fairy", true) and not _lights_off
	for i in _fairy_lights.size():
		var fl: OmniLight3D = _fairy_lights[i]
		var fm: MeshInstance3D = _fairy_meshes[i] if i < _fairy_meshes.size() else null
		var ph: float = float(i) * 0.4
		var target_e: float = (0.55 + sin(_time * 2.4 + ph) * 0.45) * 0.15 if fairy_active else 0.0
		fl.light_energy = lerp(fl.light_energy, target_e, delta * 5.0)
		if fm:
			var mat := fm.get_surface_override_material(0)
			if mat is StandardMaterial3D:
				var v: float = clampf(fl.light_energy / 0.15, 0.0, 1.0)
				(mat as StandardMaterial3D).albedo_color = Color(1.0, 0.85, 0.90, v)


func _apply_mode_lerp(t: float) -> void:
	if _from_mode.is_empty() or _to_mode.is_empty():
		return
	var from := _from_mode
	var to   := _to_mode

	if _world_env:
		var env := _world_env.environment
		env.background_color = from.sky.lerp(to.sky, t)
		env.fog_light_color  = from.sky.lerp(to.sky, t)
		env.fog_density      = lerp(1.0 / from.fog_d, 1.0 / to.fog_d, t)

	if _ambient_light:
		_ambient_light.light_energy = lerp(from.amb, to.amb, t)
		_ambient_light.light_color  = from.amb_color.lerp(to.amb_color, t)

	if _sun_light:
		_sun_light.light_energy = lerp(from.key, to.key, t)
		_sun_light.light_color  = from.key_color.lerp(to.key_color, t)

	if _lamp_light and not _lights_off:
		_lamp_light.light_color = from.lamp_color.lerp(to.lamp_color, t)
		var base_e: float = lerp(from.lamp, to.lamp, t)
		_lamp_light.light_energy = lerp(_lamp_light.light_energy, base_e, 0.1)



func _box(size: Vector3, color: Color, pos: Vector3, parent: Node3D = null, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	(parent if parent else self).add_child(mi)
	return mi


func _cyl(r_top: float, r_bot: float, h: float, color: Color, pos: Vector3, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = r_top
	mesh.bottom_radius = r_bot
	mesh.height = h
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	(parent if parent else self).add_child(mi)
	return mi


func _sphere(r: float, color: Color, pos: Vector3, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = r
	mesh.height = r * 2.0
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	(parent if parent else self).add_child(mi)
	return mi



func _plane(size: Vector2, color: Color, pos: Vector3, rot: Vector3, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = size
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot

	(parent if parent else self).add_child(mi)
	return mi




func _build_world_env() -> void:
	_world_env = WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(1.0, 0.910, 0.941)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.0, 0.878, 0.925)
	env.ambient_light_energy = 0.3
	env.fog_enabled = true
	env.fog_light_color = Color(1.0, 0.910, 0.941)
	env.fog_density = 0.05
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_bloom = 0.1
	env.glow_normalized = true
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.1
	_world_env.environment = env
	add_child(_world_env)


func _build_floor() -> void:

	_plane(Vector2(12, 12), Color(0.831, 0.627, 0.47), Vector3(0, 0, 0), Vector3(-90, 0, 0))

	var sb := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(12, 0.2, 12)
	col.shape = shape
	sb.position = Vector3(0, -0.1, 0)
	add_child(sb)
	sb.add_child(col)


func _build_ceiling() -> void:
	_plane(Vector2(12, 12), Color(1.0, 0.973, 0.988), Vector3(0, 4.0, 0), Vector3(90, 0, 0))


func _build_walls() -> void:
	var wall_color := Color(0.996, 0.957, 0.973)

	_plane(Vector2(12, 8), wall_color, Vector3(0, 4, -3.0), Vector3(0, 0, 0))

	_plane(Vector2(14, 8), wall_color, Vector3(-4, 4, 1), Vector3(0, 90, 0))

	_plane(Vector2(14, 8), wall_color, Vector3(4, 4, 1), Vector3(0, -90, 0))


func _build_rug() -> void:
	_plane(Vector2(3.0, 2.2), Color(0.941, 0.722, 0.80), Vector3(0, 0.002, 0.8), Vector3(-90, 0, 0))


func _build_molding() -> void:
	var mol := Color(1.0, 0.941, 0.969)
	_box(Vector3(12, 0.12, 0.12), mol, Vector3(0, 3.94, -3.0))
	_box(Vector3(0.12, 0.12, 14), mol, Vector3(-4, 3.94, 1))
	_box(Vector3(0.12, 0.12, 14), mol, Vector3(4, 3.94, 1))
	var base_col := Color(1.0, 0.910, 0.941)
	_box(Vector3(12, 0.10, 0.08), base_col, Vector3(0, 0.05, -2.96))
	_box(Vector3(0.08, 0.10, 14), base_col, Vector3(-3.96, 0.05, 1))
	_box(Vector3(0.08, 0.10, 14), base_col, Vector3(3.96, 0.05, 1))


func _build_window() -> void:
	var frame_col := Color(1.0, 0.957, 0.973)

	_box(Vector3(0.12, 2.2, 1.6), frame_col, Vector3(-3.96, 1.7, -0.6))

	var glass := MeshInstance3D.new()
	var gmesh := PlaneMesh.new()
	gmesh.size = Vector2(1.36, 1.88)
	glass.mesh = gmesh
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(1.0, 0.973, 0.941, 0.55)
	gmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.material_override = gmat
	glass.position = Vector3(-3.92, 1.7, -0.6)
	glass.rotation_degrees.y = 90.0
	add_child(glass)

	_box(Vector3(0.05, 1.88, 0.04), frame_col, Vector3(-3.90, 1.7, -0.6))
	_box(Vector3(0.04, 0.05, 1.36), frame_col, Vector3(-3.90, 1.7, -0.6))

	_box(Vector3(0.05, 0.05, 1.9), Color(0.784, 0.627, 0.706), Vector3(-3.88, 2.88, -0.6))

	_plane(Vector2(0.55, 2.3), Color(0.910, 0.565, 0.659), Vector3(-3.88, 1.7, -1.38), Vector3(0, 90, 0))
	_plane(Vector2(0.55, 2.3), Color(0.910, 0.565, 0.659), Vector3(-3.88, 1.7,  0.18), Vector3(0, 90, 0))


func _build_desk() -> void:
	var desk := Node3D.new()
	desk.name = "Desk"

	desk.position = Vector3(-0.1, 0, -1.8)
	add_child(desk)

	var desk_col := Color(0.784, 0.627, 0.50)
	var leg_col  := Color(0.722, 0.565, 0.44)
	var frame_col := Color(0.878, 0.816, 0.847)


	_box(Vector3(1.85, 0.07, 0.80), desk_col, Vector3(0, 0.78, 0), desk)

	_box(Vector3(1.85, 0.62, 0.04), leg_col, Vector3(0, 0.47, -0.38), desk)

	for lx: float in [-0.87, 0.87]:
		for lz: float in [-0.36, 0.36]:
			_cyl(0.028, 0.022, 0.78, leg_col, Vector3(lx, 0.39, lz), desk)



	_box(Vector3(0.84, 0.56, 0.06), Color(0.941, 0.894, 0.925), Vector3(0, 1.13, -0.26), desk)


	_box(Vector3(0.76, 0.48, 0.005), Color(0.06, 0.02, 0.05), Vector3(0, 1.13, -0.228), desk)

	_box(Vector3(0.05, 0.22, 0.05), frame_col, Vector3(0, 0.89, -0.26), desk)
	_box(Vector3(0.32, 0.025, 0.24), frame_col, Vector3(0, 0.78, -0.26), desk)


	var m2 := Node3D.new()
	m2.position = Vector3(0.76, 0, -0.05)
	m2.rotation_degrees.y = -18.0
	desk.add_child(m2)
	_box(Vector3(0.52, 0.34, 0.06), Color(0.941, 0.894, 0.925), Vector3(0, 1.04, -0.24), m2)
	_box(Vector3(0.44, 0.26, 0.005), Color(0.06, 0.02, 0.05), Vector3(0, 1.04, -0.208), m2)
	_box(Vector3(0.03, 0.14, 0.03), frame_col, Vector3(0, 0.88, -0.24), m2)
	_box(Vector3(0.18, 0.02, 0.16), frame_col, Vector3(0, 0.78, -0.24), m2)


	_box(Vector3(0.58, 0.018, 0.20), Color(0.988, 0.925, 0.957), Vector3(-0.06, 0.794, 0.18), desk)


	_cyl(0.048, 0.038, 0.11, Color(1.0, 0.98, 0.99), Vector3(-0.72, 0.836, 0.14), desk)


	_cyl(0.052, 0.038, 0.10, Color(0.878, 0.533, 0.533), Vector3(0.72, 0.830, 0.10), desk)
	_sphere(0.065, Color(0.31, 0.66, 0.19), Vector3(0.72, 0.928, 0.10), desk)


	_box(Vector3(0.024, 0.36, 0.024), Color(0.847, 0.690, 0.753), Vector3(0.56, 0.98, -0.22), desk)
	_box(Vector3(0.24, 0.024, 0.024), Color(0.847, 0.690, 0.753), Vector3(0.44, 1.16, -0.20), desk)
	_box(Vector3(0.024, 0.28, 0.024), Color(0.847, 0.690, 0.753), Vector3(0.32, 1.28, -0.18), desk)


	var note_colors := [Color(1.0, 0.933, 0.533), Color(1.0, 0.733, 0.867), Color(0.667, 0.933, 0.733)]
	for ni: int in 3:
		var note := _box(Vector3(0.14, 0.12, 0.004), note_colors[ni],
			Vector3(0.28 - ni * 0.18, 0.820, 0.26), desk)
		note.rotation_degrees.z = (ni - 1.0) * 4.6


func _build_bookshelf() -> void:
	var wood := Color(0.784, 0.533, 0.376)
	var dark  := Color(0.690, 0.439, 0.282)



	_box(Vector3(0.90, 2.40, 0.32), wood, Vector3(-2.8, 1.2, -2.84))
	for s: int in 4:
		_box(Vector3(0.86, 0.04, 0.30), dark, Vector3(-2.8, 0.25 + s * 0.58, -2.84))

	var book_colors := [
		Color(0.878, 0.188, 0.290), Color(0.941, 0.376, 0.44),
		Color(1.0,   0.761, 0.80),  Color(0.784, 0.322, 0.478),
		Color(1.0,   0.702, 0.776), Color(0.667, 0.125, 0.251),
		Color(0.957, 0.561, 0.694), Color(0.910, 0.627, 0.690),
		Color(0.831, 0.376, 0.50),  Color(1.0,   0.561, 0.659),
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = 55
	var bx: float = -3.12
	for i: int in 24:
		var bw: float = 0.055 + rng.randf() * 0.055
		var bh: float = 0.30  + rng.randf() * 0.22
		var shelf: int = i / 6
		var by: float = 0.30 + shelf * 0.58 + bh * 0.5
		var bcol: Color = book_colors[rng.randi() % book_colors.size()]

		_box(Vector3(bw, bh, 0.24), bcol, Vector3(bx, by, -2.84))
		bx += bw + 0.008
		if bx > -2.50:
			bx = -3.12


func _build_bed() -> void:
	var bed := Node3D.new()
	bed.name = "Bed"

	bed.position = Vector3(2.2, 0, -1.6)
	add_child(bed)

	_box(Vector3(1.55, 0.18, 2.4),  Color(0.784, 0.596, 0.47),  Vector3(0, 0.09, 0), bed)
	_box(Vector3(1.42, 0.20, 2.2),  Color(1.0, 0.973, 0.98),    Vector3(0, 0.29, 0), bed)
	_box(Vector3(1.38, 0.12, 1.5),  Color(0.941, 0.690, 0.769), Vector3(0, 0.42, 0.28), bed)

	_box(Vector3(1.55, 0.80, 0.12), Color(0.784, 0.596, 0.47),  Vector3(0, 0.54, -1.14), bed)
	_box(Vector3(1.55, 0.30, 0.10), Color(0.784, 0.596, 0.47),  Vector3(0, 0.24,  1.20), bed)

	_box(Vector3(0.52, 0.10, 0.38), Color(1.0, 0.933, 0.957), Vector3(-0.34, 0.40, -0.94), bed)
	_box(Vector3(0.44, 0.10, 0.38), Color(1.0, 0.933, 0.957), Vector3( 0.32, 0.40, -0.94), bed)

	_sphere(0.12, Color(1.0, 0.80, 0.847), Vector3(-0.42, 0.52, -0.46), bed)
	_sphere(0.085, Color(1.0, 0.80, 0.847), Vector3(-0.42, 0.67, -0.46), bed)


func _build_fairy_lights() -> void:

	for i: int in 28:
		var t_val: float = float(i) / 27.0
		var hue: float = 0.92 + t_val * 0.08
		var col: Color = Color.from_hsv(hue, 0.9, 0.85)
		var x_pos: float = -3.2 + float(i) * 0.24

		var pos := Vector3(x_pos, 3.25, -2.92)

		var mi := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.022
		mesh.height = 0.044
		mi.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = col
		mat.emission_enabled = true
		mat.emission = col
		mat.emission_energy_multiplier = 2.0
		mi.material_override = mat
		mi.position = pos
		add_child(mi)
		_fairy_meshes.append(mi)

		var fl := OmniLight3D.new()
		fl.position = pos
		fl.light_color = col
		fl.light_energy = 0.10
		fl.omni_range = 0.60
		add_child(fl)
		_fairy_lights.append(fl)


func _build_wall_art() -> void:






	_box(Vector3(0.80, 0.62, 0.06),  Color(0.878, 0.816, 0.843), Vector3(-1.4, 2.30, -2.97))
	_box(Vector3(0.70, 0.52, 0.012), Color(0.941, 0.753, 0.816), Vector3(-1.4, 2.30, -2.93))


	_box(Vector3(0.56, 0.74, 0.06),  Color(0.188, 0.063, 0.125), Vector3(-0.4, 2.22, -2.97))
	_box(Vector3(0.46, 0.64, 0.012), Color(0.094, 0.031, 0.063), Vector3(-0.4, 2.22, -2.93))


	_box(Vector3(1.60, 0.06, 0.24), Color(0.784, 0.533, 0.376), Vector3(-0.1, 2.02, -2.88))


func _build_lights() -> void:

	var amb := OmniLight3D.new()
	amb.position = Vector3(0, 3.8, 0)
	amb.light_color = Color(1.0, 0.878, 0.925)
	amb.light_energy = 1.1
	amb.omni_range = 14.0
	amb.omni_attenuation = 0.4
	add_child(amb)
	_ambient_light = amb


	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 40, 0)
	sun.light_color = Color(1.0, 0.957, 0.910)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	add_child(sun)
	_sun_light = sun


	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-30, -130, 0)
	fill.light_color = Color(0.867, 0.816, 1.0)
	fill.light_energy = 0.5
	add_child(fill)
	_fill_light = fill


	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-10, 175, 0)
	rim.light_color = Color(1.0, 0.722, 0.80)
	rim.light_energy = 0.4
	add_child(rim)
	_rim_light = rim


	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0.32, 1.30, -1.98)
	lamp.light_color = Color(1.0, 0.80, 0.533)
	lamp.light_energy = 1.6
	lamp.omni_range = 4.5
	add_child(lamp)
	_lamp_light = lamp


	var win_light := OmniLight3D.new()
	win_light.position = Vector3(-4.5, 1.7, -0.6)
	win_light.light_color = Color(1.0, 0.973, 0.878)
	win_light.light_energy = 1.2
	win_light.omni_range = 4.0
	add_child(win_light)


	var candle_light := OmniLight3D.new()
	candle_light.position = Vector3(-3.0, 2.58, -2.84)
	candle_light.light_color = Color(1.0, 0.80, 0.40)
	candle_light.light_energy = 0.4
	candle_light.omni_range = 1.5
	add_child(candle_light)


	_from_mode = MODES["live"].duplicate()
	_to_mode   = MODES["live"].duplicate()
