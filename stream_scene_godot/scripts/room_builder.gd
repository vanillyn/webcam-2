extends Node3D

const MODES := {
	"live": {
		"sky":        Color(1.000, 0.910, 0.941),
		"amb":        1.1,
		"amb_color":  Color(1.000, 0.878, 0.925),
		"key":        1.3,
		"key_color":  Color(1.000, 0.957, 0.910),
		"fill":       Color(0.867, 0.816, 1.000),
		"fill_i":     0.5,
		"rim":        Color(1.000, 0.722, 0.800),
		"rim_i":      0.4,
		"lamp":       1.6,
		"lamp_color": Color(1.000, 0.800, 0.533),
		"mon_i":      0.45,
		"mon_color":  Color(1.000, 0.667, 0.784),
		"fog_d":      18.0,
		"fairy":      true,
	},
	"brb": {
		"sky":        Color(0.847, 0.847, 0.878),
		"amb":        0.35,
		"amb_color":  Color(0.784, 0.784, 0.847),
		"key":        0.2,
		"key_color":  Color(0.816, 0.816, 0.910),
		"fill":       Color(0.690, 0.690, 0.784),
		"fill_i":     0.15,
		"rim":        Color(0.690, 0.690, 0.753),
		"rim_i":      0.1,
		"lamp":       0.4,
		"lamp_color": Color(0.533, 0.533, 0.627),
		"mon_i":      0.1,
		"mon_color":  Color(0.565, 0.565, 0.659),
		"fog_d":      9.0,
		"fairy":      false,
	},
	"starting": {
		"sky":        Color(1.000, 0.894, 0.878),
		"amb":        0.9,
		"amb_color":  Color(1.000, 0.800, 0.769),
		"key":        1.1,
		"key_color":  Color(1.000, 0.722, 0.596),
		"fill":       Color(1.000, 0.784, 0.690),
		"fill_i":     0.4,
		"rim":        Color(1.000, 0.600, 0.533),
		"rim_i":      0.5,
		"lamp":       2.0,
		"lamp_color": Color(1.000, 0.600, 0.400),
		"mon_i":      0.5,
		"mon_color":  Color(1.000, 0.533, 0.471),
		"fog_d":      18.0,
		"fairy":      true,
	},
	"ending": {
		"sky":        Color(0.094, 0.063, 0.094),
		"amb":        0.18,
		"amb_color":  Color(0.125, 0.063, 0.157),
		"key":        0.12,
		"key_color":  Color(0.125, 0.031, 0.094),
		"fill":       Color(0.094, 0.031, 0.125),
		"fill_i":     0.08,
		"rim":        Color(0.157, 0.031, 0.094),
		"rim_i":      0.1,
		"lamp":       0.5,
		"lamp_color": Color(0.290, 0.094, 0.188),
		"mon_i":      0.15,
		"mon_color":  Color(0.227, 0.063, 0.145),
		"fog_d":      7.0,
		"fairy":      false,
	},
}

var _current_mode : String            = "live"
var _lights_off   : bool              = false
var _time         : float             = 0.0

var _ambient_light : OmniLight3D       = null
var _sun_light     : DirectionalLight3D = null
var _fill_light    : DirectionalLight3D = null
var _rim_light     : DirectionalLight3D = null
var _lamp_light    : OmniLight3D       = null
var _mon_light     : OmniLight3D       = null
var _ceil_light    : OmniLight3D       = null

var _fairy_lights  : Array[OmniLight3D]    = []
var _fairy_meshes  : Array[MeshInstance3D] = []

var _world_env : WorldEnvironment = null

var _from_mode : Dictionary = {}
var _to_mode   : Dictionary = {}
var _mode_t    : float      = 1.0

var _monitor_screen_mat : ShaderMaterial = null
var _rng : RandomNumberGenerator = RandomNumberGenerator.new()

# ─── public api ───────────────────────────────────────────────────────────────

func build() -> void:
	_build_world_env()
	_build_floor()
	_build_ceiling()
	_build_walls()
	_build_molding()
	_build_rug()
	_build_window()
	_build_curtains()
	_build_desk()
	_build_desk_items()
	_build_desk_clutter()
	_build_bookshelf()
	_build_bed()
	_build_chair()
	_build_wall_art()
	_build_wall_shelf()
	_build_fairy_lights()
	_build_floor_clutter()
	_build_lights()
	print("[RoomBuilder] room built.")

func set_scene_mode(mode: String) -> void:
	if not MODES.has(mode) or mode == _current_mode:
		return
	_from_mode    = MODES[_current_mode].duplicate()
	_to_mode      = MODES[mode].duplicate()
	_current_mode = mode
	_mode_t       = 0.0

func set_lights_off(off: bool) -> void:
	_lights_off = off

func set_bloom(value: float) -> void:
	if _world_env == null:
		return
	var env := _world_env.environment
	env.glow_enabled   = value > 0.001
	env.glow_intensity = value * 0.12
	env.glow_bloom     = value * 0.04

# ─── process ──────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	_time += delta

	if _mode_t < 1.0:
		_mode_t = minf(1.0, _mode_t + delta * 0.8)
		_apply_mode_lerp(_mode_t)

	if _lamp_light and not _lights_off:
		_lamp_light.light_energy += sin(_time * 7.1) * 0.04 + sin(_time * 19.3) * 0.015

	var fairy_active : bool = MODES[_current_mode].get("fairy", true) and not _lights_off
	for i in _fairy_lights.size():
		var fl : OmniLight3D    = _fairy_lights[i]
		var fm : MeshInstance3D = _fairy_meshes[i] if i < _fairy_meshes.size() else null
		var ph  := float(i) * 0.4
		var target_e := (0.55 + sin(_time * 2.4 + ph) * 0.45) * 0.15 if fairy_active else 0.0
		fl.light_energy = lerp(fl.light_energy, target_e, delta * 5.0)
		if fm:
			var mat := fm.get_surface_override_material(0)
			if mat is StandardMaterial3D:
				var v := clampf(fl.light_energy / 0.15, 0.0, 1.0)
				(mat as StandardMaterial3D).albedo_color = Color(1.0, 0.85, 0.90, v)

	if _ceil_light:
		var target_ceil := 0.6 * (0.04 if _lights_off else 1.0)
		_ceil_light.light_energy = lerp(_ceil_light.light_energy, target_ceil, delta * 3.0)

	if _mon_light:
		var target_mon_i := float(MODES[_current_mode].get("mon_i", 0.45)) * (0.04 if _lights_off else 1.0)
		_mon_light.light_energy = lerp(_mon_light.light_energy, target_mon_i, delta * 3.0)

	if _monitor_screen_mat:
		_monitor_screen_mat.set_shader_parameter("time_offset", _time)

func _apply_mode_lerp(t: float) -> void:
	if _from_mode.is_empty() or _to_mode.is_empty():
		return
	var fr := _from_mode
	var to := _to_mode

	if _world_env:
		var env := _world_env.environment
		env.background_color = fr.sky.lerp(to.sky, t)
		env.fog_light_color  = fr.sky.lerp(to.sky, t)
		env.fog_density      = lerp(1.0 / float(fr.fog_d), 1.0 / float(to.fog_d), t)

	if _ambient_light:
		_ambient_light.light_energy = lerp(float(fr.amb), float(to.amb), t)
		_ambient_light.light_color  = (fr.amb_color as Color).lerp(to.amb_color, t)

	if _sun_light:
		_sun_light.light_energy = lerp(float(fr.key), float(to.key), t)
		_sun_light.light_color  = (fr.key_color as Color).lerp(to.key_color, t)

	if _fill_light:
		_fill_light.light_energy = lerp(float(fr.fill_i), float(to.fill_i), t)
		_fill_light.light_color  = (fr.fill as Color).lerp(to.fill, t)

	if _rim_light:
		_rim_light.light_energy = lerp(float(fr.rim_i), float(to.rim_i), t)
		_rim_light.light_color  = (fr.rim as Color).lerp(to.rim, t)

	if _lamp_light and not _lights_off:
		_lamp_light.light_color  = (fr.lamp_color as Color).lerp(to.lamp_color, t)
		var base_e : float       = lerp(float(fr.lamp), float(to.lamp), t)
		_lamp_light.light_energy = lerp(_lamp_light.light_energy, base_e, 0.1)

	if _mon_light:
		_mon_light.light_color = (fr.mon_color as Color).lerp(to.mon_color, t)

# ─── primitive helpers ────────────────────────────────────────────────────────

func _mat(color: Color, roughness: float = 0.88, unshaded: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness    = roughness
	m.metallic     = 0.0
	m.specular_mode = BaseMaterial3D.SPECULAR_TOON
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

func _box(size: Vector3, color: Color, pos: Vector3,
		parent: Node3D = null, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi   := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size            = size
	mi.mesh              = mesh
	mi.material_override = _mat(color)
	mi.position          = pos
	mi.rotation_degrees  = rot_deg
	mi.cast_shadow       = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	(parent if parent else self).add_child(mi)
	return mi

func _cyl(r_top: float, r_bot: float, h: float, color: Color,
		pos: Vector3, parent: Node3D = null,
		rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi   := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius    = r_top
	mesh.bottom_radius = r_bot
	mesh.height        = h
	mi.mesh            = mesh
	mi.material_override = _mat(color, 0.82)
	mi.position        = pos
	mi.rotation_degrees = rot_deg
	mi.cast_shadow     = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	(parent if parent else self).add_child(mi)
	return mi

func _sphere(r: float, color: Color, pos: Vector3,
		parent: Node3D = null) -> MeshInstance3D:
	var mi   := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius          = r
	mesh.height          = r * 2.0
	mi.mesh              = mesh
	mi.material_override = _mat(color, 0.85)
	mi.position          = pos
	mi.cast_shadow       = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	(parent if parent else self).add_child(mi)
	return mi

func _point(color: Color, energy: float, range_m: float,
		pos: Vector3, parent: Node3D = null) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color  = color
	l.light_energy = energy
	l.omni_range   = range_m
	l.position     = pos
	(parent if parent else self).add_child(l)
	return l

func _glow_sphere(r: float, color: Color, pos: Vector3,
		parent: Node3D = null) -> MeshInstance3D:
	var mi   := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = r
	mesh.height = r * 2.0
	mi.mesh     = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color             = color
	mat.emission_enabled         = true
	mat.emission                 = color
	mat.emission_energy_multiplier = 0.8
	mi.material_override         = mat
	mi.position                  = pos
	(parent if parent else self).add_child(mi)
	return mi

func _emission_mat(color: Color, energy: float = 1.2) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color             = color
	m.emission_enabled         = true
	m.emission                 = color
	m.emission_energy_multiplier = energy
	return m

# ─── shader material factories ────────────────────────────────────────────────

func _rim_mat(base_color: Color, rim_color: Color = Color(1.0, 0.85, 0.9),
		rim_power: float = 3.0, rim_strength: float = 0.18) -> ShaderMaterial:
	const CODE := """
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
uniform vec4 albedo       : source_color = vec4(1.0);
uniform vec4 rim_color    : source_color = vec4(1.0, 0.85, 0.9, 1.0);
uniform float rim_power   : hint_range(1.0, 8.0) = 3.0;
uniform float rim_strength: hint_range(0.0, 1.0) = 0.18;
void fragment() {
	ALBEDO = albedo.rgb;
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	EMISSION = rim_color.rgb * fresnel * rim_strength;
}
"""
	var sh := Shader.new()
	sh.code = CODE
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("albedo",        Color(base_color.r, base_color.g, base_color.b, 1.0))
	mat.set_shader_parameter("rim_color",     rim_color)
	mat.set_shader_parameter("rim_power",     rim_power)
	mat.set_shader_parameter("rim_strength",  rim_strength)
	return mat

func _scanline_mat(screen_color: Color = Color(0.04, 0.01, 0.04)) -> ShaderMaterial:
	const CODE := """
shader_type spatial;
render_mode unshaded, cull_back;
uniform vec4  screen_color      : source_color = vec4(0.04, 0.01, 0.04, 1.0);
uniform float scanline_density  : hint_range(80.0, 400.0) = 180.0;
uniform float scanline_strength : hint_range(0.0, 0.6) = 0.18;
uniform float phosphor_glow     : hint_range(0.0, 0.5) = 0.08;
uniform float time_offset       : hint_range(0.0, 100.0) = 0.0;
void fragment() {
	vec2  uv      = UV;
	float line    = sin(uv.y * scanline_density * 3.14159) * 0.5 + 0.5;
	float scan    = 1.0 - scanline_strength * (1.0 - line);
	vec2  vc      = uv * 2.0 - 1.0;
	float vign    = 1.0 - dot(vc, vc) * 0.35;
	float shimmer = sin(uv.x * 220.0 + time_offset * 0.5) * phosphor_glow;
	vec3  col     = screen_color.rgb * scan * vign;
	col += vec3(shimmer * 0.4, shimmer * 0.1, shimmer * 0.3);
	ALBEDO    = clamp(col, vec3(0.0), vec3(1.0));
	EMISSION  = clamp(col * 0.4, vec3(0.0), vec3(1.0));
}
"""
	var sh := Shader.new()
	sh.code = CODE
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("screen_color",      screen_color)
	mat.set_shader_parameter("scanline_density",  180.0)
	mat.set_shader_parameter("scanline_strength", 0.18)
	mat.set_shader_parameter("phosphor_glow",     0.08)
	mat.set_shader_parameter("time_offset",       0.0)
	return mat

func _wood_mat(base_color: Color, grain_strength: float = 0.06) -> ShaderMaterial:
	const CODE := """
shader_type spatial;
render_mode diffuse_lambert, specular_toon;
uniform vec4  albedo         : source_color = vec4(0.78, 0.63, 0.5, 1.0);
uniform float grain_strength : hint_range(0.0, 0.3) = 0.06;
uniform float roughness      : hint_range(0.0, 1.0) = 0.85;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float grain(vec3 pos) {
	float ring  = sin(pos.x * 18.0 + sin(pos.z * 4.0) * 1.2) * 0.5 + 0.5;
	float noise = hash(floor(pos.xz * 40.0)) * 0.15;
	return ring * grain_strength + noise * grain_strength * 0.4;
}
void fragment() {
	float g = grain(VERTEX);
	ALBEDO    = clamp(albedo.rgb + vec3(g*0.6, g*0.3, g*0.1) - g*0.15, vec3(0.0), vec3(1.0));
	ROUGHNESS = roughness;
	SPECULAR  = 0.1;
}
"""
	var sh := Shader.new()
	sh.code = CODE
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("albedo",         Color(base_color.r, base_color.g, base_color.b, 1.0))
	mat.set_shader_parameter("grain_strength", grain_strength)
	mat.set_shader_parameter("roughness",      0.85)
	return mat

# ─── poster label helper ──────────────────────────────────────────────────────

# creates a flat Label3D poster on a wall face
func _wall_poster(text: String, bg_color: Color, text_color: Color,
		pos: Vector3, rot_deg: Vector3, size_w: float = 0.65, size_h: float = 0.9) -> void:
	# backing plane
	var mi   := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size            = Vector3(size_w, size_h, 0.018)
	mi.mesh              = mesh
	mi.material_override = _mat(bg_color)
	mi.position          = pos
	mi.rotation_degrees  = rot_deg
	add_child(mi)

	# text label on poster surface
	var lbl := Label3D.new()
	lbl.text            = text
	lbl.font_size       = 28
	lbl.modulate        = text_color
	lbl.shading_mode    = BaseMaterial3D.SHADING_MODE_UNSHADED
	lbl.double_sided    = true
	lbl.pixel_size      = 0.002
	lbl.render_priority = 2
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode   = TextServer.AUTOWRAP_WORD_SMART
	lbl.width           = 280.0
	# offset slightly in front of backing
	var fwd := Vector3(
		sin(deg_to_rad(rot_deg.y)) * cos(deg_to_rad(rot_deg.x)),
		sin(deg_to_rad(-rot_deg.x)),
		cos(deg_to_rad(rot_deg.y)) * cos(deg_to_rad(rot_deg.x))
	).normalized() * 0.012
	lbl.position        = pos + fwd
	lbl.rotation_degrees = rot_deg
	add_child(lbl)

# ─── room construction ────────────────────────────────────────────────────────

func _build_world_env() -> void:
	_world_env = WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode  = Environment.BG_COLOR
	env.background_color = Color(1.0, 0.910, 0.941)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color  = Color(1.0, 0.878, 0.925)
	env.ambient_light_energy = 0.12
	env.fog_enabled      = true
	env.fog_light_color  = Color(1.0, 0.910, 0.941)
	env.fog_density      = 0.05
	env.glow_enabled              = true
	env.glow_intensity            = 0.06
	env.glow_bloom                = 0.02
	env.glow_strength             = 1.0
	env.glow_normalized           = true
	env.glow_hdr_threshold        = 0.85
	env.glow_hdr_scale            = 1.5
	env.tonemap_mode              = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure          = 0.85
	env.tonemap_white             = 1.0
	_world_env.environment = env
	add_child(_world_env)

func _build_floor() -> void:
	var floor_mi   := MeshInstance3D.new()
	var floor_mesh := BoxMesh.new()
	floor_mesh.size       = Vector3(10.0, 0.06, 10.0)
	floor_mi.mesh         = floor_mesh
	floor_mi.material_override = _rim_mat(
		Color(0.831, 0.627, 0.470),
		Color(1.0, 0.85, 0.72),
		4.0, 0.10
	)
	floor_mi.position = Vector3(0.0, -0.03, 0.0)
	add_child(floor_mi)

	var sb  := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shp := BoxShape3D.new()
	shp.size    = Vector3(10.0, 0.2, 10.0)
	col.shape   = shp
	sb.position = Vector3(0.0, -0.1, 0.0)
	add_child(sb)
	sb.add_child(col)

func _build_ceiling() -> void:
	_box(Vector3(10.0, 0.08, 10.0), Color(1.0, 0.973, 0.988), Vector3(0.0, 3.8, 0.0))

func _build_walls() -> void:
	var wc       := Color(0.996, 0.957, 0.973)
	var wall_mat := _rim_mat(wc, Color(1.0, 0.80, 0.90), 5.0, 0.08)

	# back wall (camera faces into room)
	var bw      := MeshInstance3D.new()
	var bw_mesh := BoxMesh.new()
	bw_mesh.size        = Vector3(10.0, 7.6, 0.08)
	bw.mesh             = bw_mesh
	bw.material_override = wall_mat
	bw.position         = Vector3(0.0, 3.8, 2.0)
	add_child(bw)

	# front wall (behind camera/desk)
	var fw      := MeshInstance3D.new()
	var fw_mesh := BoxMesh.new()
	fw_mesh.size        = Vector3(10.0, 7.6, 0.08)
	fw.mesh             = fw_mesh
	fw.material_override = wall_mat
	fw.position         = Vector3(0.0, 3.8, -2.8)
	add_child(fw)

	# right wall
	var rw      := MeshInstance3D.new()
	var rw_mesh := BoxMesh.new()
	rw_mesh.size        = Vector3(0.08, 7.6, 10.0)
	rw.mesh             = rw_mesh
	rw.material_override = wall_mat
	rw.position         = Vector3(3.5, 3.8, -0.4)
	add_child(rw)

	# left wall lower
	var lw_bot      := MeshInstance3D.new()
	var lw_bot_mesh := BoxMesh.new()
	lw_bot_mesh.size = Vector3(0.08, 0.65, 6.0)
	lw_bot.mesh      = lw_bot_mesh
	lw_bot.position  = Vector3(-3.5, 0.325, -0.4)
	add_child(lw_bot)

	# left wall upper
	var lw_top      := MeshInstance3D.new()
	var lw_top_mesh := BoxMesh.new()
	lw_top_mesh.size = Vector3(0.08, 5.1, 6.0)
	lw_top.mesh      = lw_top_mesh
	lw_top.position  = Vector3(-3.5, 5.25, -0.4)
	add_child(lw_top)

	# left wall window sides
	var lw_left      := MeshInstance3D.new()
	var lw_left_mesh := BoxMesh.new()
	lw_left_mesh.size = Vector3(0.08, 2.2, 2.0)
	lw_left.mesh      = lw_left_mesh
	lw_left.material_override = wall_mat
	lw_left.position  = Vector3(-3.5, 1.7, -1.9)
	add_child(lw_left)

	var lw_right      := MeshInstance3D.new()
	var lw_right_mesh := BoxMesh.new()
	lw_right_mesh.size = Vector3(0.08, 2.2, 1.2)
	lw_right.mesh      = lw_right_mesh
	lw_right.material_override = wall_mat
	lw_right.position  = Vector3(-3.5, 1.7, 1.4)
	add_child(lw_right)

func _build_molding() -> void:
	var mol := Color(1.0, 0.941, 0.969)
	_box(Vector3(10.0, 0.12, 0.12), mol, Vector3(0.0, 3.72,  2.0))
	_box(Vector3(10.0, 0.12, 0.12), mol, Vector3(0.0, 3.72, -2.8))
	_box(Vector3(0.12, 0.12, 10.0), mol, Vector3(-3.5, 3.72, -0.4))
	_box(Vector3(0.12, 0.12, 10.0), mol, Vector3( 3.5, 3.72, -0.4))

	var bc := Color(1.0, 0.910, 0.941)
	_box(Vector3(10.0, 0.1, 0.08), bc, Vector3(0.0, 0.05,  1.95))
	_box(Vector3(10.0, 0.1, 0.08), bc, Vector3(0.0, 0.05, -2.75))
	_box(Vector3(0.08, 0.1, 10.0), bc, Vector3(-3.45, 0.05, -0.4))
	_box(Vector3(0.08, 0.1, 10.0), bc, Vector3( 3.45, 0.05, -0.4))

func _build_rug() -> void:
	_box(Vector3(2.4, 0.012, 1.8), Color(0.941, 0.722, 0.800), Vector3(0.0, 0.006, 0.2))

func _build_window() -> void:
	var fc := Color(1.0, 0.957, 0.973)
	var glass_mi   := MeshInstance3D.new()
	var glass_mesh := BoxMesh.new()
	glass_mesh.size     = Vector3(0.04, 1.88, 1.36)
	glass_mi.mesh       = glass_mesh
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color   = Color(0.85, 0.95, 1.0, 0.35)
	gmat.transparency   = BaseMaterial3D.TRANSPARENCY_ALPHA
	gmat.cull_mode      = BaseMaterial3D.CULL_DISABLED
	glass_mi.material_override = gmat
	glass_mi.position   = Vector3(-3.46, 1.7, 0.2)
	add_child(glass_mi)

	_box(Vector3(0.055, 1.88, 0.05), fc, Vector3(-3.47, 1.7, 0.2))
	_box(Vector3(0.055, 0.05, 1.36), fc, Vector3(-3.47, 1.7, 0.2))
	_box(Vector3(0.05, 0.05, 1.9),  Color(0.784, 0.627, 0.706), Vector3(-3.38, 2.68, 0.2))

	var og := _point(Color(1.0, 0.973, 0.878), 1.2, 3.5, Vector3(-4.0, 1.7, 0.2))
	og.name = "OutsideGlow"

func _build_curtains() -> void:
	var cc := Color(0.910, 0.565, 0.659)
	_box(Vector3(0.04, 2.3, 0.55), cc, Vector3(-3.38, 1.7,  0.98))
	_box(Vector3(0.04, 2.3, 0.55), cc, Vector3(-3.38, 1.7, -0.52))

# ─── desk (rotated 180°, tighter to camera) ───────────────────────────────────

func _build_desk() -> void:
	var desk := Node3D.new()
	desk.name              = "Desk"
	desk.position          = Vector3(0.0, 0.0, -0.15)
	desk.rotation_degrees  = Vector3(0.0, 180.0, 0.0)
	add_child(desk)

	var dk := Color(0.784, 0.627, 0.500)
	var lg := Color(0.722, 0.565, 0.440)

	var top_mi   := MeshInstance3D.new()
	var top_mesh := BoxMesh.new()
	top_mesh.size        = Vector3(2.0, 0.07, 0.82)
	top_mi.mesh          = top_mesh
	top_mi.material_override = _wood_mat(dk, 0.07)
	top_mi.position      = Vector3(0.0, 0.75, 0.0)
	desk.add_child(top_mi)

	_box(Vector3(2.0, 0.65, 0.04), lg, Vector3(0.0, 0.425, 0.42), desk)

	for lx : float in [-0.94, 0.94]:
		for lz : float in [-0.36, 0.36]:
			_cyl(0.028, 0.022, 0.75, lg, Vector3(lx, 0.375, lz), desk)

	# main monitor
	_box(Vector3(0.92, 0.60, 0.058), Color(0.941, 0.894, 0.925), Vector3(0.0, 1.12, 0.28), desk)
	var screen_mi   := MeshInstance3D.new()
	var screen_mesh := BoxMesh.new()
	screen_mesh.size      = Vector3(0.86, 0.54, 0.008)
	screen_mi.mesh        = screen_mesh
	_monitor_screen_mat   = _scanline_mat(Color(0.04, 0.01, 0.08))
	screen_mi.material_override = _monitor_screen_mat
	screen_mi.position    = Vector3(0.0, 1.12, 0.252)
	desk.add_child(screen_mi)

	# monitor stand
	_box(Vector3(0.06, 0.24, 0.06), Color(0.878, 0.816, 0.847), Vector3(0.0, 0.88, 0.28), desk)
	_box(Vector3(0.36, 0.025, 0.28), Color(0.878, 0.816, 0.847), Vector3(0.0, 0.76, 0.28), desk)

	# secondary monitor (angled left)
	var sm := Node3D.new()
	sm.position         = Vector3(0.82, 0.0, 0.05)
	sm.rotation_degrees = Vector3(0.0, 22.0, 0.0)
	desk.add_child(sm)
	_box(Vector3(0.56, 0.38, 0.05), Color(0.941, 0.894, 0.925), Vector3(0.0, 1.05, 0.26), sm)
	_box(Vector3(0.50, 0.32, 0.006), Color(0.02, 0.01, 0.03),   Vector3(0.0, 1.05, 0.234), sm)
	_box(Vector3(0.03, 0.15, 0.03), Color(0.878, 0.816, 0.847), Vector3(0.0, 0.88, 0.26), sm)
	_box(Vector3(0.20, 0.02, 0.18), Color(0.878, 0.816, 0.847), Vector3(0.0, 0.76, 0.26), sm)

	_mon_light          = OmniLight3D.new()
	_mon_light.position = Vector3(0.0, 1.05, -0.5)
	_mon_light.light_color  = Color(1.0, 0.667, 0.784)
	_mon_light.light_energy = 0.45
	_mon_light.omni_range   = 2.5
	add_child(_mon_light)

func _build_desk_items() -> void:
	var desk := get_node_or_null("Desk")
	if desk == null:
		return

	# keyboard
	_box(Vector3(0.60, 0.018, 0.20), Color(0.988, 0.925, 0.957), Vector3(-0.08, 0.769, -0.14), desk)
	for r : int in 4:
		for k : int in 14:
			var kc := Color(1.0, 0.878, 0.933) if r == 0 else Color(1.0, 0.957, 0.973)
			_box(Vector3(0.032, 0.011, 0.028), kc,
				Vector3(-0.28 + k * 0.042, 0.781, -0.065 - r * 0.044), desk)

	# mouse
	var mouse_mi   := MeshInstance3D.new()
	var mouse_mesh := SphereMesh.new()
	mouse_mesh.radius        = 0.04
	mouse_mesh.height        = 0.08
	mouse_mi.mesh            = mouse_mesh
	mouse_mi.material_override = _mat(Color(0.988, 0.925, 0.957))
	mouse_mi.scale           = Vector3(1.0, 0.5, 1.4)
	mouse_mi.position        = Vector3(0.40, 0.762, -0.14)
	desk.add_child(mouse_mi)

	# mug
	_cyl(0.048, 0.038, 0.11, Color(1.0, 0.980, 0.988), Vector3(-0.80, 0.806, -0.10), desk)

	# plant pot
	_cyl(0.052, 0.038, 0.10, Color(0.878, 0.533, 0.533), Vector3(0.78, 0.80, -0.06), desk)
	_sphere(0.065, Color(0.310, 0.659, 0.188), Vector3(0.78, 0.928, -0.06), desk)

	# desk lamp
	_box(Vector3(0.024, 0.38, 0.024), Color(0.847, 0.690, 0.753), Vector3(0.60, 0.96, 0.22), desk)
	_box(Vector3(0.26, 0.024, 0.024), Color(0.847, 0.690, 0.753), Vector3(0.47, 1.18, 0.20), desk)
	_box(Vector3(0.024, 0.30, 0.024), Color(0.847, 0.690, 0.753), Vector3(0.34, 1.30, 0.18), desk)
	var shade_mi   := MeshInstance3D.new()
	var shade_mesh := CylinderMesh.new()
	shade_mesh.top_radius    = 0.001
	shade_mesh.bottom_radius = 0.13
	shade_mesh.height        = 0.14
	shade_mi.mesh            = shade_mesh
	shade_mi.material_override = _mat(Color(1.0, 0.878, 0.925))
	shade_mi.position        = Vector3(0.26, 1.38, 0.18)
	shade_mi.rotation_degrees = Vector3(0.0, 0.0, -12.0)
	desk.add_child(shade_mi)

	_lamp_light          = OmniLight3D.new()
	_lamp_light.position = Vector3(0.4, 1.05, -0.18)
	_lamp_light.light_color  = Color(1.0, 0.800, 0.533)
	_lamp_light.light_energy = 1.6
	_lamp_light.omni_range   = 5.0
	add_child(_lamp_light)

	# sticky notes
	var note_colors := [Color(1.0, 0.933, 0.533), Color(1.0, 0.733, 0.867), Color(0.667, 0.933, 0.733)]
	for ni : int in 3:
		var note := _box(Vector3(0.14, 0.12, 0.005), note_colors[ni],
			Vector3(0.22 - ni * 0.18, 0.784, -0.26), desk)
		note.rotation_degrees.z = (ni - 1.0) * 5.0

func _build_desk_clutter() -> void:
	# extra mess on the desk: stacked books, energy drink cans, cables
	var desk := get_node_or_null("Desk")
	if desk == null:
		return

	var book_c := [Color(0.88, 0.19, 0.29), Color(0.24, 0.45, 0.78), Color(0.22, 0.62, 0.35)]
	for i in 3:
		_box(
			Vector3(0.20 + i * 0.015, 0.28 - i * 0.04, 0.055),
			book_c[i],
			Vector3(-0.88 + i * 0.025, 0.89 + i * 0.15, 0.10),
			desk,
			Vector3(0.0, randf_range(-8.0, 8.0), 0.0)
		)

	# energy drink cans (lying on side)
	for i in 2:
		_cyl(0.033, 0.033, 0.115, Color(0.72, 0.18, 0.24),
			Vector3(-0.60 + i * 0.15, 0.783, 0.10 + i * 0.04),
			desk, Vector3(90.0, randf_range(-15.0, 15.0), 0.0))

	# headphones on desk corner
	var hp_arc := MeshInstance3D.new()
	var hp_m   := CapsuleMesh.new()
	hp_m.radius     = 0.085
	hp_m.height     = 0.22
	hp_arc.mesh     = hp_m
	hp_arc.material_override = _mat(Color(0.18, 0.18, 0.22))
	hp_arc.position = Vector3(0.85, 0.84, 0.06)
	hp_arc.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	desk.add_child(hp_arc)

func _build_bookshelf() -> void:
	var wood := Color(0.784, 0.533, 0.376)
	var dark  := Color(0.690, 0.439, 0.282)
	_box(Vector3(0.92, 2.40, 0.32), wood, Vector3(-2.8, 1.2, 1.6))
	for s : int in 4:
		_box(Vector3(0.88, 0.04, 0.30), dark, Vector3(-2.8, 0.24 + s * 0.58, 1.6))

	var book_colors := [
		Color(0.878, 0.188, 0.290), Color(0.941, 0.376, 0.44),
		Color(1.000, 0.761, 0.80),  Color(0.784, 0.322, 0.478),
		Color(1.000, 0.702, 0.776), Color(0.667, 0.125, 0.251),
		Color(0.957, 0.561, 0.694), Color(0.910, 0.627, 0.690),
		Color(0.831, 0.376, 0.500), Color(1.000, 0.561, 0.659),
	]
	_rng.seed = 55
	var bx := -3.22
	for i : int in 24:
		var bw    := 0.055 + _rng.randf() * 0.055
		var bh    := 0.30  + _rng.randf() * 0.22
		var shelf := i / 6
		var by    := 0.30 + shelf * 0.58 + bh * 0.5
		var bc    : Color = book_colors[_rng.randi() % book_colors.size()]
		var tilt  := Vector3(0.0, randf_range(-6.0, 6.0), randf_range(-4.0, 4.0))
		var bk    := _box(Vector3(bw, bh, 0.24), bc, Vector3(bx, by, 1.48))
		bk.rotation_degrees = tilt
		bx += bw + 0.012
		if bx > -2.40:
			bx = -3.22

	var top_y := 0.30 + 3 * 0.58 + 0.12
	_cyl(0.04, 0.03, 0.08, Color(0.910, 0.533, 0.376), Vector3(-2.48, top_y, 1.56))
	_cyl(0.022, 0.022, 0.14, Color(1.0, 0.941, 0.878), Vector3(-3.05, top_y + 0.01, 1.56))
	var flame_mi := MeshInstance3D.new()
	var fmesh    := CylinderMesh.new()
	fmesh.top_radius    = 0.001
	fmesh.bottom_radius = 0.015
	fmesh.height        = 0.04
	flame_mi.mesh       = fmesh
	flame_mi.material_override = _emission_mat(Color(1.0, 0.800, 0.267), 1.2)
	flame_mi.position   = Vector3(-3.05, top_y + 0.10, 1.56)
	add_child(flame_mi)
	_point(Color(1.0, 0.667, 0.267), 0.3, 1.2, Vector3(-3.05, top_y + 0.12, 1.56)).name = "CandleLight"

func _build_bed() -> void:
	var bed := Node3D.new()
	bed.name     = "Bed"
	bed.position = Vector3(2.2, 0.0, 1.1)
	add_child(bed)

	_box(Vector3(1.55, 0.18, 2.6),  Color(0.784, 0.596, 0.470), Vector3(0.0, 0.09,  0.0),  bed)
	_box(Vector3(1.42, 0.20, 2.4),  Color(1.000, 0.973, 0.980), Vector3(0.0, 0.29,  0.0),  bed)
	_box(Vector3(1.38, 0.12, 1.7),  Color(0.941, 0.690, 0.769), Vector3(0.0, 0.42, -0.32), bed)
	_box(Vector3(1.36, 0.06, 0.20), Color(0.973, 0.816, 0.878), Vector3(0.0, 0.40,  0.55), bed)
	_box(Vector3(1.55, 0.80, 0.10), Color(0.784, 0.596, 0.470), Vector3(0.0, 0.54,  1.36), bed)
	_box(Vector3(0.46, 0.60, 0.08), Color(0.847, 0.659, 0.533), Vector3(-0.48, 0.50, 1.32), bed)
	_box(Vector3(0.46, 0.60, 0.08), Color(0.847, 0.659, 0.533), Vector3( 0.48, 0.50, 1.32), bed)
	_box(Vector3(1.55, 0.30, 0.08), Color(0.784, 0.596, 0.470), Vector3(0.0, 0.24, -1.32), bed)
	_box(Vector3(0.52, 0.10, 0.40), Color(1.0, 0.933, 0.957), Vector3(-0.34, 0.39, 1.02), bed)
	_box(Vector3(0.44, 0.10, 0.40), Color(1.0, 0.933, 0.957), Vector3( 0.32, 0.39, 1.02), bed)

	_sphere(0.12,  Color(1.0, 0.800, 0.847), Vector3(-0.42, 0.50, 0.50), bed)
	_sphere(0.085, Color(1.0, 0.800, 0.847), Vector3(-0.42, 0.64, 0.50), bed)
	for ex : float in [-0.055, 0.055]:
		_sphere(0.034, Color(1.0, 0.800, 0.847), Vector3(-0.42 + ex, 0.712, 0.50), bed)
		_sphere(0.018, Color(1.0, 0.690, 0.753), Vector3(-0.42 + ex * 0.8, 0.705, 0.49), bed)

	# clothes pile on bed
	_box(Vector3(0.42, 0.06, 0.32), Color(0.35, 0.30, 0.60), Vector3(0.38, 0.40, -0.65), bed)
	_box(Vector3(0.36, 0.05, 0.28), Color(0.22, 0.22, 0.22), Vector3(0.40, 0.46, -0.62), bed)

func _build_chair() -> void:
	var chair := Node3D.new()
	chair.name            = "Chair"
	chair.position        = Vector3(0.0, 0.0, -0.2)
	chair.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	add_child(chair)

	var seat_c  := Color(0.941, 0.784, 0.847)
	var seat_c2 := Color(1.000, 0.847, 0.910)
	var arm_c   := Color(0.847, 0.659, 0.722)
	var leg_c   := Color(0.753, 0.627, 0.690)

	_box(Vector3(0.66, 0.06, 0.56), seat_c,  Vector3(0.0, 0.47, 0.0), chair)
	_box(Vector3(0.62, 0.04, 0.52), seat_c2, Vector3(0.0, 0.515, 0.0), chair)
	_box(Vector3(0.66, 0.58, 0.07), seat_c,  Vector3(0.0, 0.78, 0.245), chair)
	_box(Vector3(0.62, 0.52, 0.04), seat_c2, Vector3(0.0, 0.78, 0.24), chair)

	for ax : float in [-0.35, 0.35]:
		_box(Vector3(0.055, 0.14, 0.36), arm_c,  Vector3(ax, 0.58, -0.04), chair)
		_box(Vector3(0.18,  0.04, 0.36), seat_c, Vector3(ax, 0.664, -0.04), chair)

	var base_r := 0.38
	for a : int in 5:
		var ang   := float(a) / 5.0 * TAU
		var spoke := _cyl(0.018, 0.018, base_r, leg_c,
			Vector3(cos(ang) * base_r * 0.5, 0.05, sin(ang) * base_r * 0.5), chair,
			Vector3(0.0, 0.0, 90.0))
		spoke.rotation.y = ang
		_sphere(0.028, Color(0.533, 0.502, 0.502), Vector3(cos(ang) * base_r, 0.028, sin(ang) * base_r), chair)

	_cyl(0.025, 0.025, 0.40, leg_c, Vector3(0.0, 0.22, 0.0), chair)

func _build_wall_art() -> void:
	# asymmetric posters using Label3D so they always render correctly
	_wall_poster(
		"NEET\nLIFE\n★",
		Color(0.10, 0.05, 0.15),
		Color(0.90, 0.35, 0.85),
		Vector3(-0.6, 2.3, 1.96),
		Vector3(0.0, 180.0, 0.0),
		0.58, 0.80
	)
	_wall_poster(
		"oshi\nno\nこ",
		Color(0.08, 0.06, 0.18),
		Color(1.00, 0.82, 0.30),
		Vector3( 0.55, 2.1, 1.96),
		Vector3(0.0, 180.0, 0.0),
		0.46, 0.64
	)
	_wall_poster(
		"zzz...",
		Color(0.15, 0.06, 0.06),
		Color(1.00, 0.55, 0.55),
		Vector3( 1.55, 1.85, 1.96),
		Vector3(0.0, 180.0, 0.0),
		0.38, 0.50
	)
	# poster on right wall (tilted slightly)
	_wall_poster(
		"TOUCH\nGRASS\n(later)",
		Color(0.05, 0.12, 0.08),
		Color(0.40, 0.90, 0.55),
		Vector3(3.44, 2.0, 0.6),
		Vector3(0.0, -90.0, 0.0),
		0.52, 0.70
	)

func _build_wall_shelf() -> void:
	_box(Vector3(1.60, 0.06, 0.22), Color(0.784, 0.533, 0.376), Vector3(-0.1, 2.0, 1.92))

	_rng.seed = 88
	var book_colors := [
		Color(0.878, 0.188, 0.290), Color(0.941, 0.376, 0.44),
		Color(1.000, 0.761, 0.80),  Color(0.784, 0.322, 0.478),
		Color(1.000, 0.702, 0.776), Color(0.667, 0.125, 0.251),
	]
	for i : int in 6:
		var sw := 0.06 + _rng.randf() * 0.04
		var sh := 0.14 + _rng.randf() * 0.16
		var bc : Color = book_colors[i % book_colors.size()]
		_box(Vector3(sw, sh, 0.16), bc, Vector3(-0.74 + i * 0.26, 2.03 + sh * 0.5, 1.88))

	_cyl(0.04, 0.032, 0.14, Color(0.941, 0.753, 0.816), Vector3(0.6, 2.10, 1.88))
	_sphere(0.048, Color(1.000, 0.816, 0.753), Vector3(0.6, 2.21, 1.88))

func _build_fairy_lights() -> void:
	for i : int in 28:
		var t_val := float(i) / 27.0
		var hue   := 0.92 + t_val * 0.08
		var col   := Color.from_hsv(hue, 0.9, 0.85)
		var x_pos := -3.0 + float(i) * 0.22
		var pos   := Vector3(x_pos, 3.1, 1.94)
		var mi    := _glow_sphere(0.022, col, pos)
		_fairy_meshes.append(mi)
		var fl := _point(col, 0.10, 0.55, pos)
		_fairy_lights.append(fl)

	for i : int in 27:
		var p1  := _fairy_meshes[i].position
		var p2  := _fairy_meshes[i + 1].position
		var mid := (p1 + p2) * 0.5
		mid.y -= 0.04
		_sphere(0.006, Color(0.502, 0.376, 0.439), mid)

# ─── floor clutter (NEET chaos) ───────────────────────────────────────────────

func _build_floor_clutter() -> void:
	_rng.seed = 137

	var manga_colors := [
		Color(0.88, 0.18, 0.28), Color(0.20, 0.38, 0.72),
		Color(0.18, 0.55, 0.30), Color(0.72, 0.55, 0.12),
		Color(0.55, 0.18, 0.55), Color(0.88, 0.55, 0.18),
	]

	# scattered manga/books on floor
	for i in 12:
		var bw  := 0.18 + _rng.randf() * 0.08
		var bh  := 0.24 + _rng.randf() * 0.10
		var x   := _rng.randf_range(-2.8, 2.8)
		var z   := _rng.randf_range(-1.0, 1.8)
		# avoid desk area
		if absf(x) < 1.2 and z > -0.8 and z < 0.6:
			x += sign(x) * 1.5
		var bc  : Color = manga_colors[_rng.randi() % manga_colors.size()]
		var flat := _box(
			Vector3(bw, 0.022, bh),
			bc,
			Vector3(x, 0.011, z)
		)
		flat.rotation_degrees.y = _rng.randf_range(-35.0, 35.0)

	# crumpled paper spheres
	for i in 8:
		var r  := 0.03 + _rng.randf() * 0.02
		var x  := _rng.randf_range(-2.4, 2.4)
		var z  := _rng.randf_range(-1.2, 1.5)
		_sphere(r, Color(0.92, 0.90, 0.86), Vector3(x, r, z))

	# empty snack bags (flat quads)
	for i in 5:
		var x   := _rng.randf_range(-2.2, 2.2)
		var z   := _rng.randf_range(-0.8, 1.4)
		var w   := 0.14 + _rng.randf() * 0.06
		var snack_c := Color(_rng.randf_range(0.6, 1.0), _rng.randf_range(0.4, 0.9), _rng.randf_range(0.2, 0.6))
		var sn  := _box(Vector3(w, 0.012, w * 1.3), snack_c, Vector3(x, 0.006, z))
		sn.rotation_degrees.y = _rng.randf_range(-50.0, 50.0)

	# empty cans standing up and knocked over
	for i in 6:
		var x  := _rng.randf_range(-2.6, 2.6)
		var z  := _rng.randf_range(-1.0, 1.6)
		var knocked : bool = _rng.randf() > 0.5
		var can_c := Color(0.60 + _rng.randf() * 0.3, 0.18, 0.24)
		if knocked:
			_cyl(0.033, 0.033, 0.115, can_c, Vector3(x, 0.033, z), null, Vector3(90.0, _rng.randf_range(-40.0, 40.0), 0.0))
		else:
			_cyl(0.033, 0.033, 0.115, can_c, Vector3(x, 0.058, z))

	# small clutter cubes / misc objects
	for i in 10:
		var s  := 0.04 + _rng.randf() * 0.06
		var x  := _rng.randf_range(-2.8, 2.8)
		var z  := _rng.randf_range(-1.2, 1.6)
		var cc := Color(_rng.randf_range(0.4, 0.9), _rng.randf_range(0.3, 0.8), _rng.randf_range(0.3, 0.9))
		var cb := _box(Vector3(s, s * 0.7, s * 1.1), cc, Vector3(x, s * 0.35, z))
		cb.rotation_degrees.y = _rng.randf_range(-90.0, 90.0)

	# cable mess near desk
	for i in 3:
		var cx := -0.4 + i * 0.14
		var cz := 0.38 + i * 0.06
		_cyl(0.006, 0.006, 0.35 + i * 0.08,
			Color(0.18, 0.18, 0.18),
			Vector3(cx, 0.005, cz), null,
			Vector3(90.0, _rng.randf_range(-60.0, 60.0), 0.0))

# ─── lights ───────────────────────────────────────────────────────────────────

func _build_lights() -> void:
	_ambient_light              = OmniLight3D.new()
	_ambient_light.name         = "AmbientFill"
	_ambient_light.position     = Vector3(0.0, 3.6, 0.0)
	_ambient_light.light_color  = Color(1.000, 0.878, 0.925)
	_ambient_light.light_energy = 0.55
	_ambient_light.omni_range   = 12.0
	_ambient_light.omni_attenuation = 0.6
	add_child(_ambient_light)

	_sun_light                  = DirectionalLight3D.new()
	_sun_light.name             = "SunKey"
	_sun_light.rotation_degrees = Vector3(-55.0, 40.0, 0.0)
	_sun_light.light_color      = Color(1.000, 0.957, 0.910)
	_sun_light.light_energy     = 0.9
	_sun_light.shadow_enabled   = true
	_sun_light.shadow_blur      = 0.5
	add_child(_sun_light)

	_fill_light                  = DirectionalLight3D.new()
	_fill_light.name             = "Fill"
	_fill_light.rotation_degrees = Vector3(-30.0, -130.0, 0.0)
	_fill_light.light_color      = Color(0.78, 0.75, 1.000)
	_fill_light.light_energy     = 0.3
	add_child(_fill_light)

	_rim_light                  = DirectionalLight3D.new()
	_rim_light.name             = "Rim"
	_rim_light.rotation_degrees = Vector3(-10.0, 175.0, 0.0)
	_rim_light.light_color      = Color(1.000, 0.722, 0.800)
	_rim_light.light_energy     = 0.25
	add_child(_rim_light)

	_ceil_light              = OmniLight3D.new()
	_ceil_light.name         = "CeilFill"
	_ceil_light.position     = Vector3(0.0, 3.3, 0.0)
	_ceil_light.light_color  = Color(1.000, 0.941, 0.973)
	_ceil_light.light_energy = 0.35
	_ceil_light.omni_range   = 6.0
	add_child(_ceil_light)

	_from_mode = MODES["live"].duplicate()
	_to_mode   = MODES["live"].duplicate()
