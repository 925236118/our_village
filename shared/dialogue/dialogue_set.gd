## 对话表 —— 共享资源，参与者请勿修改本文件。
##
## 读取 dialogue.json，按当前时段筛出可用的句子，再按权重随机抽一条。
##
## 格式：
##
##     {
##       "lines": [
##         {"id": "morning", "text": "早啊，今天来得挺早。", "start": "06:00", "end": "09:00", "weight": 3},
##         {"id": "night",   "text": "这么晚还不睡？",       "start": "22:00", "weight": 2},
##         {"id": "any",     "text": "有事随时叫我。",       "weight": 1}
##       ]
##     }
##
## 规则：
##   lines   必填，数组，至少一条
##   id      必填，同一个文件里不能重复
##   text    必填，不能为空
##   start   选填，开始时刻 "HH:MM"；不写表示不限
##   end     选填，结束时刻 "HH:MM"；不写表示不限。end 必须晚于 start，不支持跨夜
##   weight  选填，正整数，越大越容易被抽到；写 0 表示这条不启用，不写默认 1
##
## 文件必须是 UTF-8 编码。写错了会在这里报错，不会静默忽略。

class_name DialogueSet
extends RefCounted


class Line extends RefCounted:
	var id: String = ""
	var text: String = ""
	var start: int = -1   ## 分钟数，-1 表示不限
	var end: int = -1
	var weight: int = 1

	func active_at(minutes: int) -> bool:
		if start >= 0 and minutes < start:
			return false
		if end >= 0 and minutes >= end:
			return false
		return true


var lines: Array[Line] = []
var source_path: String = ""

var _rng := RandomNumberGenerator.new()

## 每条允许出现的字段。多出来的字段一律报错，专治 wieght / Start 这种拼写错误。
const ALLOWED_KEYS := ["id", "text", "start", "end", "weight"]


## 读取 JSON。失败时返回 null 并把原因推进错误输出。
static func load_from_json(path: String) -> DialogueSet:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("[对话] 打不开文件：%s" % path)
		return null
	var text := f.get_as_text()
	f.close()

	# 有些编辑器存 UTF-8 会在开头带上 BOM(U+FEFF)，JSON 解析器不认这个字符。
	# 用码位判断，源码里不写那个看不见的字符，免得以后被编辑器吃掉。
	if not text.is_empty() and text.unicode_at(0) == 0xFEFF:
		text = text.substr(1)

	var json := JSON.new()
	if json.parse(text) != OK:
		push_error("[对话] %s 第 %d 行 JSON 语法写错了：%s"
			% [path, json.get_error_line(), json.get_error_message()])
		return null

	var data = json.data
	if not (data is Dictionary):
		push_error("[对话] %s 最外层要用花括号包成对象，形如 {\"lines\": [...]}。" % path)
		return null
	if not data.has("lines"):
		push_error("[对话] %s 里没有 lines 字段，形如 {\"lines\": [...]}。" % path)
		return null

	var raw_lines = data["lines"]
	if not (raw_lines is Array):
		push_error("[对话] %s 的 lines 必须是数组，用方括号包起来。" % path)
		return null
	if raw_lines.is_empty():
		push_error("[对话] %s 的 lines 是空的，至少要写一条。" % path)
		return null

	var set := DialogueSet.new()
	set.source_path = path
	set._rng.randomize()

	var seen := {}
	# raw_lines 是 Variant，它的 size() 也是 Variant，所以这里的 i 推断不出类型，
	# n 必须显式标 int，不然编译器会报 "Cannot infer the type"。
	for i in raw_lines.size():
		var n: int = i + 1   # 给人看的序号，从 1 开始
		if not _parse_entry(path, n, raw_lines[i], seen, set):
			return null

	set._check_encoding()
	if set.lines.is_empty():
		return null
	return set


## 解析一条，成功返回 true。任何一处不合格就报错并返回 false。
static func _parse_entry(path: String, n: int, raw, seen: Dictionary,
		set: DialogueSet) -> bool:
	if not (raw is Dictionary):
		push_error("[对话] %s 第 %d 条不是对象，每条都要写成 {...}。" % [path, n])
		return false
	var entry := raw as Dictionary

	for key in entry.keys():
		if not ALLOWED_KEYS.has(key):
			push_error("[对话] %s 第 %d 条有多余的字段 \"%s\"，只能写 id、text、start、end、weight。是不是拼错了？"
				% [path, n, key])
			return false

	if not entry.has("text"):
		push_error("[对话] %s 第 %d 条缺少 text。" % [path, n])
		return false
	if not entry.has("id"):
		push_error("[对话] %s 第 %d 条缺少 id。" % [path, n])
		return false

	var line := Line.new()
	line.text = str(entry["text"]).strip_edges()
	line.id = str(entry["id"]).strip_edges()

	if line.text.is_empty():
		push_error("[对话] %s 第 %d 条的 text 是空的。" % [path, n])
		return false
	if line.id.is_empty():
		push_error("[对话] %s 第 %d 条的 id 是空的。" % [path, n])
		return false
	if seen.has(line.id):
		push_error("[对话] %s 里 id \"%s\" 出现了不止一次（第 %d 条又出现）。"
			% [path, line.id, n])
		return false
	seen[line.id] = true

	var raw_start := str(entry.get("start", "")).strip_edges()
	var raw_end := str(entry.get("end", "")).strip_edges()
	line.start = parse_time(raw_start)
	line.end = parse_time(raw_end)
	if line.start == -2:
		push_error("[对话] %s 第 %d 条的 start 写得不对：\"%s\"。应该写成 \"HH:MM\"（比如 \"06:00\"）；不想限制时段就不写这个字段。"
			% [path, n, raw_start])
		return false
	if line.end == -2:
		push_error("[对话] %s 第 %d 条的 end 写得不对：\"%s\"。应该写成 \"HH:MM\"（比如 \"09:00\"）；不想限制时段就不写这个字段。"
			% [path, n, raw_end])
		return false
	if line.start >= 0 and line.end >= 0 and line.end <= line.start:
		push_error("[对话] %s 第 %d 条的 end(%s) 必须晚于 start(%s)，不支持跨夜。"
			% [path, n, raw_end, raw_start])
		return false

	var raw_weight = entry.get("weight", 1)
	if not (raw_weight is int or raw_weight is float):
		push_error("[对话] %s 第 %d 条的 weight 要写数字，不用加引号，现在是 \"%s\"。"
			% [path, n, str(raw_weight)])
		return false
	line.weight = int(raw_weight)
	if line.weight < 0:
		push_error("[对话] %s 第 %d 条的 weight 不能是负数。" % [path, n])
		return false

	set.lines.append(line)
	return true


## 文件存成 GBK 之类的编码时，中文会变成 U+FFFD。这个错很难自己看出来，替他抓一下。
func _check_encoding() -> void:
	for l in lines:
		if l.text.contains(char(0xFFFD)):
			push_error("[对话] %s 里的中文变成乱码了，说明文件不是 UTF-8 编码"
				% source_path + "（多半是存成了 ANSI/GBK）。请用 UTF-8 重新保存。")
			lines.clear()
			return


## "HH:MM" -> 分钟数。空串返回 -1（不限），格式错误返回 -2。
static func parse_time(s: String) -> int:
	if s.is_empty():
		return -1
	var parts := s.split(":")
	if parts.size() != 2:
		return -2
	var h := parts[0].strip_edges()
	var m := parts[1].strip_edges()
	if not h.is_valid_int() or not m.is_valid_int():
		return -2
	var hh := int(h)
	var mm := int(m)
	if hh < 0 or hh > 23 or mm < 0 or mm > 59:
		return -2
	return hh * 60 + mm


static func format_time(minutes: int) -> String:
	if minutes < 0:
		return "--:--"
	return "%02d:%02d" % [minutes / 60, minutes % 60]


## 当前时刻可用的所有句子（weight > 0）。
func active_at(minutes: int) -> Array[Line]:
	var out: Array[Line] = []
	for l in lines:
		if l.weight > 0 and l.active_at(minutes):
			out.append(l)
	return out


## 按权重随机抽一条。没有可用的句子时返回 null。
func pick(minutes: int) -> Line:
	var pool := active_at(minutes)
	if pool.is_empty():
		return null
	var total := 0
	for l in pool:
		total += l.weight
	var roll := _rng.randi_range(0, total - 1)
	for l in pool:
		roll -= l.weight
		if roll < 0:
			return l
	return pool[pool.size() - 1]


## 用当前时刻抽一条。时刻来自 GameShell（可在里面覆盖成固定时间方便评审）。
func pick_now() -> Line:
	return pick(GameShell.minutes_of_day())


## 调试用：把某个时刻的可选句子打出来。
func dump(minutes: int) -> void:
	print("[对话] %s @ %s，可用 %d 条：" % [source_path, format_time(minutes), active_at(minutes).size()])
	for l in active_at(minutes):
		print("   w=%d  %s" % [l.weight, l.text])
