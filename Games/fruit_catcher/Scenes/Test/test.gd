extends Node2D

@onready var icon: Sprite2D = $Icon
@onready var icon_2: Sprite2D = $Icon2

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
    pass # Replace with function body.
    
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
    icon.position.x += 50.0 * delta
    icon_2.rotation += 2 * delta
