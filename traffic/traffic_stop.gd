class_name TrafficStop
extends RefCounted
## A police traffic stop on a curb lane (0 or 3). The police car lights up and closes in on the
## car ahead; once it catches up, both pull onto the shoulder (straddling the road edge and the
## sidewalk) at a spot clear of driveways and poles, sit for a while, then the stopped car pulls
## away first and the police follow. Lane traffic swerves around the stopped pair.

enum Phase { PURSUIT, PULLING_OVER, STOPPED, SUSPECT_LEAVING, POLICE_LEAVING, DONE }

const CATCH_UP_GAP := 14.0  # police bumper gap that makes the suspect pull over
const MAX_START_GAP := 60.0  # farthest suspect a patrol car will light up for
const PURSUIT_TIMEOUT := 30.0
const PURSUIT_SPEED_BONUS := 6.0
const PULL_OVER_DECEL := 2.5
const PULL_OVER_TIMEOUT := 25.0
## Stay in lane until this close to the stop point, so cars don't ride the shoulder past driveways.
const SHOULDER_APPROACH := 30.0
const ARRIVAL_TOLERANCE := 0.6
const POLICE_GAP := 2.5  # bumper gap between the stopped car and the police behind it
const DWELL_MIN := 12.0
const DWELL_MAX := 22.0
## |z| of the stopped cars' outer side: past the curb at Car.CURB_Z, so they sit half on the road
## and half on the sidewalk, short of the powerline poles along the sidewalk.
const OUTER_EDGE_MIN := 13.15
const OUTER_EDGE_MAX := 13.4
## A pulled-over car this far toward the shoulder no longer blocks its lane.
const SHOULDERED_BIAS := 2.0
const PULL_OUT_MIN_SPEED := 2.5  # steer back toward the lane only once rolling
const PULL_OUT_LAUNCH_SPEED := 2.0
const PULL_OUT_ACCEL := 3.0  # gentle launch off the shoulder
const RELEASED_BIAS := 0.05
const POLICE_FOLLOW_DISTANCE := 12.0  # police leave once the stopped car has pulled this far away
const PULL_OUT_PATIENCE := 15.0  # seconds before accepting tighter gaps to pull out
## After signaling this long, a car waiting to leave the shoulder makes traffic behind yield to it,
## as long as that traffic can still stop short of it with the lane model's hard braking.
const YIELD_REQUEST_DELAY := 3.0
## Stop sites: stay inside the visible stroad, off driveways/merges, and clear of street furniture.
const STOP_MIN_X := -88.0
const STOP_MAX_X := 138.0
const LANE_END_MARGIN := 40.0
const SITE_APPROACH_MARGIN := 10.0  # turn-in approach before a site's first point
const SITE_MERGE_MARGIN := 12.0  # merge zone past a site's last point
const SITE_SEARCH_STEP := 2.0
const SITE_SEARCH_RANGE := 200.0
const SITE_END_CLEARANCE := 0.6
const SITE_SIDE_CLEARANCE := 0.35

var police: Car
var suspect: Car
var lane: TrafficManager.Lane
var phase := Phase.PURSUIT
var stop_distance := 0.0  # suspect's stopped lane distance
var police_stop_distance := 0.0
var outer_edge := 0.0
var timer := 0.0
var dwell_left := 0.0
var suspect_rolling := false
var police_rolling := false
var _suspect_roll_time := 0.0
var _police_roll_time := 0.0
var _police_cruise_speed := 0.0


func _init(p_police: Car, p_suspect: Car, p_lane: TrafficManager.Lane) -> void:
	police = p_police
	suspect = p_suspect
	lane = p_lane
	outer_edge = randf_range(OUTER_EDGE_MIN, OUTER_EDGE_MAX)
	for car in [police, suspect]:
		car.traffic_stop = self
		car.lateral_bias_target = 0.0
	_police_cruise_speed = police.desired_speed
	police.desired_speed = maxf(police.desired_speed, suspect.desired_speed + PURSUIT_SPEED_BONUS)
	police.set_siren(true, true)


static func can_patrol(cop: Car) -> bool:
	return (
		is_instance_valid(cop)
		and cop.car_type == Car.CarType.POLICE_SUV
		and cop.motion == Car.Motion.LANE
		and cop.state == Car.State.CRUISING
		and cop.traffic_stop == null
		and cop.errand == null
		and not cop.is_changing_lanes
		and (cop.lane_id == 0 or cop.lane_id == 3)
	)


static func can_be_stopped(target: Car, cop: Car) -> bool:
	if not is_instance_valid(target) or target == cop:
		return false
	if (
		target.car_type == Car.CarType.POLICE_SUV
		or target.car_type == Car.CarType.BUS
		or target.car_type == Car.CarType.SHIPPING_TRUCK
	):
		return false
	return (
		target.motion == Car.Motion.LANE
		and target.state == Car.State.CRUISING
		and target.traffic_stop == null
		and target.errand == null
		and not target.is_changing_lanes
		and target.lane_id == cop.lane_id
		and bumper_gap(cop, target) > 0.0
	)


static func bumper_gap(rear: Car, front: Car) -> float:
	return front.lane_distance - rear.lane_distance - 0.5 * (front.car_length + rear.car_length)


## Earliest lane distance the target can stop at: where the police should catch up (closing at
## PURSUIT_SPEED_BONUS), plus the target's braking distance from there.
static func earliest_stop_distance(cop: Car, target: Car) -> float:
	var chase_time := maxf(0.0, bumper_gap(cop, target) - CATCH_UP_GAP) / PURSUIT_SPEED_BONUS
	var braking := target.speed * target.speed / (2.0 * PULL_OVER_DECEL) + 6.0
	return target.lane_distance + target.speed * chase_time + braking


static func is_car_shouldered(car: Car) -> bool:
	return (
		car.traffic_stop != null
		and car.state == Car.State.PULLED_OVER
		and absf(car.lateral_bias) >= SHOULDERED_BIAS
	)


## Whether traffic behind should treat this curbside car as its leader (yield to it): it has
## signaled long enough to leave, or is already pulling out, and the follower can still stop.
static func is_yielded_to(car: Car, follower: Car) -> bool:
	if not car.is_requesting_lane_reentry():
		return false
	var stopping := follower.speed * follower.speed / (2.0 * TrafficManager.BRAKE_ACCELERATION)
	return bumper_gap(follower, car) >= stopping + 0.5


func is_requesting_gap(car: Car) -> bool:
	if car == suspect:
		return (
			phase == Phase.POLICE_LEAVING
			or (
				phase == Phase.SUSPECT_LEAVING and (suspect_rolling or timer >= YIELD_REQUEST_DELAY)
			)
		)
	if car == police:
		return phase == Phase.POLICE_LEAVING and (police_rolling or timer >= YIELD_REQUEST_DELAY)
	return false


## Never returns a freed car (the suspect may despawn while the police are still leaving).
func partner_of(car: Car) -> Car:
	var partner = suspect if car == police else (police if car == suspect else null)
	return partner if is_instance_valid(partner) else null


## Lateral bias that puts this car's outer side at outer_edge, on the lane's curb side.
func shoulder_bias(car: Car) -> float:
	var side := signf(lane.z)
	return side * (outer_edge - car.car_width * 0.5) - lane.z


## Caps a participant's lane target speed for the current phase.
func limit_speed(car: Car, target: float) -> float:
	match phase:
		Phase.PULLING_OVER:
			var stop_at := stop_distance if car == suspect else police_stop_distance
			return minf(target, _stop_profile(car, stop_at))
		Phase.STOPPED:
			return 0.0
		Phase.SUSPECT_LEAVING:
			if car == suspect and suspect_rolling:
				return minf(target, PULL_OUT_LAUNCH_SPEED + PULL_OUT_ACCEL * _suspect_roll_time)
			return 0.0
		Phase.POLICE_LEAVING:
			if car == police:
				if not police_rolling:
					return 0.0
				return minf(target, PULL_OUT_LAUNCH_SPEED + PULL_OUT_ACCEL * _police_roll_time)
			return minf(target, PULL_OUT_LAUNCH_SPEED + PULL_OUT_ACCEL * _suspect_roll_time)
	return target


## Advances the stop; returns false once it is over (finished or aborted) and fully released.
func update(tm: TrafficManager, delta: float) -> bool:
	if not _participants_valid():
		finish()
		return false
	timer += delta
	match phase:
		Phase.PURSUIT:
			if not _pursuit_intact() or timer > PURSUIT_TIMEOUT:
				finish()
				return false
			if bumper_gap(police, suspect) <= CATCH_UP_GAP:
				var site := find_site(
					tm, lane, earliest_stop_distance(police, suspect), suspect, police, outer_edge
				)
				if site < 0.0:
					finish()
					return false
				_begin_pull_over(site)
		Phase.PULLING_OVER:
			for car in [suspect, police]:
				var stop_at := stop_distance if car == suspect else police_stop_distance
				if stop_at - car.lane_distance < SHOULDER_APPROACH:
					car.lateral_bias_target = shoulder_bias(car)
			if (
				(_arrived(suspect, stop_distance) and _arrived(police, police_stop_distance))
				or timer > PULL_OVER_TIMEOUT
			):
				_begin_stopped()
		Phase.STOPPED:
			dwell_left -= delta
			if dwell_left <= 0.0:
				phase = Phase.SUSPECT_LEAVING
				timer = 0.0
				suspect.set_turn_signal(Car.TurnSignal.LEFT)
		Phase.SUSPECT_LEAVING:
			if not is_instance_valid(suspect):
				_begin_police_leaving()
				return true
			suspect_rolling = suspect_rolling or can_pull_out(suspect, timer)
			if suspect_rolling:
				_suspect_roll_time += delta
				if _steer_back(suspect):
					_release(suspect)
			if (
				suspect.traffic_stop != self
				or suspect.lane_distance - stop_distance > POLICE_FOLLOW_DISTANCE
			):
				_begin_police_leaving()
		Phase.POLICE_LEAVING:
			if is_instance_valid(suspect) and suspect.traffic_stop == self:
				_suspect_roll_time += delta
				if _steer_back(suspect):
					_release(suspect)
			police_rolling = police_rolling or can_pull_out(police, timer)
			if police_rolling:
				_police_roll_time += delta
				if _steer_back(police):
					finish()
					return false
	return true


## Ends the stop from any phase: cars still on the shoulder steer back into their lane.
func finish() -> void:
	phase = Phase.DONE
	_release(suspect)
	if is_instance_valid(police):
		if police.traffic_stop == self:
			police.desired_speed = _police_cruise_speed
			police.on_patrol = false
		police.set_siren(false)
	_release(police)


func can_pull_out(car: Car, waited: float) -> bool:
	return lane_clear_to_reenter(lane, car, waited, police, suspect)


## True when no lane car is alongside, and the nearest car behind (everything further back must
## stop behind that one) is far enough back for its speed, so car can steer back from the curb
## into check_lane. Traffic that has yielded and stopped behind it is fine. Waiting longer than
## PULL_OUT_PATIENCE accepts tighter gaps. ignore_a/ignore_b (untyped: may be freed) are skipped.
static func lane_clear_to_reenter(
	check_lane: TrafficManager.Lane, car: Car, waited: float, ignore_a, ignore_b
) -> bool:
	var time_gap := 3.0 if waited < PULL_OUT_PATIENCE else 1.8
	var nearest_behind: Car = null
	for other in check_lane.cars:
		if not is_instance_valid(other) or other == car or other == ignore_a or other == ignore_b:
			continue
		if other.is_beside_lane():
			continue
		var ahead := other.lane_distance - car.lane_distance
		if other.is_changing_lanes and absf(ahead) < 30.0:
			return false
		if ahead >= 0.0:
			if bumper_gap(car, other) < 4.0:
				return false
		elif nearest_behind == null or other.lane_distance > nearest_behind.lane_distance:
			nearest_behind = other
	if nearest_behind == null:
		return true
	var gap := bumper_gap(nearest_behind, car)
	if nearest_behind.speed < 0.5:
		return gap > 0.0  # yielded and waiting behind
	return gap >= 3.0 + nearest_behind.speed * time_gap


## First clear stop site (suspect's lane distance) at or past from_d, or -1.0 if none.
static func find_site(
	tm: TrafficManager,
	check_lane: TrafficManager.Lane,
	from_d: float,
	stopped: Car,
	cop: Car,
	edge: float
) -> float:
	var d := from_d
	while d <= from_d + SITE_SEARCH_RANGE:
		if is_site_clear(tm, check_lane, d, stopped, cop, edge):
			return d
		d += SITE_SEARCH_STEP
	return -1.0


## Whether both cars fit on the shoulder with the suspect centered at lane distance d.
static func is_site_clear(
	tm: TrafficManager,
	check_lane: TrafficManager.Lane,
	d: float,
	stopped: Car,
	cop: Car,
	edge: float
) -> bool:
	var police_d := d - (0.5 * stopped.car_length + POLICE_GAP + 0.5 * cop.car_length)
	var back_d := police_d - 0.5 * cop.car_length - SITE_END_CLEARANCE
	var front_d := d + 0.5 * stopped.car_length + SITE_END_CLEARANCE
	if back_d < LANE_END_MARGIN or front_d > check_lane.length - LANE_END_MARGIN:
		return false
	if check_lane.overlaps_bus_stop(back_d, front_d):
		return false
	var x_a := check_lane.start_x + check_lane.direction * back_d
	var x_b := check_lane.start_x + check_lane.direction * front_d
	var min_x := minf(x_a, x_b)
	var max_x := maxf(x_a, x_b)
	if min_x < STOP_MIN_X or max_x > STOP_MAX_X:
		return false
	for site in ParkingLot.SITES.values():
		if site.get("lane_id", -1) != check_lane.id:
			continue
		var zone := _site_zone(site, check_lane)
		if front_d >= zone.x and back_d <= zone.y:
			return false
	return _shoulder_clear(
		tm, check_lane, min_x, max_x, maxf(stopped.car_width, cop.car_width), edge
	)


## Lane-distance interval [x, y] reserved around a lot's turn-in, driveway, and merge.
static func _site_zone(site: Dictionary, check_lane: TrafficManager.Lane) -> Vector2:
	var xs: Array[float] = []
	for key in ["turn_in", "wait", "merge_end"]:
		if site.has(key):
			xs.append((site[key] as Vector3).x)
	for key in ["entry_x", "exit_x"]:
		if site.has(key):
			xs.append(float(site[key]))
	var lo := INF
	var hi := -INF
	for x in xs:
		var dist := check_lane.distance_at(x)
		lo = minf(lo, dist)
		hi = maxf(hi, dist)
	return Vector2(lo - SITE_APPROACH_MARGIN, hi + SITE_MERGE_MARGIN)


## No street furniture (poles, lamps, hydrants, signs, trees) or pedestrians in the shoulder box.
static func _shoulder_clear(
	tm: TrafficManager,
	check_lane: TrafficManager.Lane,
	min_x: float,
	max_x: float,
	width: float,
	edge: float
) -> bool:
	var box := BoxShape3D.new()
	box.size = Vector3(max_x - min_x, 1.6, width + 2.0 * SITE_SIDE_CLEARANCE)
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = box
	params.collision_mask = 1
	params.collide_with_areas = false
	var center_z := signf(check_lane.z) * (edge - width * 0.5)
	# 0.4-2.0 m above the pavement: above curbs and slabs, through anything standing.
	params.transform = Transform3D(Basis(), Vector3((min_x + max_x) * 0.5, 1.2, center_z))
	return tm.get_world_3d().direct_space_state.intersect_shape(params, 1).is_empty()


func _begin_pull_over(site_d: float) -> void:
	phase = Phase.PULLING_OVER
	timer = 0.0
	stop_distance = site_d
	police_stop_distance = (
		site_d - (0.5 * suspect.car_length + POLICE_GAP + 0.5 * police.car_length)
	)
	police.desired_speed = _police_cruise_speed
	for car in [suspect, police]:
		car.state = Car.State.PULLED_OVER
	suspect.set_turn_signal(Car.TurnSignal.RIGHT)


func _begin_police_leaving() -> void:
	phase = Phase.POLICE_LEAVING
	timer = 0.0
	police.set_siren(false)
	police.set_turn_signal(Car.TurnSignal.LEFT)


func _begin_stopped() -> void:
	phase = Phase.STOPPED
	timer = 0.0
	dwell_left = randf_range(DWELL_MIN, DWELL_MAX)
	suspect.set_turn_signal(Car.TurnSignal.NONE)
	police.set_siren(true, false)


func _stop_profile(car: Car, stop_at: float) -> float:
	var remaining := stop_at - car.lane_distance
	if remaining <= 0.1:
		return 0.0
	return sqrt(2.0 * PULL_OVER_DECEL * remaining)


func _arrived(car: Car, stop_at: float) -> bool:
	return absf(stop_at - car.lane_distance) < ARRIVAL_TOLERANCE and car.speed < 0.3


## Eases a departing car back to its lane center once rolling; true once it is back.
func _steer_back(car: Car) -> bool:
	if car.speed >= PULL_OUT_MIN_SPEED:
		car.lateral_bias_target = 0.0
	return car.lateral_bias_target == 0.0 and absf(car.lateral_bias) < RELEASED_BIAS


## Untyped: the suspect may already be freed when a stop ends.
func _release(car) -> void:
	if not is_instance_valid(car) or car.traffic_stop != self:
		return
	car.traffic_stop = null
	car.lateral_bias_target = 0.0
	if car.state == Car.State.PULLED_OVER:
		car.state = Car.State.CRUISING
		car.set_turn_signal(Car.TurnSignal.NONE)


func _participants_valid() -> bool:
	if not is_instance_valid(police) or police.traffic_stop != self:
		return false
	if not is_instance_valid(suspect):
		return phase >= Phase.SUSPECT_LEAVING
	return suspect.traffic_stop == self or phase >= Phase.SUSPECT_LEAVING


func _pursuit_intact() -> bool:
	return (
		police.state == Car.State.CRUISING
		and suspect.state == Car.State.CRUISING
		and police.motion == Car.Motion.LANE
		and suspect.motion == Car.Motion.LANE
		and police.lane_id == lane.id
		and suspect.lane_id == lane.id
		and not police.is_changing_lanes
		and not suspect.is_changing_lanes
		and bumper_gap(police, suspect) > 0.0
	)
