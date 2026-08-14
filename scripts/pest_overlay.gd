extends Control
## 虫害交互面板：小虫害驱赶确认 + 大虫害来袭提示（最小化处理，不做音游）。

signal drive_away_confirmed(pest_id: String, plot_id: String)
signal auto_submit(pest_id: String)

@onready var _dim: ColorRect = %Dim
@onready var _title: Label = %TitleLabel
@onready var _message: Label = %MessageLabel
@onready var _countdown: Label = %CountdownLabel
@onready var _confirm: Button = %ConfirmButton
@onready var _cancel: Button = %CancelButton

var _pending_pest_id := ""
var _pending_plot_id := ""
var _countdown_sec := 0
var _countdown_timer: Timer = null


func _ready() -> void:
	_dim.gui_input.connect(_on_dim_input)
	_confirm.pressed.connect(_on_confirm)
	_cancel.pressed.connect(hide_all)
	hide_all()


func hide_all() -> void:
	visible = false
	_countdown.visible = false
	_confirm.visible = false
	_cancel.visible = false


## 小虫害驱赶确认弹窗。
func ask_drive_away(pest_id: String, plot_id: String, crop_name: String) -> void:
	_pending_pest_id = pest_id
	_pending_plot_id = plot_id
	_title.text = "驱赶害虫"
	_message.text = "%s 上寄生了害虫，是否驱赶？" % crop_name
	_countdown.visible = false
	_confirm.text = "驱赶"
	_confirm.visible = true
	_cancel.visible = true
	visible = true


## 大虫害来袭：倒计时到 0 自动提交成绩（音游暂未实现，弃战）。
func show_big(payload: Dictionary) -> void:
	_pending_pest_id = str(payload.get("pest_id", ""))
	var duration := int(payload.get("duration_seconds", 30))
	var elapsed := int(payload.get("elapsed_seconds", 0))
	_countdown_sec = maxi(0, duration - elapsed)
	_title.text = "大虫害来袭！"
	_message.text = "害虫正在破坏你的农田，自动驱赶中…"
	_countdown.visible = true
	_countdown.text = "%ds" % _countdown_sec
	_confirm.visible = false
	_cancel.visible = false
	visible = true
	_start_countdown()


func _start_countdown() -> void:
	if _countdown_timer == null:
		_countdown_timer = Timer.new()
		_countdown_timer.wait_time = 1.0
		_countdown_timer.timeout.connect(_tick_countdown)
		add_child(_countdown_timer)
	_countdown_timer.start()


func _tick_countdown() -> void:
	_countdown_sec = maxi(0, _countdown_sec - 1)
	_countdown.text = "%ds" % _countdown_sec
	if _countdown_sec <= 0:
		_countdown_timer.stop()
		hide_all()
		auto_submit.emit(_pending_pest_id)


func _on_confirm() -> void:
	hide_all()
	drive_away_confirmed.emit(_pending_pest_id, _pending_plot_id)


func _on_dim_input(event: InputEvent) -> void:
	# 驱赶确认面板：点遮罩 = 取消；大虫害倒计时面板不可点掉
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT and _confirm.visible:
		hide_all()
