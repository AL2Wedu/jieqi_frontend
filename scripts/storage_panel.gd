extends Control
## 收成仓面板：列出仓内作物数量与当前收购价，支持出售。
## 数据来源 GET /v1/shop/storage → { season, items:[{crop_id, name, quantity, sell_price, season}] }。

signal close_requested
signal assets_changed

@onready var _season_label: Label = %SeasonLabel
@onready var _item_list: ItemList = %ItemList
@onready var _hint: Label = %Hint
@onready var _close: Button = %CloseButton
@onready var _dim: ColorRect = %Dim
@onready var _sell_label: Label = %SellLabel
@onready var _sell_one: Button = %SellOneButton
@onready var _sell_all: Button = %SellAllButton

# 与 ItemList 行一一对应：crop_id / 名称 / 数量 / 单价
var _crop_ids: Array[String] = []
var _crop_names: Array[String] = []
var _quantities: Array[int] = []
var _prices: Array[int] = []
var _selected := -1


func _ready() -> void:
	_close.pressed.connect(func() -> void: close_requested.emit())
	_close.pressed.connect(func() -> void: hide())
	_dim.gui_input.connect(_on_dim_input)
	_item_list.item_selected.connect(_on_item_selected)
	_sell_one.pressed.connect(_sell_selected_one)
	_sell_all.pressed.connect(_sell_selected_all)


## 打开面板并拉取收成仓数据。
func open() -> void:
	# 防御：节点未初始化完（onready 未赋值）时直接返回，避免空指针。
	if _item_list == null or _hint == null or _season_label == null:
		return
	visible = true
	_item_list.clear()
	_selected = -1
	_update_sell_ui()
	_hint.text = "加载中…"
	_hint.visible = true
	await _refresh()


func _refresh() -> void:
	var res := await Backend.get_storage()
	if not is_instance_valid(self):
		return
	if res.get("code", -1) != 0:
		_hint.text = "无法连接服务器，请稍后再试"
		return
	var data: Dictionary = res["data"]
	_season_label.text = "当前时节 · %s" % str(data.get("season", ""))
	_item_list.clear()
	_crop_ids.clear()
	_crop_names.clear()
	_quantities.clear()
	_prices.clear()
	var items: Array = data.get("items", [])
	if items.is_empty():
		_hint.text = "收成仓空空如也，快去收获作物吧～"
		_hint.visible = true
		_selected = -1
		_update_sell_ui()
		return
	_hint.visible = false
	for it in items:
		var d: Dictionary = it
		var name := str(d.get("name", ""))
		var qty: int = int(d.get("quantity", 0))
		var price: int = int(d.get("sell_price", 0))
		_item_list.add_item("%s × %d（%d 金币/株）" % [name, qty, price])
		_crop_ids.append(str(d.get("crop_id", "")))
		_crop_names.append(name)
		_quantities.append(qty)
		_prices.append(price)
	if _selected >= _item_list.item_count:
		_selected = -1
	_update_sell_ui()


func _on_item_selected(index: int) -> void:
	_selected = index
	_update_sell_ui()


func _update_sell_ui() -> void:
	var has := _selected >= 0 and _selected < _crop_ids.size()
	_sell_one.disabled = not has
	_sell_all.disabled = not has
	if has:
		_sell_label.text = "%s（%d 金币/株）" % [_crop_names[_selected], _prices[_selected]]
	else:
		_sell_label.text = "未选择作物"


func _sell_selected_one() -> void:
	await _sell_amount(1)


func _sell_selected_all() -> void:
	await _sell_amount(_quantities[_selected] if _selected >= 0 else 0)


func _sell_amount(quantity: int) -> void:
	if _selected < 0 or quantity <= 0:
		return
	var crop_id := _crop_ids[_selected]
	_hint.visible = true
	_hint.text = "出售中…"
	var res := await Backend.sell_crop(crop_id, quantity)
	if not is_instance_valid(self):
		return
	if res.get("code", -1) != 0:
		_hint.visible = true
		_hint.text = Backend.friendly_message(res, "出售失败")
		return
	_hint.text = ""
	assets_changed.emit()
	await _refresh()


## 点击遮罩关闭。
func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close_requested.emit()
		hide()
