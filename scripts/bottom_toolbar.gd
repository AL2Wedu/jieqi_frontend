class_name BottomToolbar
extends PanelContainer
## 底部木质操作栏：播种/灌溉/施肥/除草/收割。

signal action_selected(action_name: String)

const ACTIONS := [
	{ "name": "播种", "icon": "res://assets/icons/action_seed.svg" },
	{ "name": "灌溉", "icon": "res://assets/icons/action_irrigate.svg" },
	{ "name": "施肥", "icon": "res://assets/icons/action_fertilize.svg" },
	{ "name": "除草", "icon": "res://assets/icons/action_weed.svg" },
	{ "name": "收割", "icon": "res://assets/icons/action_harvest.svg" },
]

@onready var _row: HBoxContainer = %Row


func _ready() -> void:
	for i in ACTIONS.size():
		_row.add_child(_make_button(ACTIONS[i]))


func _make_button(data: Dictionary) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(96, 84)
	btn.focus_mode = Control.FOCUS_NONE

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	# 让内容占满按钮并居中
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(box)

	var icon := TextureRect.new()
	icon.texture = load(data["icon"]) as Texture2D
	icon.custom_minimum_size = Vector2(40, 40)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	box.add_child(icon)

	var label := Label.new()
	label.text = data["name"]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	label.add_theme_color_override("font_color", Color(0.42, 0.3, 0.15))
	label.add_theme_font_size_override("font_size", 22)
	box.add_child(label)

	btn.pressed.connect(func() -> void: action_selected.emit(data["name"]))

	var bg := Color(0.94, 0.82, 0.6)
	for p in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(16)
		sb.border_width_left = 3
		sb.border_width_top = 3
		sb.border_width_right = 3
		sb.border_width_bottom = 3
		sb.border_color = Color(0.6, 0.43, 0.24)
		sb.bg_color = bg
		sb.shadow_color = Color(0.25, 0.17, 0.09, 0.3)
		sb.shadow_size = 3
		if p == "hover":
			sb.bg_color = bg.lightened(0.06)
		elif p == "pressed":
			sb.bg_color = bg.darkened(0.06)
		btn.add_theme_stylebox_override(p, sb)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return btn
