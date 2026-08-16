extends Control
## 背包面板：列出背包道具与数量；选择模式（补货用）下点击道具发出 item_selected。
## 数据来源 GET /v1/player/inventory → { items:[{item_id, code, name, category, quantity, effect}] }。

signal close_requested
signal item_selected(item: Dictionary)

@onready var _item_list: VBoxContainer = %ItemList
@onready var _hint: Label = %Hint
@onready var _close: Button = %CloseButton
@onready var _dim: ColorRect = %Dim

var _select_mode := false


func _ready() -> void:
	_close.pressed.connect(func() -> void: close_requested.emit())
	_close.pressed.connect(func() -> void: hide())
	_dim.gui_input.connect(_on_dim_input)


## 打开面板并拉取背包。
func open() -> void:
	_select_mode = false
	visible = true
	_hint.visible = true
	_hint.text = "加载中…"
	await _refresh()


## 选择模式打开（补货用）：点击道具行发出 item_selected 并关闭。
func open_for_select() -> void:
	_select_mode = true
	visible = true
	_hint.visible = true
	_hint.text = "加载中…"
	await _refresh()


func _refresh() -> void:
	var res := await Backend.get_inventory()
	if not is_instance_valid(self):
		return
	if res.get("code", -1) != 0:
		_hint.visible = true
		_hint.text = Backend.friendly_message(res, "加载失败")
		return
	_clear_list()
	var items: Array = res["data"].get("items", [])
	var has_any := false
	for item in items:
		var d: Dictionary = item
		var qty: int = int(d.get("quantity", 0))
		if qty <= 0:
			continue  # 隐藏数量为 0 的行
		has_any = true
		_add_row(d, str(d.get("name", "?")), qty, str(d.get("category", "")))
	if not has_any:
		_hint.visible = true
		_hint.text = "背包空空的，去商店买些种子吧～"


func _clear_list() -> void:
	for child in _item_list.get_children():
		_item_list.remove_child(child)
		child.queue_free()


func _add_row(item: Dictionary, name: String, qty: int, category: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	if _select_mode:
		# 选择模式：整行可点，点击发出 item_selected
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 44)
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", 18)
		btn.add_theme_color_override("font_color", Color(0.42, 0.3, 0.15))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.85, 0.68, 0.4, 1)
		sb.set_corner_radius_all(12)
		sb.border_width_left = 3
		sb.border_width_top = 3
		sb.border_width_right = 3
		sb.border_width_bottom = 3
		sb.border_color = Color(0.478, 0.322, 0.188, 1)
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		btn.text = "%s · ×%d" % [name, qty]
		btn.pressed.connect(func() -> void:
			item_selected.emit(item)
			hide())
		_item_list.add_child(btn)
		return
	var cat := Label.new()
	cat.text = "[%s]" % category
	cat.custom_minimum_size = Vector2(110, 0)
	cat.add_theme_font_size_override("font_size", 17)
	cat.add_theme_color_override("font_color", Color(0.55, 0.42, 0.2))
	row.add_child(cat)
	var nm := Label.new()
	nm.text = name
	nm.add_theme_font_size_override("font_size", 18)
	nm.add_theme_color_override("font_color", Color(0.42, 0.3, 0.15))
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(nm)
	var q := Label.new()
	q.text = "×%d" % qty
	q.add_theme_font_size_override("font_size", 18)
	q.add_theme_color_override("font_color", Color(0.6, 0.42, 0.07))
	row.add_child(q)
	_item_list.add_child(row)


## 点击遮罩关闭。
func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close_requested.emit()
		hide()
