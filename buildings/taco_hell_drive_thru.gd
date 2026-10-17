extends Node3D

## Functional controller for Taco Hell Drive-Thru.
## Dynamically updates the menu board LCD screen, order speaker status LED,
## and pickup window signage when vehicles or Mats approach.

@onready var lcd_label: Label3D = get_node_or_null("MenuBoard/LcdLabel")
@onready var speaker_led: MeshInstance3D = get_node_or_null("OrderingSpeaker/Housing/StatusLed")
@onready var pickup_label: Label3D = get_node_or_null("PickupLabel")

var _order_number: int = 24
var _was_order_active: bool = false
var _was_pickup_active: bool = false

const IDLE_LCD_TEXT := "[ORDER CONFIRMATION]\nWELCOME TO TACO HELL\nPLEASE ORDER AT SPEAKER"
const IDLE_PICKUP_TEXT := "PICK UP"

const ORDERS := [
	"[ORDER #%d - CONFIRMED]\n1x CRUNCHWRAP INFERNO\n1x BAJA BLAST (LARGE)\nTOTAL: $9.58 • PULL FORWARD",
	"[ORDER #%d - CONFIRMED]\n2x CHEESY GORDITA HELL\n1x DIABLO FREEZE\nTOTAL: $11.48 • PULL FORWARD",
	"[ORDER #%d - CONFIRMED]\n3x CRUNCHY TACO COMBO\n1x NACHO FRIES DELUXE\nTOTAL: $10.98 • PULL FORWARD",
	"[ORDER #%d - CONFIRMED]\n1x BURRITO SUPREME\n1x CINNAMON TWISTS\nTOTAL: $6.98 • PULL FORWARD",
]

var _led_active_material: StandardMaterial3D = null
var _led_idle_material: StandardMaterial3D = null


func _ready() -> void:
	_init_materials()
	_update_lcd_idle()


func _init_materials() -> void:
	_led_idle_material = StandardMaterial3D.new()
	_led_idle_material.albedo_color = Color(0.96, 0.72, 0.08, 1.0)
	_led_idle_material.emission_enabled = true
	_led_idle_material.emission = Color(0.96, 0.72, 0.08, 1.0)
	_led_idle_material.emission_energy_multiplier = 0.4

	_led_active_material = StandardMaterial3D.new()
	_led_active_material.albedo_color = Color(0.2, 0.95, 0.35, 1.0)
	_led_active_material.emission_enabled = true
	_led_active_material.emission = Color(0.2, 0.95, 0.35, 1.0)
	_led_active_material.emission_energy_multiplier = 1.2

	if speaker_led != null:
		speaker_led.material_override = _led_idle_material


func _physics_process(_delta: float) -> void:
	var order_active := false
	var pickup_active := false
	var is_player_ordering := false

	# 1. Check overlapping areas/bodies from Area3D zones
	var oz: Area3D = get_node_or_null("OrderZone")
	var pz: Area3D = get_node_or_null("PickupZone")
	if oz != null:
		for a in oz.get_overlapping_areas():
			if a is Area3D:
				order_active = true
		for b in oz.get_overlapping_bodies():
			if b is CharacterBody3D:
				order_active = true
				is_player_ordering = true
	if pz != null:
		for a in pz.get_overlapping_areas():
			if a is Area3D:
				pickup_active = true
		for b in pz.get_overlapping_bodies():
			if b is CharacterBody3D:
				pickup_active = true

	# 2. Check active vehicles in TrafficManager
	var tm = get_node_or_null("/root/Main/TrafficManager")
	if tm == null and get_tree() != null and get_tree().current_scene != null:
		tm = get_tree().current_scene.get_node_or_null("TrafficManager")

	var global_order_pos := (
		global_transform.origin + global_transform.basis * Vector3(-12.0, 0.0, -2.0)
	)
	var global_pickup_pos := (
		global_transform.origin + global_transform.basis * Vector3(12.0, 0.0, 0.0)
	)

	if tm != null:
		for car in tm.lot_cars:
			if is_instance_valid(car):
				if car.global_position.distance_to(global_order_pos) < 3.5:
					order_active = true
				elif car.global_position.distance_to(global_pickup_pos) < 3.5:
					pickup_active = true

	# 3. Check player
	var player = get_node_or_null("/root/Main/Mats")
	if player == null and get_tree() != null and get_tree().current_scene != null:
		player = get_tree().current_scene.get_node_or_null("Mats")
	if player != null and is_instance_valid(player):
		if player.global_position.distance_to(global_order_pos) < 3.2:
			order_active = true
			is_player_ordering = true
		elif player.global_position.distance_to(global_pickup_pos) < 3.2:
			pickup_active = true

	# Update presentation
	if order_active:
		if not _was_order_active:
			_was_order_active = true
			_order_number = (_order_number + 1) % 99 + 1
			if speaker_led != null:
				speaker_led.material_override = _led_active_material
			if lcd_label != null:
				if is_player_ordering:
					lcd_label.text = (
						"[PEDESTRIAN WALK-UP #%d]\n1x RUNNER'S TACO PACK\n1x LARGE BAJA WATER\n$0.00 • WALK TO WINDOW"
						% _order_number
					)
				else:
					var template: String = ORDERS[randi() % ORDERS.size()]
					lcd_label.text = template % _order_number
	else:
		if _was_order_active:
			_was_order_active = false
			_update_lcd_idle()
			if speaker_led != null:
				speaker_led.material_override = _led_idle_material

	if pickup_active:
		if not _was_pickup_active:
			_was_pickup_active = true
			if pickup_label != null:
				pickup_label.text = "SERVING #%d" % _order_number
				pickup_label.modulate = Color(0.2, 0.95, 0.35, 1.0)
	else:
		if _was_pickup_active:
			_was_pickup_active = false
			if pickup_label != null:
				pickup_label.text = IDLE_PICKUP_TEXT
				pickup_label.modulate = Color(0.85, 0.1, 0.45, 1.0)


func _update_lcd_idle() -> void:
	if lcd_label != null:
		lcd_label.text = IDLE_LCD_TEXT
