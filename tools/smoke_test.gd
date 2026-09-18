## 冒烟测试：把范例场景真跑一遍，确认「导航烘焙 + 生成玩家 + NPC 巡游」这条链路是通的。
##
##   godot --headless --path . res://tools/smoke_test.tscn
##
## 全绿返回 0，有问题返回 1。改完共享代码记得跑一下。
##
## 注意：这里用「一个场景」而不是 --script 主循环，因为 --script 模式下
## await physics_frame 不会推进，脚本会卡死。

extends Node

const SCENE_PATH := "res://entries/_example/entry.tscn"
const WARMUP_FRAMES := 30      # 留给 GameShell 发现场景、烘焙导航
const OBSERVE_FRAMES := 240    # 观察 NPC 走不走得动

var _fails: Array[String] = []


func _ready() -> void:
	_run()


func _run() -> void:
	var packed := load(SCENE_PATH) as PackedScene
	if packed == null:
		_fail("load 不到 %s" % SCENE_PATH)
		return _finish()

	# 当成子节点挂进来。GameShell 会从 current_scene 往下找 NavigationRegion2D 和 entry_point，
	# 所以放在这一层它照样能找到。
	var scene := packed.instantiate()
	add_child(scene)

	for i in WARMUP_FRAMES:
		await get_tree().physics_frame

	# 导航网格由 NavLayer 自己注册进场景的导航地图，直接问导航服务器要
	var map := get_viewport().find_world_2d().navigation_map
	var regions: Array = NavigationServer2D.map_get_regions(map)
	if regions.is_empty():
		_fail("导航地图里没有任何导航区域 —— NavLayer 上刷格子了吗？")
	else:
		print("  导航地图里有 %d 个导航区域" % regions.size())

	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		_fail("GameShell 没有生成玩家")
	else:
		var entry := get_tree().get_first_node_in_group("entry_point") as Node2D
		if entry == null:
			_fail("场景里没有 entry_point 组的节点")
		elif player.global_position.distance_to(entry.global_position) > 1.0:
			_fail("玩家没有出现在 entry_point 上（玩家 %s，出生点 %s）"
				% [player.global_position, entry.global_position])
		else:
			print("  玩家已生成在 entry_point：%s" % player.global_position)

	var npc := _find_npc(scene)
	if npc == null:
		_fail("场景里没有 VillageNpc")
		return _finish()
	if npc.get("sheet") == null:
		_fail("NPC 的 Sheet 没有填")

	_check_dialogue(npc)
	await _check_dialogue_link(npc)

	# NPC 站的地方必须落在导航网格上，否则它再努力也走不动
	var on_mesh := NavigationServer2D.map_get_closest_point(map, npc.global_position)
	var off := on_mesh.distance_to(npc.global_position)
	if off > 64.0:
		_fail("NPC 出生点不在导航网格上（离网格 %.0f 像素），NavLayer 要铺到它脚下" % off)

	var from: Vector2 = npc.global_position
	for i in OBSERVE_FRAMES:
		await get_tree().physics_frame
	var to: Vector2 = npc.global_position
	var walked := from.distance_to(to)
	if walked < 8.0:
		_fail("NPC 四秒只挪了 %.1f 像素，八成是没在寻路" % walked)
	else:
		print("  NPC 巡游正常：走了 %.1f 像素，%s -> %s" % [walked, from, to])

	return _finish()


# ---------------------------------------------------------------- 工具

## 对话表要能加载，而且 24 小时里每一刻都抽得出台词。
## 缺哪个时段，玩家那个点走过来就会没反应 —— 这是最容易漏的一条。
func _check_dialogue(npc: Node) -> void:
	var d = npc.get("_dialogue")
	if d == null:
		_fail("NPC 没有加载到对话表（dialogue.json 路径填错或 JSON 写错了）")
		return

	var silent: Array[String] = []
	for hour in 24:
		if d.pick(hour * 60) == null:
			silent.append("%02d:00" % hour)
	if not silent.is_empty():
		_fail("这些时刻抽不出台词：%s" % ", ".join(silent))
		return
	print("  对话表已加载：%d 条，24 小时全覆盖" % d.lines.size())


## 说话这条链路：NPC 发信号 → 管家接住 → 对话框弹出来 → 玩家被冻住。
## 光有一环对不算数，这里从头发到尾走一遍。
##
## 注意开头那一步：这个测试是把范例场景 add_child 进来的，那时 GameShell 早就
## 连好 node_added 了，信号自然接得上 —— 真实的翻车场景（引擎启动时主场景
## 先于 autoload 的 _ready 进树）在这儿复现不出来。所以先把信号断开，手动
## 制造「漏接」的状态，再看管家重新装配时会不会补上。
func _check_dialogue_link(npc: Node) -> void:
	for c in npc.spoke.get_connections():
		npc.spoke.disconnect(c["callable"])
	if not npc.spoke.get_connections().is_empty():
		_fail("测试自身出错：spoke 信号断不开")
		return

	GameShell.call("_setup")
	await get_tree().process_frame

	var conns: int = npc.spoke.get_connections().size()
	if conns == 0:
		_fail("NPC 的 spoke 信号没接上 —— 台词抽得出来，但永远弹不出对话框")
		return

	# _setup 会重新生成玩家，所以要拿新的那个
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		_fail("_setup 之后找不到玩家")
		return

	npc.spoke.emit("冒烟测试台词")
	await get_tree().process_frame

	var ui = GameShell.get("_ui")
	if ui == null:
		_fail("GameShell 没有对话框实例")
		return
	var panel := ui.get_node_or_null("Panel") as CanvasItem
	if panel == null or not panel.visible:
		_fail("发了 spoke 但对话框没显示出来")
		return
	if not GameShell.is_busy():
		_fail("对话框显示了，但 GameShell 没进入 busy —— 玩家还能一边说一边走")
		return

	# 真的按着方向键走几帧，确认走不动
	var before: Vector2 = player.global_position
	Input.action_press("move_right")
	for i in 8:
		await get_tree().physics_frame
	var drift := before.distance_to(player.global_position)
	Input.action_release("move_right")
	if drift > 1.0:
		_fail("说话期间玩家还挪了 %.1f 像素，没被冻住" % drift)
		return

	# 再按一次 E 应该收起对话框（不是干等 hold_seconds 走完）
	await _press_interact()
	await get_tree().process_frame
	if panel.visible:
		_fail("说话时再按 E 没能收起对话框")
		return
	if GameShell.is_busy():
		_fail("对话框收了，GameShell 还是 busy —— 玩家会被永久卡住")
		return

	Input.action_press("move_right")
	for i in 8:
		await get_tree().physics_frame
	var after := before.distance_to(player.global_position)
	Input.action_release("move_right")
	if after <= 1.0:
		_fail("对话框收起后玩家还是走不动，输入没恢复")
		return

	print("  对话链路正常：弹框、冻住玩家、按 E 收起、收起后恢复走动")


## 模拟按一次交互键。
## 注意不能用 Input.action_press —— 那只改动作状态，不会生成 InputEvent，
## 走不到 _unhandled_input，测不出按键逻辑。要用 parse_input_event。
func _press_interact() -> void:
	var ev := InputEventAction.new()
	ev.action = "interact"
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().process_frame
	var up := InputEventAction.new()
	up.action = "interact"
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame


func _find_npc(node: Node) -> Node:
	if node is CharacterBody2D and node.get("waypoint_activity") != null:
		return node
	for child in node.get_children():
		var found := _find_npc(child)
		if found != null:
			return found
	return null


func _fail(msg: String) -> void:
	_fails.append(msg)
	print("  [失败] " + msg)


func _finish() -> void:
	print("")
	if _fails.is_empty():
		print("冒烟测试通过。")
		get_tree().quit(0)
	else:
		print("冒烟测试失败，共 %d 项：" % _fails.size())
		for f in _fails:
			print("  - " + f)
		get_tree().quit(1)
