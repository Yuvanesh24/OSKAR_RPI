extends Control

# Constants
const SCROLL_SPEED: float = 7.0
const PIPE_DELAY: int = 50
const PIPE_RANGE: int = 180
const TIMER_DELAY: int = 2
const LOG_INTERVAL: float = 0.02
const MAX_COUNTDOWN_TIME: int = 2700
const ONE_MINUTE: int = 60
const FIVE_MINUTES: int = 300
const INITIAL_HEALTH: int = 3  # Changed to 3 to match heart array
const GAME_NAME: String = "FlyThrough"

# Signals
signal game_over_signal
signal flash_animation
signal plane_crashed
signal game_started


# Preloaded resources
@onready var pipe_scene = preload("res://Games/flappy_bird/Scenes/pipe.tscn")

# Node references - organized by functionality
@onready var _timer_nodes = {
    "pipe_timer": $PipeTimer,
    "countdown_timer": $CanvasLayer/CountdownTimer,
    "log_timer": Timer.new()
}

@onready var _player_nodes = {
    "pilot": $pilot
}

@onready var _ui_nodes = {
    "score_label": $Score,
    "countdown_display": $CanvasLayer/CountdownTimer/CountdownLabel,
    "game_over_label": $CanvasLayer/GameOverLabel,
    "time_label": $CanvasLayer/TimerSelectorPanel/TimeSelector,
    "top_score_label": $CanvasLayer/TextureRect/TopScoreLabel,
    "mode_selection": $ModeSelection,
    "warning_window":$Window
}

@onready var _panel_nodes = {
    "timer_panel": $CanvasLayer/TimerSelectorPanel,
    "game_over_scene": $GameOver,
    "pause_button": $CanvasLayer/PauseButton
}

@onready var _button_nodes = {
    "play_button": $CanvasLayer/TimerSelectorPanel/VBoxContainer/HBoxContainer/PlayButton,
    "close_button": $CanvasLayer/TimerSelectorPanel/VBoxContainer/HBoxContainer/CloseButton,
    "add_one_btn": $CanvasLayer/TimerSelectorPanel/HBoxContainer/AddOneButton,
    "add_five_btn": $CanvasLayer/TimerSelectorPanel/HBoxContainer/AddFiveButton,
    "sub_one_btn": $CanvasLayer/TimerSelectorPanel/HBoxContainer2/SubOneButton,
    "sub_five_btn": $CanvasLayer/TimerSelectorPanel/HBoxContainer2/SubFiveButton,
    "logout_button": $CanvasLayer/GameOverLabel/LogoutButton,
    "retry_button": $CanvasLayer/GameOverLabel/RetryButton,
    "2d_mode": $"ModeSelection/2D_mode",
    "3d_mode": $"ModeSelection/3D_mode",
    "do_assess":$Window/HBoxContainer/do_asses,
    "close_assess":$Window/HBoxContainer/close_asses,
    "adapt_prom":$AdaptRom
        
}

@onready var _health_nodes = {
    "heart_array": [$Health/heart1, $Health/heart2, $Health/heart3],
    "ground": $ground
}

# Game state variables
var game_running: bool = false
var game_over: bool = false
var scroll: float = 0.0
var score: int = 0
var screen_size: Vector2i
var ground_height: int
var pipes: Array = []
var health: int = INITIAL_HEALTH

# Timer and countdown variables
var countdown_time: int = 0
var countdown_active: bool = false
var current_time: int = 0
var is_paused: bool = false
var is_3d_mode := false
var pause_state: int = 1

# Position tracking variables
var pos_x: float
var pos_y: float
var pos_z: float
var target_x: float
var target_y: float
var target_z: float
var game_x: float
var game_y: float = 0.0
var game_z: float

# Game logging variables
var status: String = "idle"
var error_status: String = "null"
var packets: String = "null"
var game_log_file
var pilot_node: CharacterBody2D

func _ready() -> void:
    _initialize_game_state()
    _setup_screen_and_ground()
    _setup_timers()
    _setup_ui()
    _connect_signals()
    _setup_logging()
    _initialize_scoring()

func _initialize_game_state() -> void:
    game_running = false
    game_over = false
    score = 0
    scroll = 0.0
    health = INITIAL_HEALTH
    pilot_node = _player_nodes.pilot
    _initialize_health_display()

func _initialize_health_display() -> void:
    """Initialize all hearts to show full health"""
    for i in range(_health_nodes.heart_array.size()):
        if _health_nodes.heart_array[i] != null:
            _health_nodes.heart_array[i].animation = "default"
            _health_nodes.heart_array[i].visible = true

func _setup_screen_and_ground() -> void:
    screen_size = get_window().size
    ground_height = _health_nodes.ground.get_node("Sprite2D").texture.get_height()
    _health_nodes.ground.position.x = screen_size.x / 2

func _setup_timers() -> void:
    _timer_nodes.pipe_timer.wait_time = TIMER_DELAY / 0.5
    _timer_nodes.log_timer.wait_time = LOG_INTERVAL
    _timer_nodes.log_timer.autostart = true
    add_child(_timer_nodes.log_timer)

func _setup_ui() -> void:
    _panel_nodes.timer_panel.visible = true
    _ui_nodes.time_label.visible = true
    _ui_nodes.game_over_label.visible = false
    _ui_nodes.game_over_label.hide()
    _update_top_score_display()

func _connect_signals() -> void:
    # Button connections
    _button_nodes.play_button.pressed.connect(_on_play_pressed)
    _button_nodes.close_button.pressed.connect(_on_close_pressed)
    _button_nodes.add_one_btn.pressed.connect(_on_add_one_pressed)
    _button_nodes.add_five_btn.pressed.connect(_on_add_five_pressed)
    _button_nodes.sub_one_btn.pressed.connect(_on_sub_one_pressed)
    _button_nodes.sub_five_btn.pressed.connect(_on_sub_five_pressed)
    _button_nodes.logout_button.pressed.connect(_on_logout_button_pressed)
    _button_nodes.retry_button.pressed.connect(_on_retry_button_pressed)
    _button_nodes["2d_mode"].pressed.connect(_on_2d_mode_pressed)
    _button_nodes["3d_mode"].pressed.connect(_on_3d_mode_pressed)
    _panel_nodes.pause_button.pressed.connect(_on_PauseButton_pressed)
    
    
    # Timer connections
    _timer_nodes.countdown_timer.timeout.connect(_on_CountdownTimer_timeout)
    _timer_nodes.pipe_timer.timeout.connect(_on_pipe_timer_timeout)
    
    # Game connections
    _panel_nodes.game_over_scene.restart_games.connect(restart_game)

func _setup_logging() -> void:
    GlobalScript.start_new_session_if_needed()

func _initialize_scoring() -> void:
    _update_top_score_display()

func _update_top_score_display() -> void:
    var top_score = ScoreManager.get_top_score(GlobalSignals.current_patient_id, GAME_NAME)
    _ui_nodes.top_score_label.text = str(top_score)

func update_label() -> void:
    _ui_nodes.time_label.text = str(current_time) + " sec"
    var minutes = countdown_time / 60
    _ui_nodes.time_label.text = "%2d m" % [minutes]

func _modify_countdown_time(amount: int) -> void:
    countdown_time = clamp(countdown_time + amount, 0, MAX_COUNTDOWN_TIME)
    _update_time_display()
    _ui_nodes.countdown_display.visible = true
    update_label()

func _on_add_one_pressed() -> void:
    _modify_countdown_time(ONE_MINUTE)

func _on_add_five_pressed() -> void:
    _modify_countdown_time(FIVE_MINUTES)

func _on_sub_one_pressed() -> void:
    _modify_countdown_time(-ONE_MINUTE)

func _on_sub_five_pressed() -> void:
    _modify_countdown_time(-FIVE_MINUTES)

func _on_play_pressed() -> void:
    game_running = false
    GlobalTimer.start_timer()
    print("play button is pressed, countdown_time:", countdown_time)
    _hide_timer_ui()
    start_game_with_timer()
    _setup_game_logging()

func _on_close_pressed() -> void:
    game_running = false
    _hide_timer_ui()
    _ui_nodes.countdown_display.hide()
    start_game_without_timer()
    _setup_game_logging()

func _hide_timer_ui() -> void:
    _panel_nodes.timer_panel.visible = false
    _ui_nodes.time_label.hide()
    for button_name in ["add_one_btn", "add_five_btn", "sub_one_btn", "sub_five_btn"]:
        _button_nodes[button_name].hide()

func _show_timer_ui() -> void:
    _panel_nodes.timer_panel.show()
    for button_name in ["add_one_btn", "add_five_btn", "sub_one_btn", "sub_five_btn"]:
        _button_nodes[button_name].show()

func _setup_game_logging() -> void:
    _timer_nodes.log_timer.timeout.connect(_on_log_timer_timeout)
    game_log_file = Manager.create_game_log_file(GAME_NAME, GlobalSignals.current_patient_id)
    game_log_file.store_csv_line(PackedStringArray([
        'epochtime', 'score', 'status', 'error_status', 'packets',
        'device_x', 'device_y', 'device_z', 'target_x', 'target_y', 'target_z',
        'player_x', 'player_y', 'player_z', 'pause_state'
    ]))

func _on_PauseButton_pressed() -> void:
    if is_paused:
        _resume_game()
    else:
        _pause_game()
    is_paused = !is_paused

func _pause_game() -> void:
    GlobalTimer.pause_timer()
    _timer_nodes.countdown_timer.stop()
    game_running = false
    _panel_nodes.pause_button.text = "Resume"
    pause_state = 0

func _resume_game() -> void:
    GlobalTimer.resume_timer()
    _timer_nodes.countdown_timer.start()
    game_running = true
    _panel_nodes.pause_button.text = "Pause"
    pause_state = 1

func start_game_with_timer() -> void:
    countdown_active = true
    _timer_nodes.countdown_timer.wait_time = 1.0
    _timer_nodes.countdown_timer.start()
    _update_time_display()
    game_running = false
    
func start_game_without_timer() -> void:
    countdown_active = false
    GlobalTimer.start_timer()
    game_running = false

func _on_CountdownTimer_timeout() -> void:
    if countdown_active:
        countdown_time -= 1
        _ui_nodes.countdown_display.text = "%02d:%02d" % [countdown_time / 60, countdown_time % 60]
        _update_time_display()
        if countdown_time <= 0:
            countdown_active = false
            _timer_nodes.countdown_timer.stop()
            show_game_over()

func _update_time_display() -> void:
    var minutes = countdown_time / 60
    var seconds = countdown_time % 60
    _ui_nodes.countdown_display.text = "Time left: %02d:%02d" % [minutes, seconds]
    
func show_game_over() -> void:
    print("Game Over!")
    game_running = false
    save_final_score_to_log(GlobalScript.current_score)
    GlobalTimer.stop_timer()
    _ui_nodes.game_over_label.visible = true
    
func _on_logout_button_pressed() -> void:
    get_tree().paused = false
    get_tree().change_scene_to_file("res://Main_screen/Scenes/select_game.tscn")

func _on_retry_button_pressed() -> void:
    get_tree().paused = false
    _ui_nodes.game_over_label.hide()
    _show_timer_ui()

func _process(delta: float) -> void:
    if not game_running:
        return
    
    _update_game_status()
    _update_player_position()
    _update_scroll_and_pipes()
    _update_position_tracking()

func _update_game_status() -> void:
    if status not in ["collided", "reached", "restarting"]:
        status = "moving"

func _update_player_position() -> void:
    if pilot_node:
        if not pilot_node.adapt_toggle:
            game_x = (pilot_node.position.x - GlobalScript.X_SCREEN_OFFSET) / GlobalScript.PLAYER_POS_SCALER_X
            game_z = (pilot_node.position.y - GlobalScript.Y_SCREEN_OFFSET) / GlobalScript.PLAYER_POS_SCALER_Z
        else:
            game_x = (pilot_node.position.x - GlobalScript.X_SCREEN_OFFSET) / (GlobalScript.PLAYER_POS_SCALER_X * GlobalSignals.global_scalar_x)
            game_z = (pilot_node.position.y - GlobalScript.Y_SCREEN_OFFSET) / (GlobalScript.PLAYER_POS_SCALER_Z * GlobalSignals.global_scalar_y)

func _update_scroll_and_pipes() -> void:
    scroll += SCROLL_SPEED
    if scroll >= screen_size.x / 5:
        scroll = 0
    
    _health_nodes.ground.position.x = -scroll
    
    for pipe in pipes:
        pipe.position.x -= SCROLL_SPEED

func _update_position_tracking() -> void:
    pos_x = GlobalScript.raw_x
    pos_y = GlobalScript.raw_y
    pos_z = GlobalScript.raw_z

func stop_game() -> void:
    _timer_nodes.pipe_timer.stop()
    _panel_nodes.game_over_scene.show()
    game_running = false
    game_over = true

func _on_pipe_timer_timeout() -> void:
    if game_running:
        generate_pipe()

func generate_pipe() -> void:
    if not game_running:
        return
    
    var pipe = pipe_scene.instantiate()
    _setup_pipe_position(pipe)
    _setup_pipe_signals(pipe)
    add_child(pipe)
    pipes.append(pipe)

func _setup_pipe_position(pipe: Node) -> void:
    pipe.position.x = screen_size.x / 1.5 + PIPE_DELAY
    pipe.position.y = 400 + randi_range(-PIPE_RANGE, PIPE_RANGE)
    
    target_x = (pipe.position.x - GlobalScript.X_SCREEN_OFFSET) / GlobalScript.PLAYER_POS_SCALER_X
    target_y = (pipe.position.y - GlobalScript.Y_SCREEN_OFFSET) / GlobalScript.PLAYER_POS_SCALER_Z
    target_z = 0

func _setup_pipe_signals(pipe: Node) -> void:
    pipe.hit.connect(pipe_hit)
    pipe.scored.connect(scored)

func restart_game() -> void:
    game_running = true
    game_over = false
    score = 0
    health = INITIAL_HEALTH
    _reset_health_display()
    _timer_nodes.pipe_timer.start()
    game_started.emit()
    _ui_nodes.score_label.text = str(score)

func _reset_health_display() -> void:
    """Reset all hearts to show full health"""
    for i in range(_health_nodes.heart_array.size()):
        if _health_nodes.heart_array[i] != null:
            _health_nodes.heart_array[i].animation = "default"
            _health_nodes.heart_array[i].visible = true

func _update_health_display() -> void:
    """Update the visual representation of health"""
    for i in range(_health_nodes.heart_array.size()):
        if _health_nodes.heart_array[i] != null:
            if i < health:
                # Show healthy heart
                _health_nodes.heart_array[i].animation = "default"
                _health_nodes.heart_array[i].visible = true
            else:
                # Show dead heart
                _health_nodes.heart_array[i].animation = "Dead"
                _health_nodes.heart_array[i].visible = true

func pipe_hit() -> void:
    if health > 0:
        health -= 1
        _update_health_display()
        flash_animation.emit()
        
        if health <= 0:
            _handle_game_over()
        else:
            status = "collided"

func _handle_game_over() -> void:
    game_over_signal.emit()
    status = "restarting"
    plane_crashed.emit()
    stop_game()

func scored() -> void:
    score += 1
    ScoreManager.update_top_score(GlobalSignals.current_patient_id, GAME_NAME, score)
    _update_top_score_display()
    status = "reached"
    _ui_nodes.score_label.text = str(score)

func _on_logout_pressed() -> void:
    get_tree().change_scene_to_file("res://Main_screen/Scenes/select_game.tscn")
    GlobalTimer.stop_timer()

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST:
        if game_log_file:
            game_log_file.close()

func save_final_score_to_log(score: int) -> void:
    if game_log_file:
        game_log_file.store_line("Final Score: " + str(score))
        game_log_file.flush()

func _on_log_timer_timeout() -> void:
    if game_log_file:
        game_log_file.store_csv_line(PackedStringArray([
            Time.get_unix_time_from_system(), score, status, error_status, packets,
            str(pos_x), str(pos_y), str(pos_z), str(target_x), str(target_y), str(target_z),
            str(game_x), str(game_y), str(game_z), str(pause_state)
        ]))


func _on_2d_mode_pressed() -> void:
    is_3d_mode = false
    game_running = true
    _ui_nodes.mode_selection.hide()
    print("2D pressed")


func _on_3d_mode_pressed() -> void:
    is_3d_mode = true
    game_running = true
    _ui_nodes.mode_selection.hide()
    print("3d pressed")
    


func _on_do_asses_pressed() -> void:
    get_tree().change_scene_to_file("res://Games/assessment/workspace.tscn")


func _on_close_asses_pressed() -> void:
    _ui_nodes.warning_window.visible = false
