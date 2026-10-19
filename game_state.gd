class_name GameState
extends Node

## Global game state and environment management.
## Tracks global variables including wind direction, speed, and time-varying weather.

## Emitted whenever the wind direction or speed updates.
signal wind_changed(direction: Vector3, speed: float)
enum TimeOfDay { DAY, EVENING, NIGHT }

## Emitted whenever the time of day changes.
signal time_of_day_changed(mode: TimeOfDay)

## Base prevailing wind angle (in radians). Default ~12° (0.209 rad, blowing eastward along the stroad corridor).
@export var base_wind_angle: float = 0.20944

## Base wind speed (intensity multiplier, nominally 1.0).
@export var base_wind_speed: float = 1.0

## Speed multiplier for wind changes over time.
@export var wind_variation_speed: float = 1.0

## Initial time of day setting.
@export var initial_time_of_day: TimeOfDay = TimeOfDay.DAY

## Current time of day state.
static var time_of_day: TimeOfDay = TimeOfDay.DAY

## Current night mode state (true if TimeOfDay.NIGHT).
static var night_mode: bool:
	get:
		return time_of_day == TimeOfDay.NIGHT

## Global wind direction (normalized 3D vector in horizontal XZ plane, Y = 0.0).
## Points in the direction the wind is blowing towards.
static var wind_direction: Vector3 = Vector3(0.978148, 0.0, 0.207912).normalized()

## Wind direction as a 2D vector in the ground plane (X, Z).
static var wind_direction_2d: Vector2:
	get:
		return Vector2(wind_direction.x, wind_direction.z)

## Wind heading angle in radians in the XZ plane (0 = towards +X / East).
static var wind_angle: float = 0.20944

## Current wind speed / strength multiplier (nominally 1.0, gently fluctuating with gusts).
static var wind_speed: float = 1.0

## Full wind velocity vector (direction * speed).
static var wind_velocity: Vector3:
	get:
		return wind_direction * wind_speed

static var instance: GameState = null

static var _time: float = 0.0
static var _manual_override: bool = false


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _ready() -> void:
	_update_wind_calculation(base_wind_angle, base_wind_speed)
	var user_args := OS.get_cmdline_user_args()
	if "--night-mode" in user_args:
		time_of_day = TimeOfDay.NIGHT
	elif "--evening-mode" in user_args or "--sunset-mode" in user_args:
		time_of_day = TimeOfDay.EVENING
	else:
		time_of_day = initial_time_of_day
	if time_of_day != TimeOfDay.DAY and instance:
		instance.time_of_day_changed.emit(time_of_day)


func _process(delta: float) -> void:
	if not _manual_override:
		_time += delta * wind_variation_speed
		_update_wind_calculation(base_wind_angle, base_wind_speed)
		if instance:
			instance.wind_changed.emit(wind_direction, wind_speed)


## Static advance method for testing or manual simulation stepping.
static func advance(delta: float, p_base_angle: float = 0.20944, p_base_speed: float = 1.0) -> void:
	if not _manual_override:
		_time += delta
		_update_wind_calculation(p_base_angle, p_base_speed)
		if instance:
			instance.wind_changed.emit(wind_direction, wind_speed)


## Updates wind direction and speed based on smooth multi-harmonic continuous functions.
## Produces natural, subtle wandering without abrupt shifts or repetition.
static func _update_wind_calculation(p_base_angle: float, p_base_speed: float) -> void:
	var t: float = _time
	# Subtle wandering composed of multi-octave harmonic sines:
	var wander: float = (
		sin(t * 0.042) * deg_to_rad(6.5)
		+ sin(t * 0.091) * deg_to_rad(4.5)
		+ sin(t * 0.23) * deg_to_rad(2.5)
	)
	var current_ang: float = p_base_angle + wander
	wind_angle = current_ang
	wind_direction = Vector3(cos(current_ang), 0.0, sin(current_ang)).normalized()

	# Wind speed / gust subtle variation (fluctuates ~0.85 to 1.18)
	var gust: float = sin(t * 0.073) * 0.09 + sin(t * 0.28) * 0.06 + sin(t * 0.65) * 0.03
	wind_speed = maxf(0.2, p_base_speed * (1.0 + gust))


## Explicitly set the wind direction vector. Disables automatic time-based wander if manual_override is true.
static func set_wind_direction(dir: Vector3, manual_override: bool = false) -> void:
	var horizontal := Vector3(dir.x, 0.0, dir.z)
	if horizontal.is_zero_approx():
		return
	wind_direction = horizontal.normalized()
	wind_angle = atan2(wind_direction.z, wind_direction.x)
	_manual_override = manual_override
	if instance:
		instance.wind_changed.emit(wind_direction, wind_speed)


## Explicitly set the wind heading angle in radians.
static func set_wind_angle(angle: float, manual_override: bool = false) -> void:
	wind_angle = angle
	wind_direction = Vector3(cos(angle), 0.0, sin(angle)).normalized()
	_manual_override = manual_override
	if instance:
		instance.wind_changed.emit(wind_direction, wind_speed)


## Explicitly set the wind speed multiplier.
static func set_wind_speed(speed: float) -> void:
	wind_speed = maxf(0.0, speed)
	if instance:
		instance.wind_changed.emit(wind_direction, wind_speed)


## Resume automatic time-based wind simulation if previously manually overridden.
static func resume_wind_simulation() -> void:
	_manual_override = false


## Returns true if environment artificial lights (streetlights, headlamps) should be active.
static func are_lights_on() -> bool:
	return time_of_day != TimeOfDay.DAY


## Explicitly set the time of day.
static func set_time_of_day(mode: TimeOfDay) -> void:
	if time_of_day == mode:
		return
	time_of_day = mode
	if instance:
		instance.time_of_day_changed.emit(mode)


## Cycles time of day (DAY -> EVENING -> NIGHT -> DAY) and returns the new state.
static func cycle_time_of_day() -> TimeOfDay:
	match time_of_day:
		TimeOfDay.DAY:
			set_time_of_day(TimeOfDay.EVENING)
		TimeOfDay.EVENING:
			set_time_of_day(TimeOfDay.NIGHT)
		TimeOfDay.NIGHT:
			set_time_of_day(TimeOfDay.DAY)
	return time_of_day


## Explicitly set night mode on or off.
static func set_night_mode(enabled: bool) -> void:
	set_time_of_day(TimeOfDay.NIGHT if enabled else TimeOfDay.DAY)


## Toggles night mode / cycles time of day and returns the new state.
static func toggle_night_mode() -> bool:
	cycle_time_of_day()
	return time_of_day != TimeOfDay.DAY
