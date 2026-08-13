class_name SolarTermsBar
extends Control
## 右侧紧凑节气进度条：左侧显示当前节气名，右侧竖轨道一次展示 3 个节点
## （上一个 / 当前 / 下一个），点击上下节点切换节气。

signal term_selected(term_name: String)

const SOLAR_TERMS := [
	"立春", "雨水", "惊蛰", "春分", "清明", "谷雨",
	"立夏", "小满", "芒种", "夏至", "小暑", "大暑",
	"立秋", "处暑", "白露", "秋分", "寒露", "霜降",
	"立冬", "小雪", "大雪", "冬至", "小寒", "大寒",
]

const SEASON_COLORS := [
	Color("6fbf4d"),  # 春 绿
	Color("f2a65a"),  # 夏 橙
	Color("e8c33a"),  # 秋 黄
	Color("5aa8e0"),  # 冬 蓝
]

const NAME_FONT_SIZE := 26
const DOT_R := 8.0
const DOT_GAP := 36.0

var selected := 0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP


func _season_of(index: int) -> int:
	return index / 6


func _track_center_x() -> float:
	return size.x - 26.0


## offset 相对选中节气：-1 上一个、0 当前、1 下一个。
func _dot_pos(offset: int) -> Vector2:
	var cy := size.y / 2.0
	return Vector2(_track_center_x(), cy + offset * DOT_GAP)


func _draw_text_outlined(pos: Vector2, text: String, font_size: int,
		color: Color, outline: Color) -> void:
	var font := ThemeDB.fallback_font
	for o in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		draw_string(font, pos + o, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw() -> void:
	var cy := size.y / 2.0
	var track_top := _dot_pos(-1).y
	var track_bottom := _dot_pos(1).y
	var cx := _track_center_x()

	# 轨道底色（短轨道，只有三个节点跨度）
	draw_rect(Rect2(cx - 6, track_top - 4, 12, track_bottom - track_top + 8),
			Color(0.92, 0.88, 0.78, 0.95), true)

	# 上 / 当前 / 下 三个节点
	for off in [-1, 0, 1]:
		var idx: int = selected + off
		var p: Vector2 = _dot_pos(off)
		if idx < 0 or idx >= SOLAR_TERMS.size():
			draw_circle(p, DOT_R, Color(0, 0, 0, 0.12))
			continue
		var col: Color = SEASON_COLORS[_season_of(idx)]
		draw_circle(p, DOT_R, col)
		draw_arc(p, DOT_R + 3, 0, TAU, 32, Color(0.42, 0.34, 0.22, 0.4), 2.0)

	# 当前节点高亮
	var cur := _dot_pos(0)
	draw_circle(cur, 20, Color(1, 0.85, 0.35, 0.3))
	draw_circle(cur, DOT_R + 2, Color(1, 0.88, 0.45, 1))

	# 左右箭头提示
	_draw_text_outlined(Vector2(cx - 9, track_top - 16), "▲", 14,
			Color(0.5, 0.4, 0.25, 0.85), Color(1, 1, 1, 0.6))
	_draw_text_outlined(Vector2(cx - 9, track_bottom + 2), "▼", 14,
			Color(0.5, 0.4, 0.25, 0.85), Color(1, 1, 1, 0.6))

	# 当前节气名（进度条左侧）
	_draw_text_outlined(Vector2(14, cy + 8), SOLAR_TERMS[selected], NAME_FONT_SIZE,
			Color(0.32, 0.24, 0.13), Color(1, 0.98, 0.9, 0.9))


## 选中节气并广播。
func select(index: int) -> void:
	if index < 0 or index >= SOLAR_TERMS.size():
		return
	selected = index
	queue_redraw()
	term_selected.emit(SOLAR_TERMS[selected])


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = event.position
		if _dot_pos(0).distance_to(p) < 18.0:
			return
		if _dot_pos(-1).distance_to(p) < 18.0:
			select(selected - 1)
		elif _dot_pos(1).distance_to(p) < 18.0:
			select(selected + 1)
