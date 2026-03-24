extends GutTest
## Tests for PlayerAnimationPure — direction mapping, mirroring, and state transitions.


var anim: PlayerAnimationPure


func before_each() -> void:
	anim = PlayerAnimationPure.new()


# --- Direction mapping ---

func test_velocity_to_direction_right() -> void:
	var dir := PlayerAnimationPure._velocity_to_direction(Vector2(1, 0))
	assert_eq(dir, PlayerAnimationPure.Direction.E)


func test_velocity_to_direction_down() -> void:
	var dir := PlayerAnimationPure._velocity_to_direction(Vector2(0, 1))
	assert_eq(dir, PlayerAnimationPure.Direction.S)


func test_velocity_to_direction_up() -> void:
	var dir := PlayerAnimationPure._velocity_to_direction(Vector2(0, -1))
	assert_eq(dir, PlayerAnimationPure.Direction.N)


func test_velocity_to_direction_left() -> void:
	var dir := PlayerAnimationPure._velocity_to_direction(Vector2(-1, 0))
	assert_eq(dir, PlayerAnimationPure.Direction.W)


func test_velocity_to_direction_down_right() -> void:
	var dir := PlayerAnimationPure._velocity_to_direction(Vector2(1, 1))
	assert_eq(dir, PlayerAnimationPure.Direction.SE)


func test_velocity_to_direction_up_left() -> void:
	var dir := PlayerAnimationPure._velocity_to_direction(Vector2(-1, -1))
	assert_eq(dir, PlayerAnimationPure.Direction.NW)


func test_velocity_to_direction_down_left() -> void:
	var dir := PlayerAnimationPure._velocity_to_direction(Vector2(-1, 1))
	assert_eq(dir, PlayerAnimationPure.Direction.SW)


func test_velocity_to_direction_up_right() -> void:
	var dir := PlayerAnimationPure._velocity_to_direction(Vector2(1, -1))
	assert_eq(dir, PlayerAnimationPure.Direction.NE)


# --- Mirroring ---

func test_resolve_south_no_flip() -> void:
	var result := PlayerAnimationPure._resolve_direction(PlayerAnimationPure.Direction.S)
	assert_eq(result["name"], "s")
	assert_eq(result["flip"], false)


func test_resolve_east_no_flip() -> void:
	var result := PlayerAnimationPure._resolve_direction(PlayerAnimationPure.Direction.E)
	assert_eq(result["name"], "e")
	assert_eq(result["flip"], false)


func test_resolve_west_mirrors_east() -> void:
	var result := PlayerAnimationPure._resolve_direction(PlayerAnimationPure.Direction.W)
	assert_eq(result["name"], "e")
	assert_eq(result["flip"], true)


func test_resolve_southwest_mirrors_southeast() -> void:
	var result := PlayerAnimationPure._resolve_direction(PlayerAnimationPure.Direction.SW)
	assert_eq(result["name"], "se")
	assert_eq(result["flip"], true)


func test_resolve_northwest_mirrors_northeast() -> void:
	var result := PlayerAnimationPure._resolve_direction(PlayerAnimationPure.Direction.NW)
	assert_eq(result["name"], "ne")
	assert_eq(result["flip"], true)


# --- State transitions ---

func test_initial_state_is_idle() -> void:
	assert_eq(anim.state, PlayerAnimationPure.State.IDLE)


func test_moving_sets_running() -> void:
	anim.update(Vector2(2, 0))
	assert_eq(anim.state, PlayerAnimationPure.State.RUNNING)


func test_stopping_returns_to_idle() -> void:
	anim.update(Vector2(2, 0))
	assert_eq(anim.state, PlayerAnimationPure.State.RUNNING)
	anim.update(Vector2.ZERO)
	assert_eq(anim.state, PlayerAnimationPure.State.IDLE)


func test_kick_locks_state() -> void:
	anim.trigger_kick()
	assert_eq(anim.state, PlayerAnimationPure.State.KICKING)
	assert_true(anim.is_locked())
	# Moving doesn't override kick
	anim.update(Vector2(2, 0))
	assert_eq(anim.state, PlayerAnimationPure.State.KICKING)


func test_kick_expires_after_duration() -> void:
	anim.trigger_kick()
	for i in range(PlayerAnimationPure.KICK_DURATION):
		anim.update(Vector2.ZERO)
	assert_eq(anim.state, PlayerAnimationPure.State.IDLE)
	assert_false(anim.is_locked())


func test_slide_locks_state() -> void:
	anim.trigger_slide()
	assert_eq(anim.state, PlayerAnimationPure.State.SLIDING)
	assert_true(anim.is_locked())


func test_knockdown_transitions_to_getup() -> void:
	anim.trigger_knockdown()
	assert_eq(anim.state, PlayerAnimationPure.State.KNOCKED_DOWN)
	# Tick through knockdown duration
	for i in range(PlayerAnimationPure.KNOCKDOWN_DURATION):
		anim.update(Vector2.ZERO)
	assert_eq(anim.state, PlayerAnimationPure.State.GETTING_UP)


func test_getup_returns_to_idle() -> void:
	anim.trigger_knockdown()
	for i in range(PlayerAnimationPure.KNOCKDOWN_DURATION):
		anim.update(Vector2.ZERO)
	assert_eq(anim.state, PlayerAnimationPure.State.GETTING_UP)
	for i in range(PlayerAnimationPure.GETUP_DURATION):
		anim.update(Vector2.ZERO)
	assert_eq(anim.state, PlayerAnimationPure.State.IDLE)


# --- Animation result ---

func test_idle_south_animation_name() -> void:
	var result := anim.get_animation_result()
	assert_eq(result["animation"], "idle_s")
	assert_eq(result["flip_h"], false)


func test_running_east_animation_name() -> void:
	anim.update(Vector2(2, 0))
	var result := anim.get_animation_result()
	assert_eq(result["animation"], "run_e")
	assert_eq(result["flip_h"], false)


func test_running_west_mirrors_east() -> void:
	anim.update(Vector2(-2, 0))
	var result := anim.get_animation_result()
	assert_eq(result["animation"], "run_e")
	assert_eq(result["flip_h"], true)


func test_kick_south_animation() -> void:
	anim.direction = PlayerAnimationPure.Direction.S
	anim.trigger_kick()
	var result := anim.get_animation_result()
	assert_eq(result["animation"], "kick_s")


func test_celebrate_animation() -> void:
	anim.trigger_celebrate()
	var result := anim.get_animation_result()
	assert_eq(result["animation"], "celebrate")
	assert_eq(result["flip_h"], false)


func test_direction_preserved_when_stopping() -> void:
	# Move east, then stop — should idle facing east
	anim.update(Vector2(2, 0))
	anim.update(Vector2.ZERO)
	var result := anim.get_animation_result()
	assert_eq(result["animation"], "idle_e")
