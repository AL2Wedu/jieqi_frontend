extends Control
## 播种选作物弹窗：从商店拉取种子道具，点选后发出 picked。

signal picked(seed_item: Dictionary)

@onready var _seed_list: VBoxContainer = %SeedList
@onready var _hint: Label = %Hint


func _ready() -> void:
	%CloseButton.pressed.connect(_close)
	$Dim.gui_input.connect(_on_dim_input)


## 打开弹窗并加载商店种子列表。
func open() -> void:
	visible = true
	_clear_seed_list()
	_hint.visible = true
	_hint.text = "加载中…"
	var res := await Backend.get_shop()
	if not visible:
		return  # 等待期间被关闭
	_hint.visible = false
	if res.get("code", -1) != 0:
		_hint.visible = true
		_hint.text = "获取商店失败：" + str(res.get("message", "未知错误"))
		return
	for item in res["data"]["items"]:
		var it: Dictionary = item
		if it.get("category", "") != "seed":
			continue
		_seed_list.add_child(_make_item_button(it))
	if _seed_list.get_child_count() == 0:
		_hint.visible = true
		_hint.text = "商店里没有可种的作物"


func _clear_seed_list() -> void:
	for child in _seed_list.get_children():
		_seed_list.remove_child(child)
		child.queue_free()


func _make_item_button(item: Dictionary) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 48)
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", Color(0.42, 0.3, 0.15))
	var name: String = item.get("name", "")
	var price: Variant = item.get("buy_price", 0)
	btn.text = "%s　·　%d 金币" % [name, int(price)]
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.85, 0.68, 0.4, 1)
	sb.set_corner_radius_all(14)
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.border_color = Color(0.478, 0.322, 0.188, 1)
	btn.add_theme_stylebox_override("normal", sb)
	var sb_h := sb.duplicate()
	sb_h.bg_color = Color(0.92, 0.76, 0.48, 1)
	btn.add_theme_stylebox_override("hover", sb_h)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.pressed.connect(func() -> void:
		picked.emit(item)
		_close())
	return btn


func _close() -> void:
	visible = false


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_close()
