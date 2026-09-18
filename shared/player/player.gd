## 共享玩家 —— 共享资源，参与者请勿修改本文件。
##
## 玩家由 GameShell 自动生成，群友不需要在自己的场景里摆。
## 你只要在场景里放一个 Marker2D 并加入 entry_point 组，玩家就会从那里出现。
##
## 操作：WASD / 方向键移动，E 与 NPC 对话。

class_name VillagePlayer
extends CharacterBody2D

@export_group("素材")
## 玩家角色图集，规格和 NPC 一样是 2688x1920。
## 不填就只有碰撞体、没有图像，调试时仍可正常走动。
@export var sheet: Texture2D

@export var speed: float = 170.0

@onready var _sprite: Sprite2D = $Sprite

var _cs := CharacterSheet.new()
var _anim := SheetAnimator.new(_cs)


func _ready() -> void:
	add_to_group("player")
	_sprite.hframes = CharacterSheet.SHEET_COLS
	_sprite.vframes = CharacterSheet.SHEET_ROWS
	_sprite.offset = Vector2(0, -CharacterSheet.FRAME_H / 2.0)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	if sheet == null:
		push_warning("[玩家] 还没有设置玩家图集，先用无图模式运行。"
			+ "把任意一份 2688x1920 的角色图集拖到 player.tscn 的 Sheet 上即可。")
		_sprite.visible = false
	else:
		var problem := CharacterSheet.validate_size(sheet)
		if not problem.is_empty():
			push_error("[玩家] %s" % problem)
			_sprite.visible = false
		else:
			_sprite.texture = sheet

	_anim.play("idle", CharacterSheet.DIR_DOWN)
	_sync()


func _physics_process(delta: float) -> void:
	# 正在跟 NPC 说话时不许走，否则玩家能一边听一边把自己开出对话框范围
	if GameShell.is_busy():
		velocity = Vector2.ZERO
		_anim.play("idle", _anim.dir)
		move_and_slide()
		_anim.advance(delta)
		_sync()
		return

	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = dir * speed
	if dir.length_squared() > 0.0001:
		_anim.play("walk", CharacterSheet.dir_from_vector(dir))
	else:
		_anim.play("idle", _anim.dir)
	move_and_slide()
	_anim.advance(delta)
	_sync()


func _sync() -> void:
	_sprite.frame = _anim.index()
