extends Control
## 任务面板：列出任务与实时进度，可领取奖励。
## 数据来源 GET /v1/quests → { items:[{quest_id, code, name, description, category, reward, status, progress}] }。

signal close_requested
signal assets_changed

@onready var _item_list: VBoxContainer = %ItemList
@onready var _hint: Label = %Hint
@onready var _close: Button = %CloseButton
@onready var _dim: ColorRect = %Dim


func _ready() -> void:
	_close.pressed.connect(func() -> void: close_requested.emit())
	_close.pressed.connect(func() -> void: hide())
	_dim.gui_input.connect(_on_dim_input)


func open() -> void:
	visible = true
	_hint.visible = true
	_hint.text = "加载中…"
	await _refresh()


func _refresh() -> void:
	var res := await Backend.get_quests()
	if not is_instance_valid(self):
		return
	if res.get("code", -1) != 0:
		_hint.visible = true
		_hint.text = Backend.friendly_message(res, "加载失败")
		return
	_clear_list()
	var items: Array = res["data"].get("items", [])
	if items.is_empty():
		_hint.visible = true
		_hint.text = "暂时没有任务"
		return
	_hint.visible = false
	for item in items:
		_add_row(item)


func _clear_list() -> void:
	for child in _item_list.get_children():
		_item_list.remove_child(child)
		child.queue_free()


func _add_row(item: Variant) -> void:
	var d: Dictionary = item
	var status: int = int(d.get("status", 0))
	var progress: Dictionary = d.get("progress", {})
	var cur: int = int(progress.get("current", 0))
	var target: int = int(progress.get("target", 1))
	var reward: Dictionary = d.get("reward", {})

	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 0.965, 0.871, 1)
	sb.set_corner_radius_all(14)
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.border_color = Color(0.784, 0.604, 0.373, 1)
	card.add_theme_stylebox_override("panel", sb)
	card.mouse_filter = Control.MOUSE_FILTER_PASS

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	# 标题行：名称 + 状态徽标
	var head := HBoxContainer.new()
	var name := Label.new()
	name.text = str(d.get("name", "?"))
	name.add_theme_font_size_override("font_size", 20)
	name.add_theme_color_override("font_color", Color(0.42, 0.3, 0.15))
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name)
	var badge := Label.new()
	match status:
		0:
			badge.text = "进行中"
			badge.add_theme_color_override("font_color", Color(0.55, 0.42, 0.2))
		1:
			badge.text = "可领取"
			badge.add_theme_color_override("font_color", Color(0.85, 0.55, 0.1))
		_:
			badge.text = "已领取"
			badge.add_theme_color_override("font_color", Color(0.45, 0.45, 0.45))
	badge.add_theme_font_size_override("font_size", 16)
	head.add_child(badge)
	vbox.add_child(head)

	var desc := Label.new()
	desc.text = str(d.get("description", ""))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 15)
	desc.add_theme_color_override("font_color", Color(0.55, 0.42, 0.2))
	vbox.add_child(desc)

	# 进度条
	var bar := ProgressBar.new()
	bar.max_value = maxi(1, target)
	bar.value = cur
	bar.custom_minimum_size = Vector2(0, 18)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.9, 0.85, 0.72, 1)
	bg.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("background", bg)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.29, 0.616, 0.878, 1)
	fill.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("fill", fill)
	vbox.add_child(bar)

	# 底部行：奖励 + 领取
	var foot := HBoxContainer.new()
	var reward_text := "奖励：金币 %d · 经验 %d" % [int(reward.get("coins", 0)), int(reward.get("exp", 0))]
	var rw := Label.new()
	rw.text = reward_text
	rw.add_theme_font_size_override("font_size", 15)
	rw.add_theme_color_override("font_color", Color(0.6, 0.42, 0.07))
	rw.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(rw)
	if status == 1:
		var claim := Button.new()
		claim.text = "领取"
		claim.custom_minimum_size = Vector2(90, 40)
		claim.focus_mode = Control.FOCUS_NONE
		claim.add_theme_color_override("font_color", Color(0.42, 0.3, 0.15))
		claim.add_theme_font_size_override("font_size", 18)
		var sb_btn := StyleBoxFlat.new()
		sb_btn.bg_color = Color(0.85, 0.68, 0.4, 1)
		sb_btn.set_corner_radius_all(14)
		sb_btn.border_width_left = 3
		sb_btn.border_width_top = 3
		sb_btn.border_width_right = 3
		sb_btn.border_width_bottom = 3
		sb_btn.border_color = Color(0.478, 0.322, 0.188, 1)
		claim.add_theme_stylebox_override("normal", sb_btn)
		var quest_id := str(d.get("quest_id", ""))
		claim.pressed.connect(_claim.bind(quest_id))
		foot.add_child(claim)
	vbox.add_child(foot)

	_item_list.add_child(card)


func _claim(quest_id: String) -> void:
	_hint.visible = true
	_hint.text = "领取中…"
	var res := await Backend.claim_quest(quest_id)
	if not is_instance_valid(self):
		return
	if res.get("code", -1) != 0:
		_hint.visible = true
		_hint.text = Backend.friendly_message(res, "领取失败")
		return
	_hint.text = ""
	assets_changed.emit()
	await _refresh()


## 点击遮罩关闭。
func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close_requested.emit()
		hide()
