## 逐帧播放器 —— 共享资源，参与者请勿修改本文件。
##
## 按 CharacterSheet 的规格推进帧号。NPC 壳子和共享玩家都用它，
## 这样整套活动只有一个地方在算帧，不会出现两边对不上的情况。

class_name SheetAnimator
extends RefCounted

var sheet: CharacterSheet
var anim: String = "idle"
var dir: int = CharacterSheet.DIR_DOWN
var frame: int = 0

var _clock: float = 0.0

func _init(p_sheet: CharacterSheet = null) -> void:
	sheet = p_sheet if p_sheet != null else CharacterSheet.new()


## 切换动作 / 朝向。相同组合重复调用不会打断播放。
func play(p_anim: String, p_dir: int) -> void:
	if not sheet.has(p_anim):
		push_warning("[动画] 没有叫 %s 的动作，忽略。" % p_anim)
		return
	# 该动作没有这个朝向时，退回到它支持的第一个朝向
	if not sheet.supports(p_anim, p_dir):
		p_dir = sheet.first_supported_dir(p_anim)
	if p_anim == anim and p_dir == dir:
		return
	anim = p_anim
	dir = p_dir
	frame = 0
	_clock = 0.0


## 只换朝向，不换动作。
func face(p_dir: int) -> void:
	if p_dir == dir:
		return
	if not sheet.supports(anim, p_dir):
		p_dir = sheet.first_supported_dir(anim)
	if p_dir == dir:
		return
	dir = p_dir
	frame = 0
	_clock = 0.0


func face_vector(v: Vector2) -> void:
	if v.length_squared() < 0.0001:
		return
	face(CharacterSheet.dir_from_vector(v))


func advance(delta: float) -> void:
	var n := sheet.frames(anim)
	if n <= 1:
		frame = 0
		return
	_clock += delta * sheet.fps(anim)
	while _clock >= 1.0:
		_clock -= 1.0
		frame += 1
		if frame >= n:
			frame = 0 if sheet.loops(anim) else n - 1


## 当前该显示的帧序号，直接赋给 Sprite2D.frame。
func index() -> int:
	return sheet.frame_index(anim, dir, frame)


## 一次性动作是否已经播完（循环动作永远返回 false）。
func finished() -> bool:
	if sheet.loops(anim):
		return false
	return frame >= sheet.frames(anim) - 1
