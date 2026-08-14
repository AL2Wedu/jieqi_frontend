extends Control
## 真实商店：购买商品（库存/售价）+ 查看作物收购价（季节涨降）。

signal close_requested
signal assets_changed

@onready var _season_label: Label = %SeasonLabel
@onready var _items_tab: Button = %ItemsTab
@onready var _quotes_tab: Button = %QuotesTab
@onready var _items_scroll: ScrollContainer = %ItemsScroll
@onready var _quotes_scroll: ScrollContainer = %QuotesScroll
@onready var _items_list: VBoxContainer = %ItemsList
@onready var _quotes_list: VBoxContainer = %QuotesList
@onready var _hint: Label = %Hint
@onready var _close: Button = %CloseButton
@onready var _dim: ColorRect = %Dim


func _ready() -> void:
	_close.pressed.connect(func() -> void: close_requested.emit())
	_close.pressed.connect(func() -> void: hide())
	_dim.gui_input.connect(_on_dim_input)
	_items_tab.pressed.connect(func() -> void: _show_tab(true))
	_quotes_tab.pressed.connect(func() -> void: _show_tab(false))
	_show_tab(true)


## 打开商店并拉取数据。
func open() -> void:
	visible = true
	_hint.visible = true
	_hint.text = "加载中…"
	await _refresh()


func _refresh() -> void:
	var res := await Backend.get_shop_state()
	if not is_instance_valid(self):
		return
	if res.get("code", -1) != 0:
		_hint.visible = true
		_hint.text = Backend.friendly_message(res, "加载失败")
		return
	var data: Dictionary = res["data"]
	_season_label.text = "当前时节 · %s（每 %d 秒补货）" % [
		str(data.get("season", "")), int(data.get("restock_seconds", 0))]
	_fill_items(data.get("items", []))
	_fill_quotes(data.get("crop_quotes", []))
	_hint.visible = false


func _show_tab(items: bool) -> void:
	_items_scroll.visible = items
	_quotes_scroll.visible = not items
	_items_tab.button_pressed = items
	_quotes_tab.button_pressed = not items


func _clear_list(list_node: VBoxContainer) -> void:
	for child in list_node.get_children():
		list_node.remove_child(child)
		child.queue_free()


## 商品行：名称 + 单价 + 库存 + 买。
func _fill_items(items: Array) -> void:
	_clear_list(_items_list)
	for item in items:
		var d: Dictionary = item
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var name := Label.new()
		name.text = "%s" % str(d.get("name", ""))
		name.custom_minimum_size = Vector2(200, 0)
		name.add_theme_font_size_override("font_size", 18)
		name.add_theme_color_override("font_color", Color(0.42, 0.3, 0.15))
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name)
		var price := Label.new()
		price.text = "%d 金币" % int(d.get("buy_price", 0))
		price.add_theme_font_size_override("font_size", 17)
		price.add_theme_color_override("font_color", Color(0.6, 0.42, 0.07))
		row.add_child(price)
		var stock := Label.new()
		stock.text = "×%d" % int(d.get("stock", 0))
		stock.add_theme_font_size_override("font_size", 17)
		stock.add_theme_color_override("font_color", Color(0.55, 0.42, 0.2))
		row.add_child(stock)
		var btn := Button.new()
		btn.text = "买"
		btn.custom_minimum_size = Vector2(60, 40)
		btn.focus_mode = Control.FOCUS_NONE
		var item_id := str(d.get("item_id", ""))
		var sold_out: bool = int(d.get("stock", 0)) <= 0
		btn.disabled = sold_out
		btn.pressed.connect(_buy.bind(item_id))
		row.add_child(btn)
		_items_list.add_child(row)


func _buy(item_id: String) -> void:
	_hint.visible = true
	_hint.text = "购买中…"
	var res := await Backend.buy(item_id, 1)
	if not is_instance_valid(self):
		return
	if res.get("code", -1) != 0:
		_hint.visible = true
		_hint.text = Backend.friendly_message(res, "购买失败")
		return
	_hint.text = ""
	assets_changed.emit()
	await _refresh()


## 收购价行：名称 + 分类 + 单价 + 季节系数。
func _fill_quotes(quotes: Array) -> void:
	_clear_list(_quotes_list)
	for q in quotes:
		var d: Dictionary = q
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var name := Label.new()
		name.text = "%s（%s）" % [str(d.get("name", "")), str(d.get("category", ""))]
		name.custom_minimum_size = Vector2(200, 0)
		name.add_theme_font_size_override("font_size", 18)
		name.add_theme_color_override("font_color", Color(0.42, 0.3, 0.15))
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name)
		var price := Label.new()
		price.text = "%d 金币/株" % int(d.get("sell_price", 0))
		price.add_theme_font_size_override("font_size", 17)
		price.add_theme_color_override("font_color", Color(0.6, 0.42, 0.07))
		row.add_child(price)
		var factor := Label.new()
		factor.text = "x%s" % str(d.get("season_factor", 1.0))
		factor.add_theme_font_size_override("font_size", 16)
		factor.add_theme_color_override("font_color", Color(0.55, 0.42, 0.2))
		row.add_child(factor)
		_quotes_list.add_child(row)


## 点击遮罩关闭。
func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close_requested.emit()
		hide()
