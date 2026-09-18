## 生成 entries/_example 里的范例场景（主办方用，参与者不需要跑）。
##
## TileMapLayer 的格子数据是二进制格式，手写容易出错，所以交给引擎自己写：
##
##   godot --headless --path . --script res://tools/build_example_scene.gd
##
## 想改范例布局就改这个文件，然后重新跑一次。

extends SceneTree

const TILE := 48
const NAV_TILESET := "res://shared/tileset/nav_tileset.tres"
const NPC_SCENE := "res://shared/npc/npc.tscn"
const PORTAL_SCENE := "res://shared/scene_portal/exit_portal.tscn"
const SHEET := "res://entries/_example/char/sheet.png"
const DIALOGUE := "res://entries/_example/dialogue.json"

const MAIN_PATH := "res://entries/_example/entry.tscn"
const INNER_PATH := "res://entries/_example/inner_room.tscn"

const FLOOR_COLOR := Color("3b3f4a")
const WALL_COLOR := Color("23252c")
const INNER_FLOOR := Color("343845")


func _initialize() -> void:
	var code := _run()
	quit(code)


func _run() -> int:
	var tileset := load(NAV_TILESET) as TileSet
	if tileset == null:
		push_error("load 不到 %s" % NAV_TILESET)
		return 1
	var npc_scene := load(NPC_SCENE) as PackedScene
	var portal_scene := load(PORTAL_SCENE) as PackedScene
	var sheet := load(SHEET) as Texture2D
	if npc_scene == null or portal_scene == null or sheet == null:
		push_error("有几个资源 load 不到，先跑一次 godot --headless --editor --quit 导入素材。")
		return 1

	# 两个场景互相跳转，用来演示出口。出口都摆在墙边，像个门。
	var main := _room("Entry", 16, 11, Vector2i(14, 5), portal_scene)
	main.get_node("ExitPortal").target_scene = INNER_PATH
	_add_npc(main, npc_scene, sheet, Vector2i(8, 4),
		[Vector2i(3, 3), Vector2i(8, 7), Vector2i(12, 4)])
	_save(main, MAIN_PATH)

	var inner := _room("InnerRoom", 11, 8, Vector2i(8, 2), portal_scene)
	inner.get_node("ExitPortal").target_scene = MAIN_PATH
	_add_npc(inner, npc_scene, sheet, Vector2i(5, 4), [Vector2i(2, 2), Vector2i(8, 5)])
	_save(inner, INNER_PATH)

	print("范例场景已生成：%s、%s" % [MAIN_PATH, INNER_PATH])
	return 0


## 一个房间：地面 + 墙 + 导航层 + 出生点 + 出口。
## tiles_w/tiles_h 是房间总格数，最外一圈是墙，里面那圈才是可走区域。
func _room(room_name: String, tiles_w: int, tiles_h: int,
		exit_tile: Vector2i, portal_scene: PackedScene) -> Node2D:
	var root := Node2D.new()
	root.name = room_name

	# 导航层放在最前面（最底下画），地板盖在它上面 ——
	# 这样编辑器里看得见青色格子方便刷，游戏里被地板挡住不会露出来。
	var nav_layer := TileMapLayer.new()
	nav_layer.name = "NavLayer"
	nav_layer.tile_set = load(NAV_TILESET) as TileSet
	root.add_child(nav_layer)
	for x in range(1, tiles_w - 1):
		for y in range(1, tiles_h - 1):
			nav_layer.set_cell(Vector2i(x, y), 0, Vector2i(0, 0), 0)

	# 墙（深色底）和地板（浅色，内缩一格）
	_poly(root, "Wall", Vector2.ZERO,
		Vector2(tiles_w * TILE, tiles_h * TILE), WALL_COLOR)
	_poly(root, "Floor", Vector2(TILE, TILE),
		Vector2((tiles_w - 2) * TILE, (tiles_h - 2) * TILE), FLOOR_COLOR)

	# 墙也要挡人，不然玩家能走到画面外
	var walls := StaticBody2D.new()
	walls.name = "Walls"
	root.add_child(walls)
	_wall_shape(walls, Vector2(tiles_w * TILE / 2.0, TILE / 2.0), Vector2(tiles_w * TILE, TILE))
	_wall_shape(walls, Vector2(tiles_w * TILE / 2.0, (tiles_h - 0.5) * TILE), Vector2(tiles_w * TILE, TILE))
	_wall_shape(walls, Vector2(TILE / 2.0, tiles_h * TILE / 2.0), Vector2(TILE, tiles_h * TILE))
	_wall_shape(walls, Vector2((tiles_w - 0.5) * TILE, tiles_h * TILE / 2.0), Vector2(TILE, tiles_h * TILE))

	var entry := Marker2D.new()
	entry.name = "EntryPoint"
	entry.position = _center(Vector2i(2, tiles_h - 3))
	entry.add_to_group("entry_point", true)
	root.add_child(entry)

	var portal := portal_scene.instantiate() as Area2D
	portal.name = "ExitPortal"
	portal.position = _center(exit_tile)
	root.add_child(portal)

	return root


func _add_npc(root: Node2D, npc_scene: PackedScene, sheet: Texture2D,
		at: Vector2i, waypoints: Array) -> void:
	var npc := npc_scene.instantiate() as CharacterBody2D
	npc.name = "Npc"
	npc.set("sheet", sheet)
	npc.set("dialogue_json", DIALOGUE)
	npc.position = _center(at)
	root.add_child(npc)
	# 巡游点写成 NPC 的子节点；坐标在开场读一次，之后 NPC 走动不会带着它们跑
	for i in waypoints.size():
		var wp := Marker2D.new()
		wp.name = "Waypoint%d" % (i + 1)
		wp.position = _center(waypoints[i]) - npc.position
		npc.add_child(wp)


# ---------------------------------------------------------------- 小工具

func _center(tile: Vector2i) -> Vector2:
	return Vector2(tile.x * TILE + TILE / 2.0, tile.y * TILE + TILE / 2.0)


func _poly(parent: Node, pname: String, pos: Vector2, size: Vector2, color: Color) -> void:
	var poly := Polygon2D.new()
	poly.name = pname
	poly.position = pos
	poly.color = color
	poly.polygon = PackedVector2Array([
		Vector2.ZERO, Vector2(size.x, 0), Vector2(size.x, size.y), Vector2(0, size.y)])
	parent.add_child(poly)


func _wall_shape(parent: StaticBody2D, pos: Vector2, size: Vector2) -> void:
	var shape := RectangleShape2D.new()
	shape.size = size
	var cs := CollisionShape2D.new()
	cs.shape = shape
	cs.position = pos
	parent.add_child(cs)


## 保存前得把 owner 补上，没 owner 的节点不会写进 .tscn。
## 判据用 owner == null：我们自己 add_child 出来的节点 owner 是空的，
## 而 instantiate() 出来的子场景，它内部节点已经被引擎标好 owner 了，跳过即可。
func _own(root: Node, node: Node) -> void:
	for child in node.get_children():
		if child.owner == null:
			child.owner = root
			_own(root, child)


func _save(root: Node2D, path: String) -> void:
	_own(root, root)
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err != OK:
		push_error("pack %s 失败：%d" % [path, err])
		return
	err = ResourceSaver.save(packed, path)
	if err != OK:
		push_error("保存 %s 失败：%d" % [path, err])
	root.free()
