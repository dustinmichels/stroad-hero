extends Node3D

const FLASH_STEP_SECONDS := 0.08
const FLASH_STEPS := 12
const SAMPLE_RATE := 22050
const WAIL_SECONDS := 3

static var _wail_stream: AudioStreamWAV

## Lights and wail together; `siren_audible` mutes the wail while the lights keep flashing.
@export var siren_active: bool = true:
	set(value):
		siren_active = value
		if _audio != null:
			_apply_active()
@export var siren_audible: bool = true:
	set(value):
		siren_audible = value
		if _audio != null:
			_apply_audio()

var _audio: AudioStreamPlayer3D
var _red_materials: Array[StandardMaterial3D] = []
var _blue_materials: Array[StandardMaterial3D] = []
var _flash_time := 0.0
var _flash_step := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_collect_lenses(get_node_or_null("SirenRed"), _red_materials)
	_collect_lenses(get_node_or_null("SirenBlue"), _blue_materials)
	_audio = AudioStreamPlayer3D.new()
	_audio.name = "SirenAudio"
	_audio.stream = get_wail_stream()
	_audio.volume_db = -15.0
	_audio.max_db = -9.0
	_audio.unit_size = 8.0
	_audio.max_distance = 85.0
	add_child(_audio)
	_apply_active()


func _process(delta: float) -> void:
	_flash_time = fmod(_flash_time + delta, FLASH_STEP_SECONDS * FLASH_STEPS)
	_update_flashes()


func _apply_active() -> void:
	set_process(siren_active)
	_flash_time = 0.0
	_flash_step = -1
	_update_flashes()
	_apply_audio()


func _apply_audio() -> void:
	if siren_active and siren_audible:
		if not _audio.playing:
			_audio.play()
	else:
		_audio.stop()


func _update_flashes() -> void:
	var step := int(_flash_time / FLASH_STEP_SECONDS) if siren_active else -2
	if step == _flash_step:
		return
	_flash_step = step
	_set_emission(_red_materials, step == 0 or step == 2)
	_set_emission(_blue_materials, step == 6 or step == 8)


func _set_emission(materials: Array[StandardMaterial3D], enabled: bool) -> void:
	for material in materials:
		material.emission_enabled = enabled


func _collect_lenses(node: Node, materials: Array[StandardMaterial3D]) -> void:
	if node == null:
		return
	if node is MeshInstance3D:
		var lens := node as MeshInstance3D
		if lens.mesh != null:
			# Duplicate surface materials, never the shared mesh or another car's lenses.
			for surface in range(lens.mesh.get_surface_count()):
				var source := lens.get_active_material(surface) as StandardMaterial3D
				if source != null:
					var material := source.duplicate() as StandardMaterial3D
					lens.set_surface_override_material(surface, material)
					materials.append(material)
			lens.material_override = null
	for child in node.get_children():
		_collect_lenses(child, materials)


static func get_wail_stream() -> AudioStreamWAV:
	if _wail_stream != null:
		return _wail_stream
	var sample_count := SAMPLE_RATE * WAIL_SECONDS
	var samples := PackedByteArray()
	samples.resize(sample_count * 2)
	for index in range(sample_count):
		var time := float(index) / SAMPLE_RATE
		# 550–1150 Hz sweep: an integer number of carrier cycles makes the loop seamless.
		var phase := TAU * 850.0 * time - 300.0 * WAIL_SECONDS * sin(TAU * time / WAIL_SECONDS)
		var wave := 0.75 * sin(phase) + 0.18 * sin(2.0 * phase) + 0.07 * sin(3.0 * phase)
		var sample := int(wave * 0.65 * 32767.0)
		samples.encode_u16(index * 2, sample & 0xffff)
	_wail_stream = AudioStreamWAV.new()
	_wail_stream.format = AudioStreamWAV.FORMAT_16_BITS
	_wail_stream.mix_rate = SAMPLE_RATE
	_wail_stream.stereo = false
	_wail_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_wail_stream.loop_begin = 0
	_wail_stream.loop_end = sample_count
	_wail_stream.data = samples
	return _wail_stream
