extends CharacterBody2D

var network_position = Vector2.ZERO
var zero_offset = Vector2.ZERO
@onready var adapt_toggle:bool = false
@onready var flash: AnimationPlayer = $AnimatedSprite2D/Flash
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@export var debug_mode: bool = true
func _ready() -> void:
    get_parent().flash_animation.connect(anim_change)
    get_parent().plane_crashed.connect(plane_anim_change)
    get_parent().game_started.connect(pilot_refresh)

func _physics_process(delta: float) -> void:
    
    if debug_mode:
        network_position = get_global_mouse_position()
    elif adapt_toggle:
        network_position = GlobalScript.scaled_network_position
    else:
        network_position = GlobalScript.network_position

        
    if network_position != Vector2.ZERO:
        network_position = network_position - zero_offset  + Vector2(600, 100)  
        position = position.lerp(network_position, 0.8)
    position.x = 100
    
    
    
    
        
func pilot_refresh():
    animated_sprite_2d.animation = 'default'

func plane_anim_change():
    #animated_sprite_2d.animation_changed
    animated_sprite_2d.animation = 'dead'
    
func anim_change():
    flash.play('flash')
    
func _on_adapt_rom_toggled(toggled_on: bool) -> void:
    if toggled_on:
        adapt_toggle = true
    else:
        adapt_toggle = false
