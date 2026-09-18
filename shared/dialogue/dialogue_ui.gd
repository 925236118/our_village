## 共享对话框 —— 共享资源，参与者请勿修改本文件。
##
## 由 GameShell 自动放进场景树，NPC 说话时会自动弹出来。
## 想改样式就改 dialogue_ui.tscn，但注意这是共享文件，改动会影响所有人。

class_name DialogueUI
extends CanvasLayer

## 弹出 / 收起时发出。GameShell 靠它知道「现在在说话」，好把玩家冻住。
signal opened
signal closed

## 一句话停留几秒。
@export var hold_seconds: float = 4.0

## 可选：拖一个中文字体进来。留空则用 Godot 默认字体
## （4.3+ 会自动回退到系统字体，Windows 上一般能正常显示中文）。
@export var font: FontFile

@onready var _panel: PanelContainer = $Panel
@onready var _label: Label = $Panel/Margin/Text
@onready var _timer: Timer = $Timer

## 弹出时所在的帧号。用来挡掉「打开的那一次按键」——否则同一次按 E
## 会被当成「关闭」，对话框一闪就没了。
var _opened_frame: int = -1


func _ready() -> void:
	_panel.visible = false
	_timer.one_shot = true
	_timer.timeout.connect(_hide)
	if font != null:
		_label.add_theme_font_override("font", font)


func show_line(text: String) -> void:
	_label.text = text
	_panel.visible = true
	_timer.start(hold_seconds)
	_opened_frame = Engine.get_process_frames()
	opened.emit()


## 还开着的时候再按一次交互键就收起，不用干等 hold_seconds 走完。
func _unhandled_input(event: InputEvent) -> void:
	if not _panel.visible:
		return
	if not event.is_action_pressed("interact"):
		return
	if Engine.get_process_frames() <= _opened_frame:
		return
	get_viewport().set_input_as_handled()
	_timer.stop()
	_hide()


func _hide() -> void:
	_panel.visible = false
	closed.emit()
