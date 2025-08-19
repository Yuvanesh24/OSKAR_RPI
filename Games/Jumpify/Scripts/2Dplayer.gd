extends CharacterBody2D

# Movement configuration
@export var movement_smoothing: float = 1.0
@export var debug_mode = DebugSettings.debug_mode
@export var use_scaled_position: bool = false
@export var ground_level: float = 577

# Movement bounds
const MIN_BOUNDS = Vector2(44, 40)
const MAX_BOUNDS = Vector2(1105, 577)

# Movement variables
var network_position = Vector2.ZERO
var zero_offset = Vector2.ZERO
var previous_position = Vector2.ZERO
var last_movement_direction = 0  

# Node references
@onready var sprite = $Sprite2D
@onready var player_sprite = $AnimatedSprite2D
@onready var particle_trails = $ParticleTrails
@onready var button: Button = $"../UserInterface/GameUI/Button"

func _ready() -> void:
    network_position = Vector2.ZERO
    previous_position = position
    button.pressed.connect(_on_logout_button_pressed)
       
func _physics_process(_delta):
    _update_player_position()
    _update_animations()

func _update_player_position() -> void:
    # Store previous position for animation calculations
    previous_position = position
    
    # Get position from different sources based on mode
    if debug_mode:
        network_position = get_global_mouse_position()
    elif use_scaled_position:
        network_position = GlobalScript.scaled_network_position3D
    else:
        network_position = GlobalScript.network_position3D
    
    # Apply movement if we have valid network position
    if network_position != Vector2.ZERO:
        # Apply zero offset calibration
        network_position = network_position - zero_offset
        
        # Smooth movement to target position
        position = position.lerp(network_position, movement_smoothing)
        
        # Clamp position within bounds
        position.x = clamp(position.x, MIN_BOUNDS.x, MAX_BOUNDS.x)
        position.y = clamp(position.y, MIN_BOUNDS.y, MAX_BOUNDS.y)

func _update_animations():
    # Calculate movement based on position changes
    var position_diff = position - previous_position
    var is_moving = position_diff.length() > 2.0  # Increased threshold to prevent jittering
    
    # Only update direction if movement is significant enough
    if abs(position_diff.x) > 3.0:  # Only change direction for meaningful horizontal movement
        last_movement_direction = sign(position_diff.x)
    
    # Animation logic - check if player is above ground level
    if position.y < ground_level - 10:
        if player_sprite:
            player_sprite.play("Jump")
        if particle_trails:
            particle_trails.emitting = false
    elif is_moving:
        if player_sprite:
            player_sprite.play("Walk")
        if particle_trails:
            particle_trails.emitting = true
    else:
        if player_sprite:
            player_sprite.play("Idle")
        if particle_trails:
            particle_trails.emitting = false
    
    # Flip sprite based on last significant movement direction (prevents constant flipping)
    if abs(last_movement_direction) > 0 and player_sprite:
        if last_movement_direction < 0:
            player_sprite.flip_h = true
        elif last_movement_direction > 0:
            player_sprite.flip_h = false

# Calibration function - call this to set current position as zero point
func calibrate_zero_position() -> void:
    zero_offset = network_position
    print("Zero position calibrated to: ", zero_offset)
    
func _on_logout_button_pressed() -> void:
    get_tree().change_scene_to_file("res://Main_screen/Scenes/select_game.tscn")
