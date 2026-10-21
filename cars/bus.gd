class_name BusCar
extends Car
## City bus. In a curb lane it serves the bus stops along the stroad: it signals, brakes so its
## front door lines up with the stop pole, tucks in toward the curb, dwells, then signals and
## pulls back out once the lane behind is clear. TrafficManager drives the stop phases.

enum StopPhase { NONE, PULLING_IN, DWELLING, PULLING_OUT }

## |z| of the bus's outer side at a stop: short of the sidewalk curb (Car.CURB_Z) and the sign
## plate hanging off the stop pole, so the bus sits mostly beside the curb lane.
const STOP_OUTER_EDGE := 12.95
## Lateral bias past which lane traffic swerves around the bus instead of queueing behind it.
const BESIDE_LANE_BIAS := 2.2
const DOOR_SETBACK := 1.5  # front door's distance behind the front bumper
const COMFORT_DECEL := 2.0  # braking that starts a stop approach
const MAX_STOP_DECEL := 3.5  # a stop needing harder braking than this is skipped
const SHOULDER_APPROACH := 30.0  # tuck toward the curb only this close to the stop point
const ARRIVAL_TOLERANCE := 0.5
const DWELL_MIN := 6.0
const DWELL_MAX := 12.0
const YIELD_REQUEST_DELAY := 3.0  # signaling this long makes traffic behind yield
const PULL_OUT_LAUNCH_SPEED := 2.0
const PULL_OUT_ACCEL := 2.5
const PULL_OUT_MIN_SPEED := 2.5  # steer back toward the lane only once rolling
const RELEASED_BIAS := 0.05

var stop_phase := StopPhase.NONE
## Lane distance of the last stop pole served or skipped; poles at or before it are behind us.
var last_pole_distance := -INF
var stop_distance := 0.0  # lane distance where the bus center halts
var stop_decel := 0.0
var stop_timer := 0.0  # dwell left while DWELLING, time signaling while PULLING_OUT
var _rolling := false
var _roll_time := 0.0


func _init() -> void:
	car_type = CarType.BUS


func can_park() -> bool:
	return false


func can_take_errands() -> bool:
	return false


func can_use_drive_thru() -> bool:
	return false


func setup(
	p_lane_id: int,
	p_lane_z: float,
	p_dir: float,
	p_start_x: float,
	p_lane_len: float,
	p_speed: float,
	_p_type: CarType = CarType.BUS
) -> void:
	stop_phase = StopPhase.NONE
	last_pole_distance = -INF
	super.setup(p_lane_id, p_lane_z, p_dir, p_start_x, p_lane_len, p_speed, CarType.BUS)


func _apply_visual_type() -> void:
	car_type = CarType.BUS
	var visuals := get_node_or_null("Visuals")
	if visuals:
		var bus_model := visuals.get_node_or_null("Bus")
		if bus_model:
			bus_model.visible = true
	super._apply_visual_type()


func is_curb_stopping() -> bool:
	return super() or stop_phase != StopPhase.NONE


func is_beside_lane() -> bool:
	return super() or (stop_phase != StopPhase.NONE and absf(lateral_bias) >= BESIDE_LANE_BIAS)


func is_requesting_lane_reentry() -> bool:
	return (
		super()
		or (stop_phase == StopPhase.PULLING_OUT and (_rolling or stop_timer >= YIELD_REQUEST_DELAY))
	)


func _is_wander_centered() -> bool:
	return super() or stop_phase != StopPhase.NONE


## Lane distance of the bus center when its front door is at a pole at pole_d.
func stop_distance_for(pole_d: float) -> float:
	return pole_d - (car_length * 0.5 - DOOR_SETBACK)


## Lateral bias that puts the bus's outer side at STOP_OUTER_EDGE on its lane's curb side.
func curb_bias() -> float:
	return signf(lane_z) * (STOP_OUTER_EDGE - car_width * 0.5) - lane_z


func begin_pull_in(pole_d: float) -> void:
	last_pole_distance = pole_d
	stop_phase = StopPhase.PULLING_IN
	stop_distance = stop_distance_for(pole_d)
	var remaining := maxf(0.1, stop_distance - lane_distance)
	stop_decel = maxf(COMFORT_DECEL, speed * speed / (2.0 * remaining))
	_center_in_lane()
	set_turn_signal(TurnSignal.RIGHT)


## Advances the stop phases; lane_clear says whether pulling back into the lane is safe now.
func advance_stop(delta: float, lane_clear: bool) -> void:
	match stop_phase:
		StopPhase.PULLING_IN:
			var remaining := stop_distance - lane_distance
			if remaining < SHOULDER_APPROACH:
				lateral_bias_target = curb_bias()
			if remaining < ARRIVAL_TOLERANCE and speed < 0.3:
				stop_phase = StopPhase.DWELLING
				stop_timer = randf_range(DWELL_MIN, DWELL_MAX)
				set_turn_signal(TurnSignal.NONE)
		StopPhase.DWELLING:
			stop_timer -= delta
			if stop_timer <= 0.0:
				stop_phase = StopPhase.PULLING_OUT
				stop_timer = 0.0
				_rolling = false
				_roll_time = 0.0
				set_turn_signal(TurnSignal.LEFT)
		StopPhase.PULLING_OUT:
			stop_timer += delta
			_rolling = _rolling or lane_clear
			if _rolling:
				_roll_time += delta
				if speed >= PULL_OUT_MIN_SPEED:
					lateral_bias_target = 0.0
				if lateral_bias_target == 0.0 and absf(lateral_bias) < RELEASED_BIAS:
					stop_phase = StopPhase.NONE
					set_turn_signal(TurnSignal.NONE)
					_init_lane_wander()


## Caps the lane target speed for the current stop phase.
func limit_stop_speed(target: float) -> float:
	match stop_phase:
		StopPhase.PULLING_IN:
			var remaining := stop_distance - lane_distance
			if remaining <= 0.1:
				return 0.0
			return minf(target, sqrt(2.0 * stop_decel * remaining))
		StopPhase.DWELLING:
			return 0.0
		StopPhase.PULLING_OUT:
			if not _rolling:
				return 0.0
			return minf(target, PULL_OUT_LAUNCH_SPEED + PULL_OUT_ACCEL * _roll_time)
	return target
