extends Control
## 收成仓查看面板（只读）：列出仓内作物数量与当前收购价。
## 数据来源 GET /v1/shop/storage → { season, items:[{crop_id, name, quantity, sell_price, season}] }。

signal close_requested

@onready var _season_label: Label = %SeasonLabel
@onready var _item_list: ItemList = %ItemList
@onready var _hint: Label = %Hint
@onready var _close: Button = %CloseButton
@onready var _dim: ColorRect = %Dim


func _ready() -> void:
	_close.pressed.connect(func() -> void: close_requested.emit())
	_close.pressed.connect(func() -> void: hide())
	_dim.gui_input.connect(_on_dim_input)


## 打开面板并拉取收成仓数据。
func open() -> void:
	# 防御：节点未初始化完（onready 未赋值）时直接返回，避免空指针。
	if _item_list == null or _hint == null or _season_label == null:
		return
	visible = true
	_item_list.clear()
	_hint.text = "加载中…"
	_hint.visible = true
	var res := await Backend.get_storage()
	if not is_instance_valid(self):
		return
	if res.get("code", -1) != 0:
		_hint.text = "无法连接服务器，请稍后再试"
		return
	var data: Dictionary = res["data"]
	_season_label.text = "当前时节 · %s" % str(data.get("season", ""))
	var items: Array = data.get("items", [])
	if items.is_empty():
		_hint.text = "收成仓空空如也，快去收获作物吧～"
		return
	_hint.visible = false
	for it in items:
		var d: Dictionary = it
		var name := str(d.get("name", ""))
		var qty: int = int(d.get("quantity", 0))
		var price: int = int(d.get("sell_price", 0))
		_item_list.add_item("%s × %d    售价 %d 金币/株" % [name, qty, price])


## 点击遮罩关闭。
func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close_requested.emit()
		hide()
