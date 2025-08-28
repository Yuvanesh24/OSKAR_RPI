extends Control

@onready var pipe_scene = preload("res://Games/flappy_bird/flappy_scenes/pipe.tscn")
@onready var timer = $PipeTimer
@onready var player = $pilot
@onready var score_label: Label = $ScoreBoard/Score
@onready var heart_array = [$Health/heart1, $Health/heart2, $Health/heart3]
@onready var health = 2
@onready var game_over_scene: CanvasLayer = $GameOver
@onready var game_log_file
@onready var log_timer := Timer.new()
@onready var timer_panel = $CanvasLayer/TimerSelectorPanel
@onready var countdown_display = $CanvasLayer/CountdownTimer/CountdownLabel
@onready var play_button = $CanvasLayer/TimerSelectorPanel/VBoxContainer/HBoxContainer/PlayButton
@onready var close_button = $CanvasLayer/TimerSelectorPanel/VBoxContainer/HBoxContainer/CloseButton
@onready var countdown_timer = $CanvasLayer/CountdownTimer
@onready var game_over_label = $CanvasLayer/GameOverLabel
@onready var add_one_btn = $CanvasLayer/TimerSelectorPanel/HBoxContainer/AddOneButton
@onready var add_five_btn = $CanvasLayer/TimerSelectorPanel/HBoxContainer/AddFiveButton
@onready var sub_one_btn = $CanvasLayer/TimerSelectorPanel/HBoxContainer2/SubOneButton
@onready var sub_five_btn = $CanvasLayer/TimerSelectorPanel/HBoxContainer2/SubFiveButton
@onready var logout_button = $CanvasLayer/GameOverLabel/LogoutButton
@onready var retry_button = $CanvasLayer/GameOverLabel/RetryButton
@onready var time_label := $CanvasLayer/TimeSelector
@onready var pause_button = $CanvasLayer/PauseButton
@onready var top_score_label = $CanvasLayer/TextureRect/TopScoreLabel

#TODO: Packed scene if possible

signal game_over_signal
signal flash_animation
signal plane_crashed
signal game_started

const SCROLL_SPEED : float = 7
const PIPE_DELAY : int = 50
const PIPE_RANGE : int = 180
const TIMER_DELAY: int = 2

var game_running : bool = false
var game_over : bool
var scroll
var score
var screen_size : Vector2i
var ground_height : int
var pipes : Array
var countdown_time = 0
var countdown_active = false
var current_time := 0
var is_paused = false
var pause_state = 1
var pos_x : float
var pos_y : float
var pos_z : float
var target_x : float
var target_y : float
var target_z : float
var total_time = GlobalTimer.get_time() 
var pilot_node : CharacterBody2D
var game_x : float
var game_y = 0.0
var game_z : float
var status = ""
var error_status = "null"
var packets = "null"




func _ready() -> void:
    game_running = false
    score = 0
    scroll = 0
    screen_size = get_window().size
    ground_height = $ground.get_node("Sprite2D").texture.get_height()
    $ground.position.x = screen_size.x /2
    timer.wait_time = TIMER_DELAY/0.5
    log_timer.wait_time = 0.02 
    log_timer.autostart = true 
    add_child(log_timer)
    timer_panel.visible = true
    time_label.visible = true
    game_over_label.visible = false
    play_button.pressed.connect(_on_play_pressed)
    countdown_timer.timeout.connect(_on_CountdownTimer_timeout)
    close_button.pressed.connect(_on_close_pressed)
    add_one_btn.pressed.connect(_on_add_one_pressed)
    add_five_btn.pressed.connect(_on_add_five_pressed)
    sub_one_btn.pressed.connect(_on_sub_one_pressed)
    sub_five_btn.pressed.connect(_on_sub_five_pressed)
    logout_button.pressed.connect(_on_logout_button_pressed)
    retry_button.pressed.connect(_on_retry_button_pressed)
    pause_button.pressed.connect(_on_PauseButton_pressed)
    game_over_scene.restart_games.connect(restart_game)
    game_over_label.hide()
    GlobalScript.start_new_session_if_needed()
    pilot_node = $pilot
    var top_score = ScoreManager.get_top_score(GlobalSignals.current_patient_id, "FlyThrough")
    top_score_label.text = str(top_score)
    GlobalScript.start_new_session_if_needed()
    
    
    
func update_label():
    time_label.text = str(current_time) + " sec"
    var minutes = countdown_time / 60
    var seconds = countdown_time % 60
    time_label.text = "%2d m" % [minutes]

func _on_add_one_pressed():
    if countdown_time + 60 <= 2700:
        countdown_time += 60
    else:
        countdown_time = 2700
    _update_time_display()
    countdown_display.visible = true
    update_label()
    
func _on_add_five_pressed():
    if countdown_time + 300 <= 2700:
        countdown_time += 300
    else:
        countdown_time = 2700
    _update_time_display()
    countdown_display.visible = true
    update_label()

func _on_sub_one_pressed():
    if countdown_time >= 60:
        countdown_time -= 60
    else:
        countdown_time = 0
    _update_time_display()
    update_label()

func _on_sub_five_pressed():
    if countdown_time >= 300:
        countdown_time -= 300
    else:
        countdown_time = 0
    _update_time_display()
    update_label()
    

func _on_play_pressed():
    game_running = true
    GlobalTimer.start_timer()
    print("play button is pressed, countdown_time:", countdown_time)
    timer_panel.visible = false
    add_one_btn.hide()
    add_five_btn.hide()
    sub_one_btn.hide()
    sub_five_btn.hide()
    time_label.hide()
    start_game_with_timer()
    log_timer.timeout.connect(_on_log_timer_timeout)
    game_log_file = Manager.create_game_log_file('FlyThrough', GlobalSignals.current_patient_id)
    game_log_file.store_csv_line(PackedStringArray(['epochtime','score','status','error_status','packets','device_x', 'device_y','device_z', 'target_x','target_y','target_z','player_x','player_y','player_z','pause_state']))

func _on_close_pressed():
    game_running = true
    timer_panel.visible = false
    add_one_btn.hide()
    add_five_btn.hide()
    sub_one_btn.hide()
    sub_five_btn.hide()
    time_label.hide()
    countdown_display.hide()
    start_game_without_timer()
    log_timer.timeout.connect(_on_log_timer_timeout)
    game_log_file = Manager.create_game_log_file('FlyThrough', GlobalSignals.current_patient_id)
    game_log_file.store_csv_line(PackedStringArray(['epochtime','score','status','error_status','packets','device_x', 'device_y','device_z', 'target_x','target_y','target_z','player_x','player_y','player_z','pause_state']))
    
    
func _on_PauseButton_pressed():
    if is_paused:
        GlobalTimer.resume_timer()
        countdown_timer.start()
        game_running = true
        pause_button.text = "Pause"
        pause_state = 1
    else:
        GlobalTimer.pause_timer()
        countdown_timer.stop()
        game_running = false
        pause_button.text = "Resume"
        pause_state = 0
    is_paused = !is_paused


func start_game_with_timer():
    countdown_active = true
    countdown_timer.wait_time = 1.0 
    countdown_timer.start()
    _update_time_display()
    game_running = true
    
func start_game_without_timer():
    countdown_active = false
    GlobalTimer.start_timer()
    game_running = true

func _on_CountdownTimer_timeout():
    if countdown_active:
        countdown_time -= 1
        countdown_display.text = "%02d:%02d" % [countdown_time / 60, countdown_time % 60]
        _update_time_display()
        if countdown_time <= 0:
            countdown_active = false
            countdown_timer.stop()
            show_game_over()

func _update_time_display():
    var minutes = countdown_time / 60
    var seconds = countdown_time % 60
    countdown_display.text = "Time left: %02d:%02d" % [minutes, seconds]
    
func show_game_over():
    print("Game Over!")
    game_running = false
    save_final_score_to_log(GlobalScript.current_score)
    GlobalTimer.stop_timer()
    game_over_label.visible = true
    
    
func _on_logout_button_pressed():
    get_tree().paused = false
    get_tree().change_scene_to_file("res://Main_screen/select_game.tscn")

func _on_retry_button_pressed():
    get_tree().paused = false
    game_over_label.hide()
    timer_panel.show()
    add_one_btn.show()
    add_five_btn.show()
    sub_one_btn.show()
    sub_five_btn.show()

func _process(delta: float) -> void:
    
    if game_running:
        if status != "collided" and status != "reached" and status != "restarting":
            status = "moving"
        if pilot_node:
            if not pilot_node.adapt_toggle:
                game_x = (pilot_node.position.x - GlobalScript.X_SCREEN_OFFSET) / GlobalScript.PLAYER_POS_SCALER_X
                game_z = (pilot_node.position.y - GlobalScript.Y_SCREEN_OFFSET) / GlobalScript.PLAYER_POS_SCALER_Y
            else:
                game_x  = (pilot_node.position.x - GlobalScript.X_SCREEN_OFFSET) / (GlobalScript.PLAYER_POS_SCALER_X * GlobalSignals.global_scalar_x)
                game_z = (pilot_node.position.y - GlobalScript.Y_SCREEN_OFFSET) / (GlobalScript.PLAYER_POS_SCALER_Y * GlobalSignals.global_scalar_y)
            
        scroll += SCROLL_SPEED
        pos_x = GlobalScript.raw_x
        pos_y = GlobalScript.raw_y
        pos_z = GlobalScript.raw_z
        if scroll >= screen_size.x/5:
            scroll = 0
        $ground.position.x = -scroll
        for pipe in pipes:
            pipe.position.x -= SCROLL_SPEED
            
    
func stop_game():
    timer.stop()
    $GameOver.show()
    game_running = false
    game_over = true

func _on_pipe_timer_timeout() -> void:
    if game_running:
        generate_pipe()

func generate_pipe():
    if game_running:
    
        var pipe = pipe_scene.instantiate()
        pipe.position.x = screen_size.x / 1.5 + PIPE_DELAY
        pipe.position.y = 400 + randi_range(-PIPE_RANGE, PIPE_RANGE)
        target_x = (pipe.position.x - GlobalScript.X_SCREEN_OFFSET)  / GlobalScript.PLAYER_POS_SCALER_X
        target_y = (pipe.position.y - GlobalScript.Y_SCREEN_OFFSET)  / (GlobalScript.PLAYER_POS_SCALER_Y)
        target_z = 0
        pipe.hit.connect(pipe_hit)
        pipe.scored.connect(scored)
        add_child(pipe)
        pipes.append(pipe)

func restart_game():
    game_running = true
    game_over = false
    timer.start()
    for _h in heart_array:
        _h.animation = "default"
    game_started.emit()
    score = 0
    health = 2
    
func pipe_hit():
    if not health == 0 and health > -1:
        heart_array[health].animation = "Dead"
        flash_animation.emit()
    if health == 0:
        
        heart_array[health].animation = "Dead"
        game_over_signal.emit()
        status = "restarting"
        plane_crashed.emit()
        stop_game()
    else:
        status = "collided"
    health -=1

func scored():
    score+= 1
    ScoreManager.update_top_score(GlobalSignals.current_patient_id, "FlyThrough", score)
    var top_score = ScoreManager.get_top_score(GlobalSignals.current_patient_id, "FlyThrough")
    top_score_label.text = str(top_score)
    status = "reached"
    score_label.text = str(score)

func _on_logout_pressed() -> void:
    get_tree().change_scene_to_file("res://Main_screen/select_game.tscn")
    GlobalTimer.stop_timer()

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST:
        game_log_file.close()

func save_final_score_to_log(score: int):
    if game_log_file:
        game_log_file.store_line("Final Score: " + str(score))
        game_log_file.flush()
        
        
func _on_log_timer_timeout():
    if game_log_file:
        game_log_file.store_csv_line(PackedStringArray([Time.get_unix_time_from_system(),score,status,error_status,packets,str(pos_x), str(pos_y), str(pos_z), str(target_x), str(target_y), str(target_z),str(game_x),str(game_y),str(game_z),str(pause_state)]))
