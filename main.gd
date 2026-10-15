extends Node2D

const SPEED := 400.0
const PLAYER_RADIUS := 25.0
const ENEMY_RADIUS := 30.0

var player: AnimatedSprite2D
var screen_size: Vector2
var enemies: Array[AnimatedSprite2D] = []
var score := 0
var playing := false

var score_label: Label
var message_label: Label
var spawn_timer: Timer
var score_timer: Timer
var music: AudioStreamPlayer
var death_sound: AudioStreamPlayer


func _ready() -> void:
	randomize()
	screen_size = get_viewport_rect().size

	# Background
	var bg := ColorRect.new()
	bg.color = Color(0.22, 0.37, 0.45)
	bg.size = screen_size
	add_child(bg)

	# Player, with animations built in code
	var frames := SpriteFrames.new()
	frames.add_animation("walk")
	frames.set_animation_speed("walk", 5)
	frames.add_frame("walk", load("res://art/playerGrey_walk1.png"))
	frames.add_frame("walk", load("res://art/playerGrey_walk2.png"))
	frames.add_animation("up")
	frames.set_animation_speed("up", 5)
	frames.add_frame("up", load("res://art/playerGrey_up1.png"))
	frames.add_frame("up", load("res://art/playerGrey_up2.png"))

	player = AnimatedSprite2D.new()
	player.sprite_frames = frames
	player.animation = "walk"
	player.scale = Vector2(0.5, 0.5)
	player.hide()
	add_child(player)

	# Timers
	spawn_timer = Timer.new()
	spawn_timer.wait_time = 0.5
	spawn_timer.timeout.connect(_spawn_enemy)
	add_child(spawn_timer)

	score_timer = Timer.new()
	score_timer.wait_time = 1.0
	score_timer.timeout.connect(_on_score_tick)
	add_child(score_timer)

	# Sounds
	music = AudioStreamPlayer.new()
	var music_stream = load("res://art/House In a Forest Loop.ogg")
	music_stream.loop = true
	music.stream = music_stream
	add_child(music)

	death_sound = AudioStreamPlayer.new()
	death_sound.stream = load("res://art/gameover.wav")
	add_child(death_sound)

	# Labels (added last so they draw on top)
	score_label = Label.new()
	score_label.position = Vector2(20, 10)
	score_label.add_theme_font_size_override("font_size", 48)
	add_child(score_label)

	message_label = Label.new()
	message_label.size = Vector2(screen_size.x, 200)
	message_label.position = Vector2(0, 250)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.add_theme_font_size_override("font_size", 40)
	message_label.text = "Dodge the Creeps!\n\nPress SPACE to start"
	add_child(message_label)


func _new_game() -> void:
	for e in enemies:
		e.queue_free()
	enemies.clear()

	score = 0
	score_label.text = "0"
	message_label.hide()

	player.position = Vector2(screen_size.x / 2, screen_size.y - 100)
	player.show()

	spawn_timer.wait_time = 0.5
	spawn_timer.start()
	score_timer.start()
	music.play()
	playing = true


func _game_over() -> void:
	playing = false
	spawn_timer.stop()
	score_timer.stop()
	music.stop()
	death_sound.play()
	player.hide()

	message_label.text = "Game Over\nScore: %d\n\nPress SPACE to retry" % score
	message_label.show()


func _on_score_tick() -> void:
	score += 1
	score_label.text = str(score)
	# Gets harder over time
	spawn_timer.wait_time = max(0.2, 0.5 - score * 0.01)


func _spawn_enemy() -> void:
	var kinds := [
		["enemyFlyingAlt_1", "enemyFlyingAlt_2"],
		["enemySwimming_1", "enemySwimming_2"],
		["enemyWalking_1", "enemyWalking_2"],
	]
	var kind: Array = kinds.pick_random()

	var f := SpriteFrames.new()
	f.set_animation_speed("default", 3)
	for name in kind:
		f.add_frame("default", load("res://art/%s.png" % name))

	var enemy := AnimatedSprite2D.new()
	enemy.sprite_frames = f
	enemy.scale = Vector2(0.75, 0.75)
	enemy.position = Vector2(randf_range(0, screen_size.x), -40)
	enemy.set_meta("vel", Vector2(randf_range(-80, 80), randf_range(150, 250)))
	enemy.play()
	add_child(enemy)
	enemies.append(enemy)


func _process(delta: float) -> void:
	if not playing:
		if Input.is_action_just_pressed("ui_accept"):
			_new_game()
		return

	# Move the player
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if dir.length() > 0:
		player.play()
		if dir.x != 0:
			player.animation = "walk"
			player.flip_v = false
			player.flip_h = dir.x < 0
		elif dir.y != 0:
			player.animation = "up"
			player.flip_v = dir.y > 0
	else:
		player.stop()

	player.position += dir * SPEED * delta
	player.position = player.position.clamp(Vector2.ZERO, screen_size)

	# Move enemies, remove off-screen ones, check collisions
	for i in range(enemies.size() - 1, -1, -1):
		var e := enemies[i]
		e.position += e.get_meta("vel") * delta

		if e.position.y > screen_size.y + 60 or e.position.x < -100 or e.position.x > screen_size.x + 100:
			e.queue_free()
			enemies.remove_at(i)
		elif e.position.distance_to(player.position) < PLAYER_RADIUS + ENEMY_RADIUS:
			_game_over()
			return