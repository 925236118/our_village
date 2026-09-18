## 生成导航瓦片集 shared/tileset/nav_tileset.tres（主办方用，参与者不需要跑）。
##
##   godot --headless --path . --script res://tools/build_nav_tileset.gd
##
## TileSet 里「瓦片 → 导航多边形」这层数据手写太容易错，交给引擎自己写。
## 导航层用的贴图是 tools/make_nav_tile.py 生成的。

extends SceneTree

const TEXTURE_PATH := "res://shared/tileset/nav_tile.png"
const OUT_PATH := "res://shared/tileset/nav_tileset.tres"
const TILE_SIZE := 48


func _initialize() -> void:
	quit(_run())


func _run() -> int:
	var texture := load(TEXTURE_PATH) as Texture2D
	if texture == null:
		push_error("load 不到 %s，先跑一次 godot --headless --editor --quit 导入素材。" % TEXTURE_PATH)
		return 1

	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	tileset.add_navigation_layer(-1)

	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	# 必须先把 source 挂到 tileset 上，瓦片才知道有几层导航可以放多边形
	tileset.add_source(source, 0)
	source.create_tile(Vector2i.ZERO)

	# 一格瓦片的导航多边形，坐标相对瓦片中心
	var half := TILE_SIZE / 2.0
	var poly := NavigationPolygon.new()
	poly.vertices = PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half),
		Vector2(half, half), Vector2(-half, half)])
	poly.add_polygon(PackedInt32Array([0, 1, 2, 3]))

	source.get_tile_data(Vector2i.ZERO, 0).set_navigation_polygon(0, poly)

	var err := ResourceSaver.save(tileset, OUT_PATH)
	if err != OK:
		push_error("保存 %s 失败：%d" % [OUT_PATH, err])
		return 1
	print("导航瓦片集已生成：%s（%d 层导航）" % [OUT_PATH, tileset.get_navigation_layers_count()])
	return 0
