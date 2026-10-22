extends Main

var _suites: Array[TestSuite] = []


func _enter_tree() -> void:
	_configure_test_fixtures()


func _configure_test_fixtures() -> void:
	var args := OS.get_cmdline_user_args()
	for a in OS.get_cmdline_args():
		if not args.has(a):
			args.append(a)

	var is_startup_test := "--test-startup" in args
	var start_scr = get_node_or_null("StartScreen")
	if start_scr:
		start_scr.skip_start_screen = not is_startup_test

	var tm = get_node_or_null("TrafficManager")
	if tm:
		if not is_startup_test:
			tm.staged_initial_spawn = false
			tm.parking_fill_floor = 0.0
		for arg in args:
			if arg.begins_with("--seed="):
				tm.set_random_seed(int(arg.substr(7)))
				break

	var obj_mgr = get_node_or_null("ObjectiveManager")
	if obj_mgr and is_startup_test:
		obj_mgr.initial_call_delay = 0.25


func _ready() -> void:
	super._ready()

	var candidate_suites: Array[TestSuite] = [
		BenchmarksSuite.new(self, _user_args),
		TrafficContractsSuite.new(self, _user_args),
		TrafficScenariosSuite.new(self, _user_args),
		PlayerInteractionsSuite.new(self, _user_args),
		ObjectivesUiSuite.new(self, _user_args),
	]

	for suite in candidate_suites:
		if suite.matches_args():
			_suites.append(suite)
			suite.setup_ready()


func _physics_process(delta: float) -> void:
	for suite in _suites:
		suite.on_physics_process(delta)
