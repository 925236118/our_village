## 角色图集规格 —— 共享资源，参与者请勿修改本文件。
##
## 整个活动只有这一份动画表。NPC 壳子和共享玩家都用它，所以改一处两边同时生效。
##
## 图集规格：2688 x 1920，每帧 48 x 96，共 56 列 x 20 行。
## 朝向顺序固定为「右上左下」= right, up, left, down。
##
## 每一行只有部分朝向时（比如 sleep 只有下、sit 只有左右），
## 图上就只排这些朝向，从第 0 列起按右上左下顺序顺次排。
## 没有的朝向就是那个动作本来就没有这个方向，不要自己补。

class_name CharacterSheet
extends RefCounted

const FRAME_W := 48
const FRAME_H := 96
const SHEET_COLS := 56
const SHEET_ROWS := 20

## 生成器原始输出应该是这个尺寸。裁剪过的图集对不上，会被拒绝。
const EXPECTED_SIZE := Vector2i(SHEET_COLS * FRAME_W, SHEET_ROWS * FRAME_H)

const DIR_RIGHT := 0
const DIR_UP := 1
const DIR_LEFT := 2
const DIR_DOWN := 3
const DIR_ORDER: Array[String] = ["right", "up", "left", "down"]

## row    该动作在第几行（0 起）
## frames 每个朝向几帧
## dirs   该动作实际存在的朝向，按右上左下顺序写
## fps    播放速度
## loop   是否循环
const ANIM := {
	"static":   {"row": 0,  "frames": 1,  "dirs": "RULD", "fps": 1.0,  "loop": true,  "label": "静止（单帧）"},
	"idle":     {"row": 1,  "frames": 6,  "dirs": "RULD", "fps": 6.0,  "loop": true,  "label": "站立等待"},
	"walk":     {"row": 2,  "frames": 6,  "dirs": "RULD", "fps": 10.0, "loop": true,  "label": "行走"},
	"sleep":    {"row": 3,  "frames": 6,  "dirs": "D",    "fps": 4.0,  "loop": true,  "label": "睡觉（仅下）"},
	"sit":      {"row": 4,  "frames": 6,  "dirs": "RL",   "fps": 4.0,  "loop": true,  "label": "坐下（仅左右）"},
	"sit_desk": {"row": 5,  "frames": 6,  "dirs": "RL",   "fps": 4.0,  "loop": true,  "label": "伏案（仅左右）"},
	"phone":    {"row": 6,  "frames": 12, "dirs": "D",    "fps": 6.0,  "loop": true,  "label": "玩手机（仅下，1-3 掏出 / 4-9 循环 / 10-12 收起）"},
	"read":     {"row": 7,  "frames": 12, "dirs": "D",    "fps": 6.0,  "loop": true,  "label": "看书（仅下，1-6 循环 / 7-12 翻页）"},
	"push":     {"row": 8,  "frames": 6,  "dirs": "RULD", "fps": 10.0, "loop": true,  "label": "推车"},
	"pickup":   {"row": 9,  "frames": 12, "dirs": "RULD", "fps": 10.0, "loop": false, "label": "捡东西"},
	"gift":     {"row": 10, "frames": 10, "dirs": "RULD", "fps": 10.0, "loop": false, "label": "送礼物"},
	"lift":     {"row": 11, "frames": 14, "dirs": "RULD", "fps": 10.0, "loop": false, "label": "举起放下（1-7 举起 / 8-14 放下）"},
	"throw":    {"row": 12, "frames": 14, "dirs": "RULD", "fps": 10.0, "loop": false, "label": "举起投掷（1-7 举起 / 8-14 投掷）"},
	"hit":      {"row": 13, "frames": 6,  "dirs": "RULD", "fps": 10.0, "loop": false, "label": "打击"},
	"punch":    {"row": 14, "frames": 6,  "dirs": "RULD", "fps": 10.0, "loop": false, "label": "拳击"},
	"stab":     {"row": 15, "frames": 6,  "dirs": "RULD", "fps": 10.0, "loop": false, "label": "匕首"},
	"grab_gun": {"row": 16, "frames": 4,  "dirs": "RULD", "fps": 8.0,  "loop": false, "label": "抓枪"},
	"gun_idle": {"row": 17, "frames": 6,  "dirs": "RULD", "fps": 6.0,  "loop": true,  "label": "持枪站立"},
	"shoot":    {"row": 18, "frames": 3,  "dirs": "RULD", "fps": 12.0, "loop": false, "label": "射击"},
	"hurt":     {"row": 19, "frames": 3,  "dirs": "RULD", "fps": 8.0,  "loop": false, "label": "受伤"},
}

## 活动只用到这些。其余动作留在表里，但不在规范里推荐使用。
const RECOMMENDED := ["idle", "walk", "sit", "sit_desk", "phone", "read", "sleep"]

var _slots: Dictionary = {}   # anim -> [4]，每个朝向的起始列，-1 表示没有这个朝向


func _init() -> void:
	for name in ANIM:
		var a: Dictionary = ANIM[name]
		var slots := [-1, -1, -1, -1]
		var offset := 0
		for d in DIR_ORDER:
			if a["dirs"].contains(d[0].to_upper()):
				slots[DIR_ORDER.find(d)] = offset
				offset += int(a["frames"])
		_slots[name] = slots


func has(anim: String) -> bool:
	return ANIM.has(anim)


func frames(anim: String) -> int:
	return int(ANIM[anim]["frames"])


func loops(anim: String) -> bool:
	return bool(ANIM[anim]["loop"])


func fps(anim: String) -> float:
	return float(ANIM[anim]["fps"])


func row(anim: String) -> int:
	return int(ANIM[anim]["row"])


## 这个动作有没有这个朝向。没有就返回 -1。
func slot(anim: String, dir: int) -> int:
	return int(_slots[anim][dir])


func supports(anim: String, dir: int) -> bool:
	return slot(anim, dir) >= 0


## 这个动作支持的第一个朝向，用来在指定朝向不存在时兜底。
func first_supported_dir(anim: String) -> int:
	for d in 4:
		if slot(anim, d) >= 0:
			return d
	return DIR_DOWN


## Sprite2D 用的帧序号（配合 hframes=56 / vframes=20）。
func frame_index(anim: String, dir: int, frame: int) -> int:
	var s := slot(anim, dir)
	if s < 0:
		return row(anim) * SHEET_COLS
	var f := clampi(frame, 0, frames(anim) - 1)
	return row(anim) * SHEET_COLS + s + f


## 把移动方向转成朝向。横竖谁的分量大听谁的。
static func dir_from_vector(v: Vector2) -> int:
	if absf(v.x) > absf(v.y):
		return DIR_RIGHT if v.x > 0.0 else DIR_LEFT
	return DIR_DOWN if v.y > 0.0 else DIR_UP


static func dir_name(dir: int) -> String:
	return DIR_ORDER[clampi(dir, 0, 3)]


## 检查图集尺寸对不对。返回空串表示没问题，否则返回给用户看的原因。
static func validate_size(tex: Texture2D) -> String:
	if tex == null:
		return "没有设置 Sheet。"
	var size := tex.get_size()
	if Vector2i(size) != EXPECTED_SIZE:
		return "图集尺寸是 %dx%d，应该是 %dx%d。请使用生成器的原始输出，不要裁剪。" % [
			int(size.x), int(size.y), EXPECTED_SIZE.x, EXPECTED_SIZE.y]
	return ""


## 按帧序号取这一帧在图上的像素区域，评审工具和调试用。
static func frame_rect(anim: String, dir: int, frame: int) -> Rect2i:
	var a: Dictionary = ANIM[anim]
	var offset := 0
	for d in DIR_ORDER:
		if a["dirs"].contains(d[0].to_upper()):
			if DIR_ORDER.find(d) == dir:
				break
			offset += int(a["frames"])
	return Rect2i(offset * FRAME_W, int(a["row"]) * FRAME_H, FRAME_W, FRAME_H)
