class_name ObjectiveManager
extends Node

enum State {
	IDLE,
	RINGING,
	IN_CALL,
	ACTIVE,
	COMPLETE,
}

signal state_changed(old_state: State, new_state: State)
signal call_started(errand: MatsErrand)
signal call_answered(errand: MatsErrand)
signal objective_started(errand: MatsErrand)
signal objective_completed(errand: MatsErrand, total: int)

@export var initial_call_delay: float = 8.0
@export var next_call_delay: float = 4.0
@export var arrive_radius: float = 2.5
@export var generic_name_chance: float = 0.5
@export var objectives_data_path: String = "res://objectives/mats_objectives.json"
@export var mats_path: NodePath = NodePath("../Mats")
@export var auto_start: bool = false

var objectives_data: Dictionary = {}
var current_state: State = State.IDLE
var completed_count: int = 0
var current_errand: MatsErrand = null
var last_completed_errand: MatsErrand = null
var recent_errand_ids: Array[StringName] = []
var current_marker: ObjectiveMarker = null
var errands: Array[MatsErrand] = []
var destination_anchors: Dictionary = {}  # Dictionary[StringName, Node3D]
var mats: Mats = null:
	set(value):
		if mats == value:
			return
		if mats:
			if mats.died.is_connected(_on_mats_died):
				mats.died.disconnect(_on_mats_died)
			if mats.respawned.is_connected(_on_mats_respawned):
				mats.respawned.disconnect(_on_mats_respawned)
		mats = value
		if mats:
			if not mats.died.is_connected(_on_mats_died):
				mats.died.connect(_on_mats_died)
			if not mats.respawned.is_connected(_on_mats_respawned):
				mats.respawned.connect(_on_mats_respawned)
			if current_state == State.RINGING:
				mats.set_phone_state(Mats.PhoneMode.RINGING)
			elif current_state == State.IN_CALL:
				mats.set_phone_state(Mats.PhoneMode.TALKING)
var hud: HUD = null
var _is_mats_dead: bool = false
var _pending_errand: MatsErrand = null
var _call_timer: float = -1.0
var _started_once: bool = false

var _setup_done: bool = false


func _ready() -> void:
	add_to_group("objective_manager")
	if objectives_data.is_empty():
		objectives_data = load_objectives_data(objectives_data_path)
	if errands.is_empty():
		errands = build_errands_from_data(objectives_data)
	_setup.call_deferred()


func _exit_tree() -> void:
	if mats:
		if mats.died.is_connected(_on_mats_died):
			mats.died.disconnect(_on_mats_died)
		if mats.respawned.is_connected(_on_mats_respawned):
			mats.respawned.disconnect(_on_mats_respawned)


func _setup() -> void:
	if _setup_done:
		return
	_setup_done = true
	_discover_destination_anchors()
	_resolve_dependencies()
	if auto_start:
		start_objective_flow()


func _resolve_dependencies() -> void:
	if mats == null and is_inside_tree():
		if has_node(mats_path):
			mats = get_node(mats_path) as Mats
		else:
			mats = get_tree().get_first_node_in_group("player") as Mats

	if hud == null and is_inside_tree():
		hud = get_tree().get_first_node_in_group("hud") as HUD


func _discover_destination_anchors() -> void:
	var default_bindings: Dictionary = {
		&"walgroins": ^"Props/Walgroins/DestinationAnchor",
		&"booger_king": ^"Props/BoogerKingSite/DestinationAnchor",
		&"taco_hell": ^"Props/TacoHell/DestinationAnchor",
		&"smell": ^"Props/SmellGasStation/DestinationAnchor",
	}
	var parent := get_parent()
	for loc_id in default_bindings:
		if destination_anchors.has(loc_id) and is_instance_valid(destination_anchors[loc_id]):
			continue
		var anchor_path: NodePath = default_bindings[loc_id]
		if parent and parent.has_node(anchor_path):
			register_destination(loc_id, parent.get_node(anchor_path) as Node3D)
		elif has_node(anchor_path):
			register_destination(loc_id, get_node(anchor_path) as Node3D)


func register_destination(location_id: StringName, anchor_node: Node3D) -> void:
	if location_id.is_empty() or anchor_node == null:
		return
	destination_anchors[location_id] = anchor_node


func bind_destinations(bindings: Dictionary) -> void:
	for loc_id in bindings:
		var val = bindings[loc_id]
		if val is Node3D:
			register_destination(loc_id if loc_id is StringName else StringName(str(loc_id)), val)


func unregister_destination(location_id: StringName) -> void:
	destination_anchors.erase(location_id)


func get_destination_anchor(location_id: StringName) -> Node3D:
	var anchor = destination_anchors.get(location_id)
	if anchor != null and is_instance_valid(anchor):
		return anchor as Node3D
	return null


func has_destination(location_id: StringName) -> bool:
	return get_destination_anchor(location_id) != null


func start_objective_flow() -> void:
	if _started_once:
		return
	_started_once = true
	_schedule_call(initial_call_delay)


func _on_start_screen_started() -> void:
	start_objective_flow()


func _on_mats_died(_pos: Vector3) -> void:
	_is_mats_dead = true


func _on_mats_respawned() -> void:
	_is_mats_dead = false


func _process(delta: float) -> void:
	if _call_timer >= 0.0:
		if get_tree().paused:
			return
		_call_timer -= delta
		if _call_timer <= 0.0:
			_call_timer = -1.0
			start_call()


func _physics_process(_delta: float) -> void:
	if current_state != State.ACTIVE:
		return
	if current_marker == null and current_errand != null:
		_spawn_marker()
	if _is_mats_dead or mats == null or current_errand == null:
		return
	var target_pos := get_target_position(current_errand)
	var mats_pos := mats.global_position
	var dist_xz := Vector2(mats_pos.x - target_pos.x, mats_pos.z - target_pos.z).length()
	# If Mats is already standing inside arrive_radius when an errand starts,
	# instant completion is allowed on the next physics tick.
	if dist_xz < arrive_radius:
		complete_objective()


func transition_to(new_state: State) -> void:
	if current_state == new_state:
		return
	var old_state := current_state
	current_state = new_state
	if new_state == State.ACTIVE:
		_spawn_marker()
	elif old_state == State.ACTIVE and new_state != State.COMPLETE:
		_despawn_marker(false)
	if mats:
		if new_state == State.RINGING:
			mats.set_phone_state(Mats.PhoneMode.RINGING)
		elif new_state == State.IN_CALL:
			mats.set_phone_state(Mats.PhoneMode.TALKING)
		elif new_state == State.IDLE or new_state == State.ACTIVE or new_state == State.COMPLETE:
			mats.end_phone_call()
	state_changed.emit(old_state, new_state)


func is_call_showing() -> bool:
	return current_state == State.RINGING or current_state == State.IN_CALL


func start_call(errand: MatsErrand = null) -> void:
	if current_state != State.IDLE:
		return
	var errand_to_use := errand if errand != null else _pending_errand
	if is_inside_tree() and get_tree().paused:
		_pending_errand = errand_to_use
		_call_timer = 0.0
		return
	_pending_errand = null
	_call_timer = -1.0
	if errand_to_use != null:
		current_errand = errand_to_use
	else:
		current_errand = _pick_next()
	if current_errand and current_errand.call_line.is_empty():
		refresh_errand_dialogue(current_errand, randf() < generic_name_chance)
	transition_to(State.RINGING)
	call_started.emit(current_errand)


func answer_call() -> void:
	if current_state != State.RINGING:
		return
	transition_to(State.IN_CALL)
	call_answered.emit(current_errand)


func dismiss_call() -> void:
	if current_state != State.IN_CALL:
		return
	transition_to(State.ACTIVE)
	objective_started.emit(current_errand)


func complete_objective() -> void:
	if current_state != State.ACTIVE:
		return
	completed_count += 1
	var finished_errand := current_errand
	last_completed_errand = current_errand
	_despawn_marker(true)
	transition_to(State.COMPLETE)
	objective_completed.emit(finished_errand, completed_count)
	current_errand = null
	transition_to(State.IDLE)
	_schedule_call(next_call_delay)


func _spawn_marker() -> void:
	if current_errand == null:
		return
	if current_marker != null and is_instance_valid(current_marker):
		return
	var target_pos := get_target_position(current_errand)
	var ground_pos := Vector3(target_pos.x, 0.0, target_pos.z)
	var marker := ObjectiveMarker.new()
	marker.name = "ObjectiveMarker"
	marker.arrive_radius = arrive_radius
	marker.store_name = current_errand.store_name

	var parent_node := get_parent()
	if parent_node is Node3D:
		parent_node.add_child(marker)
		marker.global_position = ground_pos
	elif is_inside_tree() and get_tree().current_scene is Node3D:
		get_tree().current_scene.add_child(marker)
		marker.global_position = ground_pos
	else:
		add_child(marker)
		marker.position = ground_pos

	current_marker = marker


func _despawn_marker(completed: bool = false) -> void:
	if current_marker != null and is_instance_valid(current_marker):
		if completed:
			current_marker.complete_and_free()
		else:
			current_marker.queue_free()
	current_marker = null


func _schedule_call(delay: float) -> void:
	if delay <= 0.0:
		_call_timer = -1.0
		start_call.call_deferred()
	else:
		_call_timer = delay


func get_errand_by_id(errand_id: StringName) -> MatsErrand:
	for errand in errands:
		if errand.id == errand_id:
			return errand
	return null


func get_target_node(errand: MatsErrand) -> Node3D:
	if errand == null:
		return null
	if not errand.location_id.is_empty():
		var anchor := get_destination_anchor(errand.location_id)
		if anchor != null:
			return anchor
	if not errand.target_path.is_empty():
		if get_parent() and get_parent().has_node(errand.target_path):
			return get_parent().get_node(errand.target_path) as Node3D
		if has_node(errand.target_path):
			return get_node(errand.target_path) as Node3D
	return null


func get_target_position(errand: MatsErrand) -> Vector3:
	var node := get_target_node(errand)
	if node:
		return node.global_position
	if errand != null:
		push_error(
			(
				"ObjectiveManager: Unbound destination for errand '%s' (location '%s')"
				% [errand.id, errand.location_id]
			)
		)
	return Vector3.ZERO


func refresh_errand_dialogue(errand: MatsErrand, use_generic: bool = false) -> void:
	if errand == null:
		return
	var dialogue_parts: Dictionary = objectives_data.get("dialogue_parts", {})
	if dialogue_parts.is_empty():
		dialogue_parts = DEFAULT_OBJECTIVES_DATA.get("dialogue_parts", {})
	var res := generate_dialogue(
		errand.item,
		errand.proper_store_name,
		errand.generic_store_name,
		dialogue_parts,
		use_generic
	)
	errand.call_line = res["call_line"]
	errand.used_location_name = res["used_location_name"]


func _pick_next() -> MatsErrand:
	_resolve_dependencies()
	var mats_z := mats.global_position.z if mats else 9.0
	var mats_side := signf(mats_z)
	if is_zero_approx(mats_side):
		mats_side = 1.0

	var candidates: Array[MatsErrand] = []
	for errand in errands:
		var target_pos := get_target_position(errand)
		var target_side := signf(target_pos.z)
		if is_zero_approx(target_side):
			target_side = -mats_side
		if target_side != mats_side:
			candidates.append(errand)

	var valid_candidates: Array[MatsErrand] = []
	for errand in candidates:
		if last_completed_errand == null or errand.id != last_completed_errand.id:
			valid_candidates.append(errand)

	if valid_candidates.is_empty():
		for errand in errands:
			if last_completed_errand == null or errand.id != last_completed_errand.id:
				valid_candidates.append(errand)

	if valid_candidates.is_empty():
		valid_candidates = errands.duplicate()

	# Two-stage random selection:
	# 1. Group candidate errands by location to prevent bias toward stores with more items
	var loc_to_errands: Dictionary = {}
	for errand in valid_candidates:
		var lid := errand.location_id
		if not loc_to_errands.has(lid):
			loc_to_errands[lid] = []
		loc_to_errands[lid].append(errand)

	# 2. Pick a location at random, avoiding the last completed location if multiple options exist
	var available_locations: Array = loc_to_errands.keys()
	if last_completed_errand != null and available_locations.size() > 1:
		var diff_locations: Array = []
		for lid in available_locations:
			if lid != last_completed_errand.location_id:
				diff_locations.append(lid)
		if not diff_locations.is_empty():
			available_locations = diff_locations

	var chosen_location = available_locations[randi() % available_locations.size()]
	var location_errands: Array = loc_to_errands[chosen_location]

	# 3. From the chosen location, pick an item at random, preferring items not recently completed
	var item_candidates: Array[MatsErrand] = []
	for errand in location_errands:
		if not recent_errand_ids.has(errand.id):
			item_candidates.append(errand)
	if item_candidates.is_empty():
		item_candidates.assign(location_errands)

	var picked: MatsErrand = item_candidates[randi() % item_candidates.size()]
	recent_errand_ids.append(picked.id)
	if recent_errand_ids.size() > 4:
		recent_errand_ids.pop_front()

	var use_generic := randf() < generic_name_chance
	refresh_errand_dialogue(picked, use_generic)
	return picked


static func item_to_id(item_name: String) -> StringName:
	return StringName(item_name.to_lower().replace("-", "_").replace(" ", "_"))


static func load_objectives_data(
	path: String = "res://objectives/mats_objectives.json"
) -> Dictionary:
	if not path.is_empty() and FileAccess.file_exists(path):
		var file := FileAccess.open(path, FileAccess.READ)
		if file:
			var content := file.get_as_text()
			var parsed = JSON.parse_string(content)
			if parsed is Dictionary and parsed.has("locations") and parsed.has("dialogue_parts"):
				return parsed
	return DEFAULT_OBJECTIVES_DATA


static func generate_dialogue(
	item_name: String,
	proper_name: String,
	generic_name: String,
	dialogue_parts: Dictionary,
	use_generic: bool = false
) -> Dictionary:
	var openings: Array = dialogue_parts.get("openings", [])
	var excuses: Array = dialogue_parts.get("excuses", [])
	var requests: Array = dialogue_parts.get("requests", [])

	var opening: String = openings[randi() % openings.size()] if not openings.is_empty() else ""
	var excuse: String = excuses[randi() % excuses.size()] if not excuses.is_empty() else ""
	var chosen_location: String = (
		generic_name if use_generic and not generic_name.is_empty() else proper_name
	)

	var request_template: String = (
		requests[randi() % requests.size()]
		if not requests.is_empty()
		else "Could you pick up some {item} at {location}?"
	)
	var request: String = request_template.replace("{item}", item_name).replace(
		"{location}", chosen_location
	)

	var parts: Array[String] = []
	if not opening.is_empty():
		parts.append(opening)
	if not excuse.is_empty():
		parts.append(excuse)
	if not request.is_empty():
		parts.append(request)

	var full_call_line: String = " ".join(parts)
	return {
		"call_line": full_call_line,
		"used_location_name": chosen_location,
		"opening": opening,
		"excuse": excuse,
		"request": request,
	}


static func build_errands_from_data(data: Dictionary) -> Array[MatsErrand]:
	var list: Array[MatsErrand] = []
	var dialogue_parts: Dictionary = data.get("dialogue_parts", {})
	var locations: Array = data.get("locations", [])

	for loc in locations:
		if not loc is Dictionary:
			continue
		var loc_id_str: String = loc.get("id", "")
		var loc_id := StringName(loc_id_str)
		var proper_name: String = loc.get("proper_name", "")
		var generic_name: String = loc.get("generic_name", "")
		var target_path := NodePath(loc.get("target_path", ""))
		var items: Array = loc.get("items", [])

		for item_raw in items:
			var item_str := str(item_raw)
			var errand_id := item_to_id(item_str)
			var success := "Got the %s!" % item_str

			var call_line := ""
			var used_loc := proper_name
			if errand_id == &"cough_syrup":
				call_line = "Hello Mats darling, while you're out exploring, could you please pick up some cough syrup from Walgroins?"
				used_loc = proper_name
			else:
				var res := generate_dialogue(
					item_str, proper_name, generic_name, dialogue_parts, false
				)
				call_line = res["call_line"]
				used_loc = res["used_location_name"]

			var errand := MatsErrand.new(
				errand_id,
				item_str,
				proper_name,
				target_path,
				call_line,
				success,
				loc_id,
				proper_name,
				generic_name,
				used_loc
			)
			list.append(errand)

	return list


const DEFAULT_OBJECTIVES_DATA: Dictionary = {
	"dialogue_parts":
	{
		"openings":
		[
			"Hi Mats, are you having fun out there?",
			"Mats schat...",
			"Mats, m’n jongen...",
		],
		"excuses":
		[
			"I don't feel like cooking dinner tonight.",
			"I just remembered another thing!",
			"Could you grab one more item for your mother?",
		],
		"requests":
		[
			"Could you pick up some {item} at {location}?",
			"Can you stop by {location} and get some {item}?",
			"While you're out, swing by {location} for some {item}.",
		],
	},
	"locations":
	[
		{
			"id": "walgroins",
			"proper_name": "Walgroins",
			"generic_name": "the pharmacy",
			"items":
			[
				"cough syrup",
				"band-aids",
				"potato chips",
				"toothpaste",
				"batteries",
			],
		},
		{
			"id": "booger_king",
			"proper_name": "Booger King",
			"generic_name": "the burger joint",
			"items":
			[
				"hamburgers",
			],
		},
		{
			"id": "taco_hell",
			"proper_name": "Taco Hell",
			"generic_name": "the taco stand",
			"items":
			[
				"tacos",
				"burritos",
				"quesadillas",
			],
		},
		{
			"id": "smell",
			"proper_name": "Smell",
			"generic_name": "the convenience store",
			"items":
			[
				"milk",
				"cereal",
				"chewing gum",
				"beef jerky",
			],
		},
	],
}


static func create_errand_from_dict(data: Dictionary) -> MatsErrand:
	return MatsErrand.new(
		data.get("id", &""),
		data.get("item", ""),
		data.get("store_name", ""),
		data.get("target_path", NodePath()),
		data.get("call_line", ""),
		data.get("success_line", "")
	)


static func get_default_errands() -> Array[MatsErrand]:
	var data := load_objectives_data()
	return build_errands_from_data(data)
