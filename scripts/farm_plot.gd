class_name FarmPlot
extends Button
## 一块农田。状态：空地/幼苗/叶菜/成熟/锁定；选中高亮；害虫提示。
## 视觉：土块贴图 + 边框贴图（正式美术资源）。

signal plot_clicked(plot: FarmPlot)

enum PlotState { EMPTY, SPROUT, LEAFY, MATURE, LOCKED }

const COLOR_LOCK := Color(0.94, 0.89, 0.75)
const COLOR_LOCK_EDGE := Color(0.78, 0.65, 0.45)

var state: int = PlotState.EMPTY
var is_selected: bool = false

@onready var _crop_label: Label = %CropLabel
@onready var _lock_icon: TextureRect = %LockIcon
@onready var _pest_bubble: PanelContainer = %PestBubble
@onready var _soil: TextureRect = %Soil
@onready var _frame: TextureRect = %Frame


func _ready() -> void:
	pressed.connect(func() -> void: plot_clicked.emit(self))
	_refresh()


## 设置地块状态，crop_name 用于显示作物文字（幼苗/叶菜/成熟）。
func set_plot_state(new_state: int, crop_name: String = "") -> void:
	state = new_state
	_crop_label.text = crop_name
	_refresh()


## 是否显示“害虫”感叹号。
func set_pest(has_pest: bool) -> void:
	_pest_bubble.visible = has_pest


func set_selected(sel: bool) -> void:
	is_selected = sel
	_refresh()


func _refresh() -> void:
	_soil.visible = state != PlotState.LOCKED
	_lock_icon.visible = state == PlotState.LOCKED
	_crop_label.visible = state != PlotState.LOCKED and state != PlotState.EMPTY

	var normal := StyleBoxFlat.new()
	normal.set_corner_radius_all(14)

	var hover := StyleBoxFlat.new()
	hover.set_corner_radius_all(14)
	var pressed := StyleBoxFlat.new()
	pressed.set_corner_radius_all(14)

	if state == PlotState.LOCKED:
		normal.bg_color = COLOR_LOCK
		normal.border_width_left = 3
		normal.border_width_top = 3
		normal.border_width_right = 3
		normal.border_width_bottom = 3
		normal.border_color = COLOR_LOCK_EDGE
	else:
		normal.bg_color = Color(1, 1, 1, 0)  # 透明，露出土块贴图
		# hover 时轻微提亮
		hover.bg_color = Color(1, 1, 1, 0.08)
		pressed.bg_color = Color(0, 0, 0, 0.08)

	if is_selected:
		var sel := StyleBoxFlat.new()
		sel.set_corner_radius_all(14)
		sel.bg_color = Color(1, 1, 1, 0)
		sel.border_width_left = 5
		sel.border_width_top = 5
		sel.border_width_right = 5
		sel.border_width_bottom = 5
		sel.border_color = Color(0.35, 0.85, 0.45, 1)
		sel.shadow_color = Color(0.3, 0.9, 0.4, 0.45)
		sel.shadow_size = 8
		normal = sel
		hover = sel.duplicate()
		pressed = sel.duplicate()

	add_theme_stylebox_override("normal", normal)
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("pressed", pressed)
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
