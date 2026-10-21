@tool
class_name ObjectivesEditorDock
extends PanelContainer

const OBJECTIVES_PATH := "res://objectives/mats_objectives.json"

var data: Dictionary = {}
var is_dirty: bool = false

# Current selection indices
var _current_loc_idx: int = -1
var _current_item_idx: int = -1
var _current_item_excuse_idx: int = -1

var _current_opening_idx: int = -1
var _current_cat_key: String = "general"
var _current_cat_excuse_idx: int = -1
var _current_request_idx: int = -1

# UI Nodes
var status_label: Label
var tabs: TabContainer

# Tab 1: Locations & Objectives
var loc_item_list: ItemList
var loc_id_edit: LineEdit
var loc_proper_edit: LineEdit
var loc_generic_edit: LineEdit
var loc_cat_edit: LineEdit

var item_item_list: ItemList
var item_name_edit: LineEdit

var item_excuse_list: ItemList
var item_excuse_edit: TextEdit
var item_excuse_header_label: Label

# Tab 2: Dialogue Pools
var opening_item_list: ItemList
var opening_edit: TextEdit
var opening_preview: RichTextLabel

var cat_option_btn: OptionButton
var cat_excuse_list: ItemList
var cat_excuse_edit: TextEdit

var request_item_list: ItemList
var request_edit: TextEdit

# Tab 3: Combiner & Tester
var test_loc_option: OptionButton
var test_item_option: OptionButton
var test_generic_check: CheckBox
var test_opening_option: OptionButton
var test_excuse_option: OptionButton
var test_request_option: OptionButton
var test_output_display: RichTextLabel
var test_breakdown_loc: Label
var test_breakdown_opening: Label
var test_breakdown_excuse: Label
var test_breakdown_excuse_src: Label
var test_breakdown_request: Label


func _ready() -> void:
	custom_minimum_size = Vector2(0, 340)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build_ui()
	load_from_file()


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	add_child(margin)

	var main_vbox := VBoxContainer.new()
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(main_vbox)
	# --- Toolbar ---
	var toolbar := HBoxContainer.new()
	toolbar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(toolbar)

	var title_lbl := Label.new()
	title_lbl.text = "🎯 Mats Objectives & Dialogue Editor"
	title_lbl.add_theme_font_size_override("font_size", 14)
	toolbar.add_child(title_lbl)

	toolbar.add_child(VSeparator.new())

	var save_btn := Button.new()
	save_btn.text = "💾 Save JSON"
	save_btn.tooltip_text = "Save changes to " + OBJECTIVES_PATH
	save_btn.pressed.connect(_on_save_pressed)
	toolbar.add_child(save_btn)

	var reload_btn := Button.new()
	reload_btn.text = "🔄 Reload"
	reload_btn.tooltip_text = "Reload data from disk (discards unsaved edits)"
	reload_btn.pressed.connect(load_from_file)
	toolbar.add_child(reload_btn)

	toolbar.add_child(VSeparator.new())

	status_label = Label.new()
	status_label.text = "Ready"
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(status_label)

	# --- TabContainer ---
	tabs = TabContainer.new()
	tabs.custom_minimum_size = Vector2(0, 260)
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build_locations_tab()
	_build_dialogue_pools_tab()
	_build_tester_tab()
	tabs.tab_changed.connect(_on_tab_changed)
	main_vbox.add_child(tabs)


# ==============================================================================
# TAB 1: Locations, Items, and Item-Specific Excuses
# ==============================================================================
func _build_locations_tab() -> void:
	var panel := PanelContainer.new()
	panel.name = "Locations & Errands"
	tabs.add_child(panel)

	var hsplit_main := HSplitContainer.new()
	hsplit_main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hsplit_main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(hsplit_main)

	# --- Column 1: Locations (Left) ---
	var loc_vbox := VBoxContainer.new()
	loc_vbox.custom_minimum_size = Vector2(200, 0)
	loc_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	loc_vbox.size_flags_stretch_ratio = 1.0
	hsplit_main.add_child(loc_vbox)

	var loc_title := Label.new()
	loc_title.text = "1. Stores & Locations"
	loc_vbox.add_child(loc_title)

	loc_item_list = ItemList.new()
	loc_item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	loc_item_list.item_selected.connect(_on_loc_selected)
	loc_vbox.add_child(loc_item_list)

	var loc_btn_bar := HBoxContainer.new()
	loc_vbox.add_child(loc_btn_bar)

	var add_loc_btn := Button.new()
	add_loc_btn.text = "+ Add Store"
	add_loc_btn.pressed.connect(_on_add_location)
	loc_btn_bar.add_child(add_loc_btn)

	var del_loc_btn := Button.new()
	del_loc_btn.text = "- Delete"
	del_loc_btn.pressed.connect(_on_delete_location)
	loc_btn_bar.add_child(del_loc_btn)

	# Location details form
	var loc_grid := GridContainer.new()
	loc_grid.columns = 2
	loc_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	loc_vbox.add_child(loc_grid)

	loc_grid.add_child(_make_label("ID:"))
	loc_id_edit = LineEdit.new()
	loc_id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	loc_id_edit.text_changed.connect(_on_loc_field_changed)
	loc_grid.add_child(loc_id_edit)

	loc_grid.add_child(_make_label("Proper Name:"))
	loc_proper_edit = LineEdit.new()
	loc_proper_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	loc_proper_edit.text_changed.connect(_on_loc_field_changed)
	loc_grid.add_child(loc_proper_edit)

	loc_grid.add_child(_make_label("Generic Name:"))
	loc_generic_edit = LineEdit.new()
	loc_generic_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	loc_generic_edit.text_changed.connect(_on_loc_field_changed)
	loc_grid.add_child(loc_generic_edit)

	loc_grid.add_child(_make_label("Category:"))
	loc_cat_edit = LineEdit.new()
	loc_cat_edit.placeholder_text = "dinner, pharmacy, convenience..."
	loc_cat_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	loc_cat_edit.text_changed.connect(_on_loc_field_changed)
	loc_grid.add_child(loc_cat_edit)

	# --- Column 2 & 3: Items and Item Excuses (Right) ---
	var hsplit_right := HSplitContainer.new()
	hsplit_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hsplit_right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hsplit_right.size_flags_stretch_ratio = 2.5
	hsplit_main.add_child(hsplit_right)

	# Column 2: Items
	var item_vbox := VBoxContainer.new()
	item_vbox.custom_minimum_size = Vector2(180, 0)
	item_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_vbox.size_flags_stretch_ratio = 1.0
	hsplit_right.add_child(item_vbox)

	var item_title := Label.new()
	item_title.text = "2. Store Items (Objectives)"
	item_vbox.add_child(item_title)

	item_item_list = ItemList.new()
	item_item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	item_item_list.item_selected.connect(_on_item_selected)
	item_vbox.add_child(item_item_list)

	var item_btn_bar := HBoxContainer.new()
	item_vbox.add_child(item_btn_bar)

	var add_item_btn := Button.new()
	add_item_btn.text = "+ Add Item"
	add_item_btn.pressed.connect(_on_add_item)
	item_btn_bar.add_child(add_item_btn)

	var del_item_btn := Button.new()
	del_item_btn.text = "- Delete"
	del_item_btn.pressed.connect(_on_delete_item)
	item_btn_bar.add_child(del_item_btn)

	item_name_edit = LineEdit.new()
	item_name_edit.placeholder_text = "Item name..."
	item_name_edit.text_changed.connect(_on_item_name_changed)
	item_vbox.add_child(item_name_edit)

	# Column 3: Item-Specific Excuses
	var item_exc_vbox := VBoxContainer.new()
	item_exc_vbox.custom_minimum_size = Vector2(250, 0)
	item_exc_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_exc_vbox.size_flags_stretch_ratio = 1.5
	hsplit_right.add_child(item_exc_vbox)

	item_excuse_header_label = Label.new()
	item_excuse_header_label.text = "3. Specific Excuses for Selected Item"
	item_exc_vbox.add_child(item_excuse_header_label)

	var item_exc_hint := Label.new()
	item_exc_hint.text = ("Mom has a 45% chance to use one of these item-tailored excuses when this errand is called.")
	item_exc_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item_exc_hint.modulate = Color(0.8, 0.8, 0.8, 0.9)
	item_exc_vbox.add_child(item_exc_hint)

	item_excuse_list = ItemList.new()
	item_excuse_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	item_excuse_list.item_selected.connect(_on_item_excuse_selected)
	item_exc_vbox.add_child(item_excuse_list)

	var item_exc_btn_bar := HBoxContainer.new()
	item_exc_vbox.add_child(item_exc_btn_bar)

	var add_exc_btn := Button.new()
	add_exc_btn.text = "+ Add Item Excuse"
	add_exc_btn.pressed.connect(_on_add_item_excuse)
	item_exc_btn_bar.add_child(add_exc_btn)

	var del_exc_btn := Button.new()
	del_exc_btn.text = "- Delete"
	del_exc_btn.pressed.connect(_on_delete_item_excuse)
	item_exc_btn_bar.add_child(del_exc_btn)

	item_excuse_edit = TextEdit.new()
	item_excuse_edit.custom_minimum_size = Vector2(0, 60)
	item_excuse_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	item_excuse_edit.placeholder_text = "Enter excuse text..."
	item_excuse_edit.text_changed.connect(_on_item_excuse_text_changed)
	item_exc_vbox.add_child(item_excuse_edit)


# ==============================================================================
# TAB 2: Dialogue Pools (Openings, Category Excuses, Requests)
# ==============================================================================
func _build_dialogue_pools_tab() -> void:
	var panel := PanelContainer.new()
	panel.name = "Dialogue Pools"
	tabs.add_child(panel)

	var subtabs := TabContainer.new()
	subtabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	subtabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(subtabs)

	# --- SubTab A: Openings ---
	var open_panel := VBoxContainer.new()
	open_panel.name = "Openings (Greetings)"
	subtabs.add_child(open_panel)

	var open_hint := Label.new()
	open_hint.text = ("Mother's opening phrases. Use [[i]translation[/i]] for bracketed Dutch subtitles.")
	open_panel.add_child(open_hint)

	var open_hsplit := HSplitContainer.new()
	open_hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	open_panel.add_child(open_hsplit)

	var open_list_vbox := VBoxContainer.new()
	open_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	open_list_vbox.size_flags_stretch_ratio = 1.0
	open_hsplit.add_child(open_list_vbox)

	opening_item_list = ItemList.new()
	opening_item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	opening_item_list.item_selected.connect(_on_opening_selected)
	open_list_vbox.add_child(opening_item_list)

	var open_btn_bar := HBoxContainer.new()
	open_list_vbox.add_child(open_btn_bar)

	var add_open_btn := Button.new()
	add_open_btn.text = "+ Add Opening"
	add_open_btn.pressed.connect(_on_add_opening)
	open_btn_bar.add_child(add_open_btn)

	var del_open_btn := Button.new()
	del_open_btn.text = "- Delete"
	del_open_btn.pressed.connect(_on_delete_opening)
	open_btn_bar.add_child(del_open_btn)

	var open_edit_vbox := VBoxContainer.new()
	open_edit_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	open_edit_vbox.size_flags_stretch_ratio = 1.2
	open_hsplit.add_child(open_edit_vbox)

	open_edit_vbox.add_child(_make_label("Edit Opening Text:"))
	opening_edit = TextEdit.new()
	opening_edit.custom_minimum_size = Vector2(0, 70)
	opening_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	opening_edit.text_changed.connect(_on_opening_text_changed)
	open_edit_vbox.add_child(opening_edit)

	open_edit_vbox.add_child(_make_label("Formatted In-Game Preview:"))
	opening_preview = RichTextLabel.new()
	opening_preview.bbcode_enabled = true
	opening_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	opening_preview.fit_content = false
	open_edit_vbox.add_child(opening_preview)

	# --- SubTab B: Category Excuses ---
	var cat_panel := VBoxContainer.new()
	cat_panel.name = "Category Excuses"
	subtabs.add_child(cat_panel)

	var cat_top_bar := HBoxContainer.new()
	cat_panel.add_child(cat_top_bar)

	cat_top_bar.add_child(_make_label("Category:"))
	cat_option_btn = OptionButton.new()
	cat_option_btn.item_selected.connect(_on_cat_option_selected)
	cat_top_bar.add_child(cat_option_btn)

	var add_cat_btn := Button.new()
	add_cat_btn.text = "+ New Category"
	add_cat_btn.pressed.connect(_on_add_category)
	cat_top_bar.add_child(add_cat_btn)

	var cat_hsplit := HSplitContainer.new()
	cat_hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cat_panel.add_child(cat_hsplit)

	var cat_list_vbox := VBoxContainer.new()
	cat_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cat_list_vbox.size_flags_stretch_ratio = 1.0
	cat_hsplit.add_child(cat_list_vbox)

	cat_excuse_list = ItemList.new()
	cat_excuse_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cat_excuse_list.item_selected.connect(_on_cat_excuse_selected)
	cat_list_vbox.add_child(cat_excuse_list)

	var cat_btn_bar := HBoxContainer.new()
	cat_list_vbox.add_child(cat_btn_bar)

	var add_cat_exc_btn := Button.new()
	add_cat_exc_btn.text = "+ Add Excuse"
	add_cat_exc_btn.pressed.connect(_on_add_cat_excuse)
	cat_btn_bar.add_child(add_cat_exc_btn)

	var del_cat_exc_btn := Button.new()
	del_cat_exc_btn.text = "- Delete"
	del_cat_exc_btn.pressed.connect(_on_delete_cat_excuse)
	cat_btn_bar.add_child(del_cat_exc_btn)

	var cat_edit_vbox := VBoxContainer.new()
	cat_edit_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cat_edit_vbox.size_flags_stretch_ratio = 1.2
	cat_hsplit.add_child(cat_edit_vbox)

	cat_edit_vbox.add_child(_make_label("Edit Excuse for Selected Category:"))
	cat_excuse_edit = TextEdit.new()
	cat_excuse_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cat_excuse_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	cat_excuse_edit.text_changed.connect(_on_cat_excuse_text_changed)
	cat_edit_vbox.add_child(cat_excuse_edit)

	# --- SubTab C: Requests ---
	var req_panel := VBoxContainer.new()
	req_panel.name = "Requests"
	subtabs.add_child(req_panel)

	var req_hint := Label.new()
	req_hint.text = ("Mother's errand request templates. Tokens available: {item} and {location} (e.g. 'Can you grab some {item} at {location}?')")
	req_panel.add_child(req_hint)

	var req_hsplit := HSplitContainer.new()
	req_hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	req_panel.add_child(req_hsplit)

	var req_list_vbox := VBoxContainer.new()
	req_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	req_list_vbox.size_flags_stretch_ratio = 1.0
	req_hsplit.add_child(req_list_vbox)

	request_item_list = ItemList.new()
	request_item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	request_item_list.item_selected.connect(_on_request_selected)
	req_list_vbox.add_child(request_item_list)

	var req_btn_bar := HBoxContainer.new()
	req_list_vbox.add_child(req_btn_bar)

	var add_req_btn := Button.new()
	add_req_btn.text = "+ Add Request Template"
	add_req_btn.pressed.connect(_on_add_request)
	req_btn_bar.add_child(add_req_btn)

	var del_req_btn := Button.new()
	del_req_btn.text = "- Delete"
	del_req_btn.pressed.connect(_on_delete_request)
	req_btn_bar.add_child(del_req_btn)

	var req_edit_vbox := VBoxContainer.new()
	req_edit_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	req_edit_vbox.size_flags_stretch_ratio = 1.2
	req_hsplit.add_child(req_edit_vbox)

	req_edit_vbox.add_child(_make_label("Edit Request Template:"))
	request_edit = TextEdit.new()
	request_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	request_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	request_edit.text_changed.connect(_on_request_text_changed)
	req_edit_vbox.add_child(request_edit)


# ==============================================================================
# TAB 3: Combiner & Live Dialogue Tester
# ==============================================================================
func _build_tester_tab() -> void:
	var panel := PanelContainer.new()
	panel.name = "Dialogue Combiner & Tester"
	tabs.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(vbox)

	var desc_lbl := Label.new()
	desc_lbl.text = ("Simulate how lines of dialogue combine for a specific objective using the in-game dialogue generation rules.")
	vbox.add_child(desc_lbl)

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(split)

	# Left: Configuration controls
	var cfg_vbox := VBoxContainer.new()
	cfg_vbox.custom_minimum_size = Vector2(320, 0)
	cfg_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cfg_vbox.size_flags_stretch_ratio = 1.0
	split.add_child(cfg_vbox)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cfg_vbox.add_child(grid)

	grid.add_child(_make_label("Target Location:"))
	test_loc_option = OptionButton.new()
	test_loc_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	test_loc_option.item_selected.connect(_on_test_loc_changed)
	grid.add_child(test_loc_option)

	grid.add_child(_make_label("Target Item:"))
	test_item_option = OptionButton.new()
	test_item_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	test_item_option.item_selected.connect(_on_test_item_changed)
	grid.add_child(test_item_option)

	grid.add_child(_make_label("Location Style:"))
	test_generic_check = CheckBox.new()
	test_generic_check.text = "Use Generic Name ('the pharmacy' vs 'Walgroins')"
	test_generic_check.toggled.connect(func(_val): _update_tester_preview())
	grid.add_child(test_generic_check)

	grid.add_child(HSeparator.new())
	grid.add_child(HSeparator.new())

	grid.add_child(_make_label("Opening Selection:"))
	test_opening_option = OptionButton.new()
	test_opening_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	test_opening_option.item_selected.connect(func(_val): _update_tester_preview())
	grid.add_child(test_opening_option)

	grid.add_child(_make_label("Excuse Selection:"))
	test_excuse_option = OptionButton.new()
	test_excuse_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	test_excuse_option.item_selected.connect(func(_val): _update_tester_preview())
	grid.add_child(test_excuse_option)

	grid.add_child(_make_label("Request Selection:"))
	test_request_option = OptionButton.new()
	test_request_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	test_request_option.item_selected.connect(func(_val): _update_tester_preview())
	grid.add_child(test_request_option)

	var action_bar := HBoxContainer.new()
	cfg_vbox.add_child(action_bar)

	var roll_btn := Button.new()
	roll_btn.text = "🎲 Roll Dialogue (Game Logic)"
	roll_btn.tooltip_text = ("Rolls dialogue using ObjectiveManager rules (45% item excuse weighting, category filter, random request)")
	roll_btn.pressed.connect(_on_test_roll_pressed)
	action_bar.add_child(roll_btn)

	var preview_btn := Button.new()
	preview_btn.text = "👁 Refresh Preview"
	preview_btn.pressed.connect(_update_tester_preview)
	action_bar.add_child(preview_btn)

	# Right: Result Display & Breakdown Card
	var res_vbox := VBoxContainer.new()
	res_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	res_vbox.size_flags_stretch_ratio = 1.4
	split.add_child(res_vbox)

	var res_title := Label.new()
	res_title.text = "Phone Call Preview (Mats's Phone):"
	res_title.add_theme_font_size_override("font_size", 13)
	res_vbox.add_child(res_title)

	var call_panel := PanelContainer.new()
	call_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	call_panel.size_flags_stretch_ratio = 1.2
	res_vbox.add_child(call_panel)

	test_output_display = RichTextLabel.new()
	test_output_display.bbcode_enabled = true
	test_output_display.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	test_output_display.size_flags_vertical = Control.SIZE_EXPAND_FILL
	test_output_display.fit_content = false
	call_panel.add_child(test_output_display)

	var bd_title := Label.new()
	bd_title.text = "Combination Anatomy & Rule Breakdown:"
	res_vbox.add_child(bd_title)

	var bd_grid := GridContainer.new()
	bd_grid.columns = 2
	bd_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	res_vbox.add_child(bd_grid)

	bd_grid.add_child(_make_label("Resolved Store & Category:"))
	test_breakdown_loc = _make_label("-")
	bd_grid.add_child(test_breakdown_loc)

	bd_grid.add_child(_make_label("Opening Line:"))
	test_breakdown_opening = _make_label("-")
	bd_grid.add_child(test_breakdown_opening)

	bd_grid.add_child(_make_label("Excuse Line:"))
	test_breakdown_excuse = _make_label("-")
	bd_grid.add_child(test_breakdown_excuse)

	bd_grid.add_child(_make_label("Excuse Source:"))
	test_breakdown_excuse_src = _make_label("-")
	bd_grid.add_child(test_breakdown_excuse_src)

	bd_grid.add_child(_make_label("Request Line:"))
	test_breakdown_request = _make_label("-")
	bd_grid.add_child(test_breakdown_request)


# ==============================================================================
# DATA LOAD / SAVE
# ==============================================================================
func load_from_file(path: String = OBJECTIVES_PATH) -> bool:
	if not FileAccess.file_exists(path):
		_set_status("File not found: " + path, true)
		return false

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_set_status("Failed to open " + path, true)
		return false

	var json_str := file.get_as_text()
	var parsed = JSON.parse_string(json_str)
	if not (parsed is Dictionary):
		_set_status("Invalid JSON in " + path, true)
		return false

	data = parsed
	is_dirty = false

	# Ensure data structures exist
	if not data.has("dialogue_parts"):
		data["dialogue_parts"] = {}
	var dp: Dictionary = data["dialogue_parts"]
	if not dp.has("openings"):
		dp["openings"] = []
	if not dp.has("excuses"):
		dp["excuses"] = {"general": []}
	if not dp.has("item_excuses"):
		dp["item_excuses"] = {}
	if not dp.has("requests"):
		dp["requests"] = []
	if not data.has("locations"):
		data["locations"] = []

	_refresh_all_views()
	_set_status("Loaded data from " + path)
	return true


func save_to_file(path: String = OBJECTIVES_PATH) -> bool:
	var json_text := JSON.stringify(data, "\t")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_set_status("Failed to write to " + path, true)
		return false

	file.store_string(json_text)
	file.close()

	is_dirty = false
	var timestamp := Time.get_time_string_from_system()
	_set_status("Successfully saved to %s at %s" % [path, timestamp])

	# Notify Godot editor filesystem if in editor
	if Engine.is_editor_hint():
		var fs := EditorInterface.get_resource_filesystem()
		if fs:
			fs.recheck_file(path)

	return true


func _set_status(msg: String, is_err: bool = false) -> void:
	if status_label:
		status_label.text = msg
		status_label.modulate = Color(1.0, 0.4, 0.4) if is_err else Color(0.6, 1.0, 0.6)


func _on_save_pressed() -> void:
	save_to_file()


func _on_tab_changed(_tab_idx: int) -> void:
	_refresh_tester_options()


# ==============================================================================
# UI POPULATION & REFRESH
# ==============================================================================
func _refresh_all_views() -> void:
	_populate_locations()
	_populate_openings()
	_populate_category_options()
	_populate_category_excuses()
	_populate_requests()
	_refresh_tester_options()


# --- Locations & Items ---
func _populate_locations() -> void:
	loc_item_list.clear()
	var locations: Array = data.get("locations", [])
	for i in range(locations.size()):
		var loc: Dictionary = locations[i]
		var label := "%s (%s)" % [loc.get("proper_name", "Untitled"), loc.get("category", "-")]
		loc_item_list.add_item(label)

	if not locations.is_empty():
		_current_loc_idx = clampi(_current_loc_idx, 0, locations.size() - 1)
		loc_item_list.select(_current_loc_idx)
		_display_current_location()
	else:
		_current_loc_idx = -1
		_clear_location_fields()


func _display_current_location() -> void:
	var locations: Array = data.get("locations", [])
	if _current_loc_idx < 0 or _current_loc_idx >= locations.size():
		_clear_location_fields()
		return

	var loc: Dictionary = locations[_current_loc_idx]
	loc_id_edit.text = str(loc.get("id", ""))
	loc_proper_edit.text = str(loc.get("proper_name", ""))
	loc_generic_edit.text = str(loc.get("generic_name", ""))
	loc_cat_edit.text = str(loc.get("category", ""))

	_populate_items()


func _clear_location_fields() -> void:
	loc_id_edit.text = ""
	loc_proper_edit.text = ""
	loc_generic_edit.text = ""
	loc_cat_edit.text = ""
	item_item_list.clear()
	item_name_edit.text = ""
	item_excuse_list.clear()
	item_excuse_edit.text = ""


func _populate_items() -> void:
	item_item_list.clear()
	var locations: Array = data.get("locations", [])
	if _current_loc_idx < 0 or _current_loc_idx >= locations.size():
		return

	var loc: Dictionary = locations[_current_loc_idx]
	var items: Array = loc.get("items", [])
	for item in items:
		item_item_list.add_item(str(item))

	if not items.is_empty():
		_current_item_idx = clampi(_current_item_idx, 0, items.size() - 1)
		item_item_list.select(_current_item_idx)
		_display_current_item()
	else:
		_current_item_idx = -1
		item_name_edit.text = ""
		_populate_item_excuses()


func _display_current_item() -> void:
	var locations: Array = data.get("locations", [])
	if _current_loc_idx < 0 or _current_loc_idx >= locations.size():
		return
	var items: Array = locations[_current_loc_idx].get("items", [])
	if _current_item_idx < 0 or _current_item_idx >= items.size():
		item_name_edit.text = ""
		_populate_item_excuses()
		return

	var item_name := str(items[_current_item_idx])
	item_name_edit.text = item_name
	_populate_item_excuses()


func _populate_item_excuses() -> void:
	item_excuse_list.clear()
	var locations: Array = data.get("locations", [])
	if _current_loc_idx < 0 or _current_loc_idx >= locations.size():
		item_excuse_edit.text = ""
		return

	var items: Array = locations[_current_loc_idx].get("items", [])
	if _current_item_idx < 0 or _current_item_idx >= items.size():
		item_excuse_edit.text = ""
		return

	var item_name := str(items[_current_item_idx])
	var item_id := _item_name_to_id(item_name)
	item_excuse_header_label.text = "3. Specific Excuses for '%s' (ID: %s)" % [item_name, item_id]

	var dp: Dictionary = data.get("dialogue_parts", {})
	var item_excuses: Dictionary = dp.get("item_excuses", {})
	var excuses: Array = item_excuses.get(item_id, [])

	for exc in excuses:
		item_excuse_list.add_item(str(exc))

	if not excuses.is_empty():
		_current_item_excuse_idx = clampi(_current_item_excuse_idx, 0, excuses.size() - 1)
		item_excuse_list.select(_current_item_excuse_idx)
		item_excuse_edit.text = str(excuses[_current_item_excuse_idx])
	else:
		_current_item_excuse_idx = -1
		item_excuse_edit.text = ""


# --- Dialogue Pools: Openings ---
func _populate_openings() -> void:
	opening_item_list.clear()
	var dp: Dictionary = data.get("dialogue_parts", {})
	var openings: Array = dp.get("openings", [])
	for op in openings:
		opening_item_list.add_item(str(op))

	if not openings.is_empty():
		_current_opening_idx = clampi(_current_opening_idx, 0, openings.size() - 1)
		opening_item_list.select(_current_opening_idx)
		var text := str(openings[_current_opening_idx])
		opening_edit.text = text
		opening_preview.text = _format_bbcode_preview(text)
	else:
		_current_opening_idx = -1
		opening_edit.text = ""
		opening_preview.text = ""


# --- Dialogue Pools: Category Excuses ---
func _populate_category_options() -> void:
	cat_option_btn.clear()
	var dp: Dictionary = data.get("dialogue_parts", {})
	var excuses: Dictionary = dp.get("excuses", {})

	var cats: Array = excuses.keys()
	if not cats.has("general"):
		cats.push_front("general")

	var selected_idx := 0
	for i in range(cats.size()):
		var cat_name: String = str(cats[i])
		cat_option_btn.add_item(cat_name)
		if cat_name == _current_cat_key:
			selected_idx = i

	cat_option_btn.select(selected_idx)
	_current_cat_key = cat_option_btn.get_item_text(selected_idx)


func _populate_category_excuses() -> void:
	cat_excuse_list.clear()
	var dp: Dictionary = data.get("dialogue_parts", {})
	var excuses: Dictionary = dp.get("excuses", {})
	var list: Array = excuses.get(_current_cat_key, [])

	for exc in list:
		cat_excuse_list.add_item(str(exc))

	if not list.is_empty():
		_current_cat_excuse_idx = clampi(_current_cat_excuse_idx, 0, list.size() - 1)
		cat_excuse_list.select(_current_cat_excuse_idx)
		cat_excuse_edit.text = str(list[_current_cat_excuse_idx])
	else:
		_current_cat_excuse_idx = -1
		cat_excuse_edit.text = ""


# --- Dialogue Pools: Requests ---
func _populate_requests() -> void:
	request_item_list.clear()
	var dp: Dictionary = data.get("dialogue_parts", {})
	var requests: Array = dp.get("requests", [])
	for req in requests:
		request_item_list.add_item(str(req))

	if not requests.is_empty():
		_current_request_idx = clampi(_current_request_idx, 0, requests.size() - 1)
		request_item_list.select(_current_request_idx)
		request_edit.text = str(requests[_current_request_idx])
	else:
		_current_request_idx = -1
		request_edit.text = ""


# ==============================================================================
# TAB 3: TESTER & COMBINER LOGIC
# ==============================================================================
func _refresh_tester_options() -> void:
	if test_loc_option == null:
		return
	# Populate locations
	var prev_loc_id := (
		test_loc_option.get_item_metadata(test_loc_option.selected)
		if test_loc_option.item_count > 0 and test_loc_option.selected >= 0
		else ""
	)
	test_loc_option.clear()
	var locations: Array = data.get("locations", [])
	var select_loc_idx := 0
	for i in range(locations.size()):
		var loc: Dictionary = locations[i]
		var id := str(loc.get("id", ""))
		test_loc_option.add_item("%s (%s)" % [loc.get("proper_name", id), loc.get("category", "-")])
		test_loc_option.set_item_metadata(i, id)
		if id == prev_loc_id:
			select_loc_idx = i

	if not locations.is_empty():
		test_loc_option.select(select_loc_idx)

	_on_test_loc_changed(test_loc_option.selected)


func _on_test_loc_changed(_idx: int) -> void:
	test_item_option.clear()
	var loc := _get_test_selected_location()
	if loc.is_empty():
		return

	var items: Array = loc.get("items", [])
	for i in range(items.size()):
		test_item_option.add_item(str(items[i]))

	if not items.is_empty():
		test_item_option.select(0)

	_populate_test_openings()
	_populate_test_excuses()
	_populate_test_requests()
	_update_tester_preview()


func _on_test_item_changed(_idx: int) -> void:
	_populate_test_excuses()
	_update_tester_preview()


func _populate_test_openings() -> void:
	test_opening_option.clear()
	test_opening_option.add_item("🎲 [Random Opening]")
	test_opening_option.set_item_metadata(0, "")

	var dp: Dictionary = data.get("dialogue_parts", {})
	var openings: Array = dp.get("openings", [])
	for i in range(openings.size()):
		var line := str(openings[i])
		test_opening_option.add_item(line)
		test_opening_option.set_item_metadata(i + 1, line)


func _populate_test_excuses() -> void:
	test_excuse_option.clear()
	test_excuse_option.add_item("🎲 [Game Logic: 45% item excuse, else category/general]")
	test_excuse_option.set_item_metadata(0, {"type": "rng"})

	var loc := _get_test_selected_location()
	var item_name := _get_test_selected_item_name()
	var item_id := _item_name_to_id(item_name)
	var category := str(loc.get("category", ""))

	var dp: Dictionary = data.get("dialogue_parts", {})
	var item_excuses: Dictionary = dp.get("item_excuses", {})
	var specific: Array = item_excuses.get(item_id, [])

	# 1. Item-specific excuses
	for exc in specific:
		var line := str(exc)
		var item_idx := test_excuse_option.item_count
		test_excuse_option.add_item("⭐ [Item: %s] %s" % [item_name, line])
		test_excuse_option.set_item_metadata(
			item_idx, {"type": "fixed", "line": line, "src": "Item-Specific (%s)" % item_name}
		)

	# 2. Category excuses
	var cat_excuses: Dictionary = dp.get("excuses", {})
	if not category.is_empty() and cat_excuses.has(category):
		var cat_list: Array = cat_excuses.get(category, [])
		for exc in cat_list:
			var line := str(exc)
			var item_idx := test_excuse_option.item_count
			test_excuse_option.add_item("🏷️ [%s] %s" % [category.capitalize(), line])
			test_excuse_option.set_item_metadata(
				item_idx,
				{"type": "fixed", "line": line, "src": "Category (%s)" % category.capitalize()}
			)

	# 3. General excuses
	var general_list: Array = cat_excuses.get("general", [])
	for exc in general_list:
		var line := str(exc)
		var item_idx := test_excuse_option.item_count
		test_excuse_option.add_item("📦 [General] %s" % line)
		test_excuse_option.set_item_metadata(
			item_idx, {"type": "fixed", "line": line, "src": "General"}
		)


func _populate_test_requests() -> void:
	test_request_option.clear()
	test_request_option.add_item("🎲 [Random Request Template]")
	test_request_option.set_item_metadata(0, "")

	var dp: Dictionary = data.get("dialogue_parts", {})
	var requests: Array = dp.get("requests", [])
	for i in range(requests.size()):
		var line := str(requests[i])
		test_request_option.add_item(line)
		test_request_option.set_item_metadata(i + 1, line)


func _on_test_roll_pressed() -> void:
	# Reset selectors to random
	if test_opening_option.item_count > 0:
		test_opening_option.select(0)
	if test_excuse_option.item_count > 0:
		test_excuse_option.select(0)
	if test_request_option.item_count > 0:
		test_request_option.select(0)

	_update_tester_preview()


func _update_tester_preview() -> void:
	var loc := _get_test_selected_location()
	var item_name := _get_test_selected_item_name()
	if loc.is_empty() or item_name.is_empty():
		test_output_display.text = "Select a valid location and item to test."
		return

	var proper_name := str(loc.get("proper_name", ""))
	var generic_name := str(loc.get("generic_name", ""))
	var use_generic: bool = test_generic_check.button_pressed
	var chosen_loc := generic_name if use_generic and not generic_name.is_empty() else proper_name
	var category := str(loc.get("category", ""))

	var dp: Dictionary = data.get("dialogue_parts", {})

	# 1. Opening
	var opening_meta = (
		test_opening_option.get_item_metadata(test_opening_option.selected)
		if test_opening_option.selected >= 0
		else ""
	)
	var opening: String = ""
	if opening_meta is String and not opening_meta.is_empty():
		opening = opening_meta
	else:
		var openings: Array = dp.get("openings", [])
		if not openings.is_empty():
			opening = str(openings[randi() % openings.size()])

	# 2. Excuse
	var excuse_meta = (
		test_excuse_option.get_item_metadata(test_excuse_option.selected)
		if test_excuse_option.selected >= 0
		else {"type": "rng"}
	)
	var excuse: String = ""
	var excuse_source: String = ""

	if excuse_meta is Dictionary and excuse_meta.get("type", "") == "fixed":
		excuse = str(excuse_meta.get("line", ""))
		excuse_source = str(excuse_meta.get("src", "Manual Choice"))
	else:
		# Use identical logic to ObjectiveManager.pick_excuse
		var item_id := _item_name_to_id(item_name)
		var item_excuses: Dictionary = dp.get("item_excuses", {})
		var specific: Array = item_excuses.get(item_id, [])

		var pool: Array[String] = []
		var cat_excuses: Dictionary = dp.get("excuses", {})
		var gen: Array = cat_excuses.get("general", [])
		for g in gen:
			pool.append(str(g))
		if not category.is_empty() and cat_excuses.has(category):
			var cat_list: Array = cat_excuses.get(category, [])
			for c in cat_list:
				pool.append(str(c))

		# 45% weight to pick item-specific excuse when available
		if not specific.is_empty() and (pool.is_empty() or randf() < 0.45):
			excuse = str(specific[randi() % specific.size()])
			excuse_source = "Item-Specific (%s) [45%% Roll]" % item_name
		elif not pool.is_empty():
			excuse = pool[randi() % pool.size()]
			excuse_source = "Category / General Pool"
		elif not specific.is_empty():
			excuse = str(specific[randi() % specific.size()])
			excuse_source = "Item-Specific Fallback"

	if not excuse.is_empty():
		excuse = excuse.replace("{item}", item_name).replace("{location}", chosen_loc)

	# 3. Request
	var req_meta = (
		test_request_option.get_item_metadata(test_request_option.selected)
		if test_request_option.selected >= 0
		else ""
	)
	var request_template: String = ""
	if req_meta is String and not req_meta.is_empty():
		request_template = req_meta
	else:
		var requests: Array = dp.get("requests", [])
		if not requests.is_empty():
			request_template = str(requests[randi() % requests.size()])
		else:
			request_template = "Could you pick up some {item} at {location}?"

	var request := request_template.replace("{item}", item_name).replace("{location}", chosen_loc)

	# Combined call line
	var parts: Array[String] = []
	if not opening.is_empty():
		parts.append(opening)
	if not excuse.is_empty():
		parts.append(excuse)
	if not request.is_empty():
		parts.append(request)

	var full_line := " ".join(parts)

	# Update UI display
	test_output_display.text = (
		'[font_size=15][color=#ffdd88]"%s"[/color][/font_size]' % _format_bbcode_preview(full_line)
	)

	test_breakdown_loc.text = "%s (Category: %s)" % [chosen_loc, category]
	test_breakdown_opening.text = opening if not opening.is_empty() else "(None)"
	test_breakdown_excuse.text = excuse if not excuse.is_empty() else "(None)"
	test_breakdown_excuse_src.text = excuse_source
	test_breakdown_request.text = request


func _get_test_selected_location() -> Dictionary:
	var locations: Array = data.get("locations", [])
	var idx := test_loc_option.selected
	if idx >= 0 and idx < locations.size():
		return locations[idx]
	return {}


func _get_test_selected_item_name() -> String:
	var idx := test_item_option.selected
	if idx >= 0 and idx < test_item_option.item_count:
		return test_item_option.get_item_text(idx)
	return ""


# ==============================================================================
# EVENT HANDLERS & MODIFIERS
# ==============================================================================
# --- Location Events ---
func _on_loc_selected(idx: int) -> void:
	_current_loc_idx = idx
	_current_item_idx = 0
	_current_item_excuse_idx = 0
	_display_current_location()


func _on_add_location() -> void:
	var locations: Array = data.get("locations", [])
	var new_loc := {
		"id": "new_store",
		"proper_name": "New Store",
		"generic_name": "the store",
		"category": "convenience",
		"items": ["new item"]
	}
	locations.append(new_loc)
	_current_loc_idx = locations.size() - 1
	_populate_locations()
	_mark_dirty()


func _on_delete_location() -> void:
	var locations: Array = data.get("locations", [])
	if _current_loc_idx >= 0 and _current_loc_idx < locations.size():
		locations.remove_at(_current_loc_idx)
		_current_loc_idx = clampi(_current_loc_idx - 1, 0, locations.size() - 1)
		_populate_locations()
		_mark_dirty()


func _on_loc_field_changed(_new_text: String) -> void:
	var locations: Array = data.get("locations", [])
	if _current_loc_idx < 0 or _current_loc_idx >= locations.size():
		return

	var loc: Dictionary = locations[_current_loc_idx]
	loc["id"] = loc_id_edit.text.strip_edges()
	loc["proper_name"] = loc_proper_edit.text.strip_edges()
	loc["generic_name"] = loc_generic_edit.text.strip_edges()
	loc["category"] = loc_cat_edit.text.strip_edges()

	# Update list label
	loc_item_list.set_item_text(_current_loc_idx, "%s (%s)" % [loc["proper_name"], loc["category"]])
	_mark_dirty()


# --- Item Events ---
func _on_item_selected(idx: int) -> void:
	_current_item_idx = idx
	_current_item_excuse_idx = 0
	_display_current_item()


func _on_add_item() -> void:
	var locations: Array = data.get("locations", [])
	if _current_loc_idx < 0 or _current_loc_idx >= locations.size():
		return

	var items: Array = locations[_current_loc_idx].get("items", [])
	items.append("new item")
	_current_item_idx = items.size() - 1
	_populate_items()
	_mark_dirty()


func _on_delete_item() -> void:
	var locations: Array = data.get("locations", [])
	if _current_loc_idx < 0 or _current_loc_idx >= locations.size():
		return

	var items: Array = locations[_current_loc_idx].get("items", [])
	if _current_item_idx >= 0 and _current_item_idx < items.size():
		items.remove_at(_current_item_idx)
		_current_item_idx = clampi(_current_item_idx - 1, 0, items.size() - 1)
		_populate_items()
		_mark_dirty()


func _on_item_name_changed(new_text: String) -> void:
	var locations: Array = data.get("locations", [])
	if _current_loc_idx < 0 or _current_loc_idx >= locations.size():
		return

	var items: Array = locations[_current_loc_idx].get("items", [])
	if _current_item_idx < 0 or _current_item_idx >= items.size():
		return

	var old_name: String = str(items[_current_item_idx])
	var old_id := _item_name_to_id(old_name)
	var new_name := new_text.strip_edges()
	var new_id := _item_name_to_id(new_name)

	items[_current_item_idx] = new_name
	item_item_list.set_item_text(_current_item_idx, new_name)

	# Migrate item excuses if key changed
	if old_id != new_id and not old_id.is_empty():
		var dp: Dictionary = data.get("dialogue_parts", {})
		var item_excuses: Dictionary = dp.get("item_excuses", {})
		if item_excuses.has(old_id):
			item_excuses[new_id] = item_excuses[old_id]
			item_excuses.erase(old_id)

	item_excuse_header_label.text = "3. Specific Excuses for '%s' (ID: %s)" % [new_name, new_id]
	_mark_dirty()


# --- Item Excuse Events ---
func _on_item_excuse_selected(idx: int) -> void:
	_current_item_excuse_idx = idx
	var excuses := _get_current_item_excuses_array()
	if idx >= 0 and idx < excuses.size():
		item_excuse_edit.text = str(excuses[idx])


func _on_add_item_excuse() -> void:
	var excuses := _get_current_item_excuses_array(true)
	excuses.append("New excuse for this item...")
	_current_item_excuse_idx = excuses.size() - 1
	_populate_item_excuses()
	_mark_dirty()


func _on_delete_item_excuse() -> void:
	var excuses := _get_current_item_excuses_array()
	if _current_item_excuse_idx >= 0 and _current_item_excuse_idx < excuses.size():
		excuses.remove_at(_current_item_excuse_idx)
		_current_item_excuse_idx = clampi(_current_item_excuse_idx - 1, 0, excuses.size() - 1)
		_populate_item_excuses()
		_mark_dirty()


func _on_item_excuse_text_changed() -> void:
	var excuses := _get_current_item_excuses_array()
	if _current_item_excuse_idx >= 0 and _current_item_excuse_idx < excuses.size():
		excuses[_current_item_excuse_idx] = item_excuse_edit.text
		item_excuse_list.set_item_text(_current_item_excuse_idx, item_excuse_edit.text)
		_mark_dirty()


func _get_current_item_excuses_array(create_if_missing: bool = false) -> Array:
	var locations: Array = data.get("locations", [])
	if _current_loc_idx < 0 or _current_loc_idx >= locations.size():
		return []

	var items: Array = locations[_current_loc_idx].get("items", [])
	if _current_item_idx < 0 or _current_item_idx >= items.size():
		return []

	var item_name := str(items[_current_item_idx])
	var item_id := _item_name_to_id(item_name)

	var dp: Dictionary = data.get("dialogue_parts", {})
	if not dp.has("item_excuses"):
		dp["item_excuses"] = {}
	var item_excuses: Dictionary = dp["item_excuses"]

	if not item_excuses.has(item_id):
		if create_if_missing:
			item_excuses[item_id] = []
		else:
			return []

	return item_excuses[item_id]


# --- Dialogue Pools: Openings Events ---
func _on_opening_selected(idx: int) -> void:
	_current_opening_idx = idx
	var dp: Dictionary = data.get("dialogue_parts", {})
	var openings: Array = dp.get("openings", [])
	if idx >= 0 and idx < openings.size():
		var text := str(openings[idx])
		opening_edit.text = text
		opening_preview.text = _format_bbcode_preview(text)


func _on_add_opening() -> void:
	var dp: Dictionary = data.get("dialogue_parts", {})
	var openings: Array = dp.get("openings", [])
	openings.append("Mats, new greeting [[i]translation[/i]]...")
	_current_opening_idx = openings.size() - 1
	_populate_openings()
	_mark_dirty()


func _on_delete_opening() -> void:
	var dp: Dictionary = data.get("dialogue_parts", {})
	var openings: Array = dp.get("openings", [])
	if _current_opening_idx >= 0 and _current_opening_idx < openings.size():
		openings.remove_at(_current_opening_idx)
		_current_opening_idx = clampi(_current_opening_idx - 1, 0, openings.size() - 1)
		_populate_openings()
		_mark_dirty()


func _on_opening_text_changed() -> void:
	var dp: Dictionary = data.get("dialogue_parts", {})
	var openings: Array = dp.get("openings", [])
	if _current_opening_idx >= 0 and _current_opening_idx < openings.size():
		var text := opening_edit.text
		openings[_current_opening_idx] = text
		opening_item_list.set_item_text(_current_opening_idx, text)
		opening_preview.text = _format_bbcode_preview(text)
		_mark_dirty()


# --- Dialogue Pools: Category Excuse Events ---
func _on_cat_option_selected(idx: int) -> void:
	_current_cat_key = cat_option_btn.get_item_text(idx)
	_current_cat_excuse_idx = 0
	_populate_category_excuses()


func _on_add_category() -> void:
	var dp: Dictionary = data.get("dialogue_parts", {})
	var excuses: Dictionary = dp.get("excuses", {})
	var new_cat_name := "custom_%d" % (excuses.size() + 1)
	if not excuses.has(new_cat_name):
		excuses[new_cat_name] = ["Initial excuse for " + new_cat_name]
	_current_cat_key = new_cat_name
	_populate_category_options()
	_populate_category_excuses()
	_mark_dirty()


func _on_cat_excuse_selected(idx: int) -> void:
	_current_cat_excuse_idx = idx
	var dp: Dictionary = data.get("dialogue_parts", {})
	var excuses: Dictionary = dp.get("excuses", {})
	var list: Array = excuses.get(_current_cat_key, [])
	if idx >= 0 and idx < list.size():
		cat_excuse_edit.text = str(list[idx])


func _on_add_cat_excuse() -> void:
	var dp: Dictionary = data.get("dialogue_parts", {})
	var excuses: Dictionary = dp.get("excuses", {})
	if not excuses.has(_current_cat_key):
		excuses[_current_cat_key] = []
	var list: Array = excuses[_current_cat_key]
	list.append("New category excuse...")
	_current_cat_excuse_idx = list.size() - 1
	_populate_category_excuses()
	_mark_dirty()


func _on_delete_cat_excuse() -> void:
	var dp: Dictionary = data.get("dialogue_parts", {})
	var excuses: Dictionary = dp.get("excuses", {})
	var list: Array = excuses.get(_current_cat_key, [])
	if _current_cat_excuse_idx >= 0 and _current_cat_excuse_idx < list.size():
		list.remove_at(_current_cat_excuse_idx)
		_current_cat_excuse_idx = clampi(_current_cat_excuse_idx - 1, 0, list.size() - 1)
		_populate_category_excuses()
		_mark_dirty()


func _on_cat_excuse_text_changed() -> void:
	var dp: Dictionary = data.get("dialogue_parts", {})
	var excuses: Dictionary = dp.get("excuses", {})
	var list: Array = excuses.get(_current_cat_key, [])
	if _current_cat_excuse_idx >= 0 and _current_cat_excuse_idx < list.size():
		list[_current_cat_excuse_idx] = cat_excuse_edit.text
		cat_excuse_list.set_item_text(_current_cat_excuse_idx, cat_excuse_edit.text)
		_mark_dirty()


# --- Dialogue Pools: Requests Events ---
func _on_request_selected(idx: int) -> void:
	_current_request_idx = idx
	var dp: Dictionary = data.get("dialogue_parts", {})
	var requests: Array = dp.get("requests", [])
	if idx >= 0 and idx < requests.size():
		request_edit.text = str(requests[idx])


func _on_add_request() -> void:
	var dp: Dictionary = data.get("dialogue_parts", {})
	var requests: Array = dp.get("requests", [])
	requests.append("Could you grab some {item} at {location}?")
	_current_request_idx = requests.size() - 1
	_populate_requests()
	_mark_dirty()


func _on_delete_request() -> void:
	var dp: Dictionary = data.get("dialogue_parts", {})
	var requests: Array = dp.get("requests", [])
	if _current_request_idx >= 0 and _current_request_idx < requests.size():
		requests.remove_at(_current_request_idx)
		_current_request_idx = clampi(_current_request_idx - 1, 0, requests.size() - 1)
		_populate_requests()
		_mark_dirty()


func _on_request_text_changed() -> void:
	var dp: Dictionary = data.get("dialogue_parts", {})
	var requests: Array = dp.get("requests", [])
	if _current_request_idx >= 0 and _current_request_idx < requests.size():
		requests[_current_request_idx] = request_edit.text
		request_item_list.set_item_text(_current_request_idx, request_edit.text)
		_mark_dirty()


# ==============================================================================
# HELPERS
# ==============================================================================
func _item_name_to_id(item_name: String) -> String:
	return item_name.to_lower().replace("-", "_").replace(" ", "_")


func _format_bbcode_preview(text: String) -> String:
	# Format double brackets [[i]...[/i]] into readable bbcode
	return text.replace("[[i]", "[i][color=#88ccff]").replace("[/i]]", "[/color][/i]")


func _make_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	return lbl


func _mark_dirty() -> void:
	is_dirty = true
	_set_status("Unsaved changes...", false)
