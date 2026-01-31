extends CharacterBody2D
class_name Player

# =====================================================
# ANIMATION SPRITES
# =====================================================
@export var idle_sprites: Array[Texture2D] = []
@export var walk_sprites: Array[Texture2D] = []
@export var jump_sprites: Array[Texture2D] = []
@export var crouch_sprites: Array[Texture2D] = []
@export var get_up_sprites: Array[Texture2D] = []
@export var taunt_sprites: Array[Texture2D] = []
@export var light_attack_sprites: Array[Texture2D] = []
@export var heavy_attack_sprites: Array[Texture2D] = []
@export var block_sprites: Array[Texture2D] = []
@export var hit_sprites: Array[Texture2D] = []
@export var knockdown_sprites: Array[Texture2D] = []

# =====================================================
# NODE REFERENCES
# =====================================================
@export var standing_collision: CollisionShape2D
@export var crouch_collision: CollisionShape2D
@export var sprite: Sprite2D

# =====================================================
# MOVEMENT
# =====================================================
@export var move_speed := 300.0
@export var jump_velocity := -600.0
@export var gravity := 1800.0
@export var floor_y_level := 500.0

# =====================================================
# COMBAT
# =====================================================
@export var max_health := 100.0
@export var light_attack_damage := 10.0
@export var heavy_attack_damage := 25.0
@export var block_damage_reduction := 0.5

# =====================================================
# STATE
# =====================================================
var current_health := 100.0

var is_attacking := false
var is_blocking := false
var is_crouching := false
var is_hit_stunned := false
var is_knockdown := false

var facing_right := true

# =====================================================
# ANIMATION STATE
# =====================================================
var current_animation := "idle"
var animation_frame := 0
var animation_timer := 0.0
var frame_duration := 0.1

# =====================================================
# HITBOXES
# =====================================================
var light_hitbox: Area2D
var heavy_hitbox: Area2D
var hurtbox: Area2D

# =====================================================
# SIGNALS
# =====================================================
signal health_changed(new_health: float)
signal damaged(damage: float)
signal attack_landed(damage: float, is_heavy: bool)
signal died()
signal combo_performed(count: int)

# =====================================================
# READY
# =====================================================
func _ready():
	current_health = max_health

	sprite = $Sprite2D
	light_hitbox = $Hitboxes/LightHitbox
	heavy_hitbox = $Hitboxes/HeavyHitbox
	hurtbox = $Hurtbox

	_setup_hitbox(light_hitbox)
	_setup_hitbox(heavy_hitbox)

	if light_hitbox:
		light_hitbox.area_entered.connect(_on_light_hitbox_area_entered)

	if heavy_hitbox:
		heavy_hitbox.area_entere
