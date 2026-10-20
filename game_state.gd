class_name GameState
extends Node

## Global game state and environment management.
## Tracks global variables including wind direction, speed, and time-varying weather.

## Emitted whenever the wind direction or speed updates.
signal wind_changed(direction: Vector3, speed: float)
enum TimeOfDay { DAY, EVENING, NIGHT }

## Emitted whenever the time of day mode changes.
signal time_of_day_changed(mode: TimeOfDay)

## Emitted whenever the continuous game time updates.
signal time_changed(time_hours: float, time_str: String)

## Emitted when a game day concludes and the next day begins.
signal day_advanced(day_number: int)

const START_HOUR: float = 15.5  # 3:30 PM
const END_HOUR: float = 21.0  # 9:00 PM
const DUSK_HOUR: float = 18.25  # ~6:15 PM (streetlights and headlights turn on)
const NIGHT_HOUR: float = 19.75  # ~7:45 PM (full night)

const CARDINALS_16: Array[String] = [
	"N",
	"NNE",
	"NE",
	"ENE",
	"E",
	"ESE",
	"SE",
	"SSE",
	"S",
	"SSW",
	"SW",
	"WSW",
	"W",
	"WNW",
	"NW",
	"NNW"
]

## Base prevailing wind angle (in radians). Default ~12° (0.209 rad, blowing eastward along the stroad corridor).
@export var base_wind_angle: float = 0.20944

## Base wind speed (intensity multiplier, nominally 1.0).
@export var base_wind_speed: float = 1.0

## Speed multiplier for wind changes over time.
@export var wind_variation_speed: float = 1.0

## Real-world seconds per game day (3:30 PM to 9:00 PM = 5.5 hours = 330 minutes).
## At 330.0s, 1 real second = 1 game minute.
@export var day_duration_seconds: float = 330.0

## Multiplier for time progression (1.0 = normal, 0.0 = paused).
@export var time_scale: float = 1.0

## Whether the day loops back to 3:30 PM when 9:00 PM is reached.
@export var loop_day: bool = true

## Initial time of day setting.
@export var initial_time_of_day: TimeOfDay = TimeOfDay.DAY

## Current time of day in decimal hours (15.5 = 3:30 PM, 21.0 = 9:00 PM).
static var current_time_hours: float = 15.5

## Current in-game day index (1, 2, ...).
static var current_day: int = 1

## Whether automatic time progression is paused.
static var time_paused: bool = false

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
		set_time_hours(20.25)
	elif "--evening-mode" in user_args or "--sunset-mode" in user_args:
		set_time_hours(18.5)
	else:
		match initial_time_of_day:
			TimeOfDay.DAY:
				set_time_hours(START_HOUR)
			TimeOfDay.EVENING:
				set_time_hours(18.5)
			TimeOfDay.NIGHT:
				set_time_hours(20.25)
	if time_of_day != TimeOfDay.DAY and instance:
		instance.time_of_day_changed.emit(time_of_day)
	if instance:
		instance.time_changed.emit(current_time_hours, get_time_string())


func _process(delta: float) -> void:
	if not _manual_override:
		_time += delta * wind_variation_speed
		_update_wind_calculation(base_wind_angle, base_wind_speed)
		if instance:
			instance.wind_changed.emit(wind_direction, wind_speed)

	if not time_paused and day_duration_seconds > 0.0:
		var total_day_hours := END_HOUR - START_HOUR
		var hours_per_sec := (total_day_hours / day_duration_seconds) * time_scale
		advance_time(delta * hours_per_sec)


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
	return current_time_hours >= DUSK_HOUR or time_of_day != TimeOfDay.DAY


## Returns the 12-hour formatted time string, e.g. "3:30 PM".
static func get_time_string() -> String:
	var total_minutes := int(round(current_time_hours * 60.0))
	var hour_24 := int(float(total_minutes) / 60.0) % 24
	var minute := total_minutes % 60
	var is_pm := hour_24 >= 12
	var hour_12 := hour_24 % 12
	if hour_12 == 0:
		hour_12 = 12
	var am_pm := "PM" if is_pm else "AM"
	return "%d:%02d %s" % [hour_12, minute, am_pm]


## Returns a descriptive name for the current period of the day.
static func get_period_name() -> String:
	if current_time_hours < 17.5:
		return "AFTERNOON"
	elif current_time_hours < 18.5:
		return "GOLDEN HOUR"
	elif current_time_hours < 19.5:
		return "SUNSET"
	elif current_time_hours < 20.25:
		return "TWILIGHT"
	else:
		return "NIGHT"


## Returns the 16-point cardinal direction name for a 3D horizontal direction vector.
## In world space: -Z is North, +Z is South, +X is East, -X is West.
static func get_cardinal_direction_name(dir: Vector3) -> String:
	var angle_rad := atan2(dir.x, -dir.z)
	var deg := fposmod(rad_to_deg(angle_rad), 360.0)
	var idx := int(round(deg / 22.5)) % 16
	return CARDINALS_16[idx]


## Advances the game time by a given number of hours.
static func advance_time(hours_delta: float) -> void:
	current_time_hours += hours_delta
	if current_time_hours >= END_HOUR:
		if instance and instance.loop_day:
			current_time_hours = (
				START_HOUR + fmod(current_time_hours - START_HOUR, END_HOUR - START_HOUR)
			)
			current_day += 1
			if instance:
				instance.day_advanced.emit(current_day)
		else:
			current_time_hours = END_HOUR
	_sync_time_mode()
	if instance:
		instance.time_changed.emit(current_time_hours, get_time_string())


## Explicitly set the current time in decimal hours (15.5 to 21.0).
static func set_time_hours(hours: float) -> void:
	current_time_hours = clampf(hours, START_HOUR, END_HOUR)
	_sync_time_mode()
	if instance:
		instance.time_changed.emit(current_time_hours, get_time_string())


static func _sync_time_mode() -> void:
	var new_mode: TimeOfDay
	if current_time_hours < DUSK_HOUR:
		new_mode = TimeOfDay.DAY
	elif current_time_hours < NIGHT_HOUR:
		new_mode = TimeOfDay.EVENING
	else:
		new_mode = TimeOfDay.NIGHT
	if new_mode != time_of_day:
		time_of_day = new_mode
		if instance:
			instance.time_of_day_changed.emit(time_of_day)


## Explicitly set the time of day mode.
static func set_time_of_day(mode: TimeOfDay) -> void:
	match mode:
		TimeOfDay.DAY:
			set_time_hours(START_HOUR)
		TimeOfDay.EVENING:
			set_time_hours(18.5)
		TimeOfDay.NIGHT:
			set_time_hours(20.25)


## Cycles time of day (DAY -> EVENING -> NIGHT -> DAY) and returns the new state.
static func cycle_time_of_day() -> TimeOfDay:
	match time_of_day:
		TimeOfDay.DAY:
			set_time_hours(18.5)
		TimeOfDay.EVENING:
			set_time_hours(20.25)
		TimeOfDay.NIGHT:
			set_time_hours(START_HOUR)
	return time_of_day


## Explicitly set night mode on or off.
static func set_night_mode(enabled: bool) -> void:
	set_time_of_day(TimeOfDay.NIGHT if enabled else TimeOfDay.DAY)


## Toggles night mode / cycles time of day and returns the new state.
static func toggle_night_mode() -> bool:
	cycle_time_of_day()
	return are_lights_on()
