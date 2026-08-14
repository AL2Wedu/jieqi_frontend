extends Control
## 播种选作物弹窗：从商店拉取种子（含库存/宜种/解锁），点选后发出 picked。

signal picked(seed_item: Dictionary)

@onready var _seed_list: VBoxContainer = %SeedList
@onready var _hint: Label = %Hint


func _ready() -> void:
	%CloseButton.pressed.connect(_close)
	$Dim.gui_input.connect(_on_dim_input)


## 打开弹窗并加载商店种子列表（get_shop_state 含库存与作物配置）。
func open() -> void:
	visible = true
	_clear_seed_list()
	_hint.visible = true
	_hint.text = "加载中…"
	var res := await Backend.get_shop_state()
	if not visible:
		return  # 等待期间被关闭
	_hint.visible = false
	if res.get("code", -1) != 0:
		_hint.visible = true
		_hint.text = "获取商店失败：" + str(res.get("message", "未知错误"))
		return
	var data: Dictionary = res["data"]
	var term_index: int = int(Backend.current_term.get("term_index", 1))  # 后端 1-24
	var player_level: int = int(Backend.player.get("level", 1))
	var player_exp: int = int(Backend.player.get("exp", 0))
	# crop_id -> 作物收购价配置（含 art / sow_window / unlock）
	var quotes := {}
	for q in data.get("crop_quotes", []):
		var qd: Dictionary = q
		quotes[str(qd.get("crop_id", ""))] = qd
	for item in data.get("items", []):
		var it: Dictionary = item
		if it.get("category", "") != "seed":
			continue
		var effect: Dictionary = it.get("effect", {})
		var crop_id := str(effect.get("crop_id", ""))
		var quote: Dictionary = quotes.get(crop_id, {})
		_seed_list.add_child(_make_item_button(it, quote, term_index, player_level, player_exp))
	if _seed_list.get_child_count() == 0:
		_hint.visible = true
		_hint.text = "商店里没有可种的作物"


func _clear_seed_list() -> void:
	for child in _seed_list.get_children():
		_seed_list.remove_child(child)
		child.queue_free()


func _make_item_button(item: Dictionary, quote: Dictionary, term_index: int, level: int, exp: int) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 56)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", Color(0.42, 0.3, 0.15))
	var name: String = item.get("name", "")
	var price: Variant = item.get("buy_price", 0)
	var stock: int = int(item.get("stock", 0))

	var suitable := _crop_suitable(quote.get("sow_window", {}), term_index)
	var unlock_level := int(quote.get("unlock_level", 0))
	var unlock_exp := int(quote.get("unlock_exp", 0))
	var exp_ok := unlock_exp <= 0 or exp >= unlock_exp
	var lvl_ok := unlock_level <= 0 or level >= unlock_level
	var locked := not (exp_ok or lvl_ok)
	var sold_out := stock <= 0
	var disabled := not suitable or locked or sold_out
	btn.disabled = disabled

	var badge := ""
	if not suitable:
		badge = "（当前节气不宜种）"
	elif locked:
		badge = "（未解锁）"
	elif sold_out:
		badge = "（售罄）"
	btn.text = "%s · %d 金币 · ×%d%s" % [name, int(price), stock, badge]

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
	var sb_dis := sb.duplicate()
	sb_dis.bg_color = Color(0.75, 0.7, 0.6, 1)
	btn.add_theme_stylebox_override("disabled", sb_dis)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	if not disabled:
		btn.pressed.connect(func() -> void:
			picked.emit(item)
			_close())

	# 异步加载种子图标（失败则仅文字）
	if not quote.is_empty():
		_load_icon(btn, quote)
	return btn


## 宜种校验（与后端 farm_service._check_sow_window 一致）。term_index 为 1-24。
func _crop_suitable(win: Dictionary, term_index: int) -> bool:
	if win.get("type") == "term":
		var start := int(win.get("start", 1))
		var end := int(win.get("end", 24))
		var grace := int(win.get("grace", 0))
		if start <= term_index and term_index <= end:
			return true
		return end < term_index and term_index <= end + grace
	if win.get("type") == "season":
		var season := (term_index - 1) / 6 + 1
		var names := { 1: "春", 2: "夏", 3: "秋", 4: "冬" }
		for s in win.get("seasons", []):
			if str(s) == str(names.get(season, "")):
				return true
		return false
	return true  # 未配置窗口视为随时可种


func _load_icon(btn: Button, quote: Dictionary) -> void:
	var tex := await Backend.get_seed_art_texture(quote, 64)
	if tex != null and is_instance_valid(btn):
		btn.icon = tex
		btn.icon_max_width = 40


func _close() -> void:
	visible = false


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_close()
