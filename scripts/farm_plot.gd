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
var crop_key := ""  # 当前作物身份（<slug>|<stage>），用于检测地块内容是否变化

@onready var _crop_label: Label = %CropLabel
@onready var _lock_icon: TextureRect = %LockIcon
@onready var _pest_bubble: PanelContainer = %PestBubble
@onready var _weed_icon: TextureRect = %WeedIcon
@onready var _pest_countdown: PanelContainer = %PestCountdown
@onready var _pest_countdown_label: Label = %PestCountdownLabel
@onready var _soil: TextureRect = %Soil
@onready var _frame: TextureRect = %Frame
@onready var _crop_art: TextureRect = %CropArt


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


## 是否显示杂草（该地块作物生长减速）。
func set_weeded(has_weed: bool) -> void:
	_weed_icon.visible = has_weed


## 小虫害倒计时：remaining > 0 显示剩余秒；<= 0 隐藏。
func set_pest_countdown(remaining: int) -> void:
	_pest_countdown.visible = remaining > 0
	if remaining > 0:
		_pest_countdown_label.text = "%ds" % remaining


func set_selected(sel: bool) -> void:
	is_selected = sel
	_refresh()


## 显示作物贴图（替代文字）；传 null 时退回文字显示。
## EMPTY/LOCKED 状态即使有贴图也不显示（防止旧作物贴图残留）。
func set_crop_texture(tex: Texture2D) -> void:
	if tex == null:
		_crop_art.texture = null
		_crop_art.visible = false
		_crop_label.visible = state != PlotState.LOCKED and state != PlotState.EMPTY
	else:
		_crop_art.texture = tex
		var show := state != PlotState.LOCKED and state != PlotState.EMPTY
		_crop_art.visible = show
		_crop_label.visible = not show


## 设置作物贴图尺寸：stage 1 幼苗一倍（居中），stage 2/3 二倍（上移半格，盖在边框上方）。
func set_crop_stage_scale(stage: int) -> void:
	_crop_art.anchor_left = 0.5
	_crop_art.anchor_top = 0.5
	_crop_art.anchor_right = 0.5
	_crop_art.anchor_bottom = 0.5
	var half := 29.0
	var top := -29.0
	if stage >= 2:
		half = 58.0
		top = -100.0  # 二倍：上移约半格（42px）
	_crop_art.offset_left = -half
	_crop_art.offset_top = top
	_crop_art.offset_right = half
	_crop_art.offset_bottom = top + half * 2.0


## 清空作物贴图（地块换作物/清空时调用，避免旧贴图残留）。
func reset_crop_art() -> void:
	_crop_art.texture = null
	_refresh()


func _refresh() -> void:
	_soil.visible = state != PlotState.LOCKED
	_lock_icon.visible = state == PlotState.LOCKED
	var has_crop := state != PlotState.LOCKED and state != PlotState.EMPTY
	if _crop_art.texture == null:
		_crop_art.visible = false
		_crop_label.visible = has_crop
	else:
		_crop_art.visible = has_crop
		_crop_label.visible = false

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
