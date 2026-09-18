## 场景出口 —— 共享资源，参与者请勿修改本文件。
##
## 用法：把 exit_portal.tscn 摆到你的 entry.tscn 里，然后在检查器里填 Target Scene。
## 玩家走进去就会切换到那个场景，GameShell 会自动在新场景重新生成玩家。
##
## 只能跳转到你自己 entries/<你的目录>/ 下的场景，不要跳去别人的目录。

class_name ExitPortal
extends Area2D

## 玩家走进去之后切换到哪个场景。必须是你自己目录下的 .tscn。
@export_file("*.tscn") var target_scene: String = ""

## 允许重复触发的时间间隔（秒），防止玩家卡在门口反复切场景。
@export var cooldown: float = 1.5


var _busy: bool = false


func _ready() -> void:
	add_to_group("exit_area")
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _busy or not body.is_in_group("player"):
		return
	if target_scene.is_empty():
		push_warning("[出口] %s 没有设置 Target Scene，玩家走进去不会有反应。" % name)
		return
	if not FileAccess.file_exists(target_scene):
		push_error("[出口] 找不到目标场景：%s" % target_scene)
		return
	_busy = true
	get_tree().change_scene_to_file(target_scene)
	await get_tree().process_frame
	_busy = false
