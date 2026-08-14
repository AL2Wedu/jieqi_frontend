extends Control
## 主菜单：提供「开始游戏 / 设置 / 退出」入口。

signal start_requested
signal quit_requested

const SETTINGS_PANEL := preload("res://scenes/SettingsPanel.tscn")

@onready var _start_button: Button = $MenuBox/VBoxContainer/StartButton
@onready var _settings_button: Button = $MenuBox/VBoxContainer/SettingsButton
@onready var _quit_button: Button = $MenuBox/VBoxContainer/QuitButton

var _settings_panel: Control = null


func _ready() -> void:
	_start_button.pressed.connect(func() -> void: start_requested.emit())
	_settings_button.pressed.connect(_on_settings_pressed)
	_quit_button.pressed.connect(func() -> void: quit_requested.emit())

	_settings_panel = SETTINGS_PANEL.instantiate()
	add_child(_settings_panel)
	_settings_panel.visible = false
	_settings_panel.close_requested.connect(func() -> void: _settings_panel.visible = false)

	for btn in [_start_button, _settings_button, _quit_button]:
		_style_press(btn)


## 按钮按压反馈：按下轻微缩小、抬起回弹。
func _style_press(btn: Button) -> void:
	btn.button_down.connect(func() -> void:
		if btn.pivot_offset == Vector2.ZERO and btn.size != Vector2.ZERO:
			btn.pivot_offset = btn.size / 2.0
		var tw := create_tween()
		tw.tween_property(btn, "scale", Vector2(0.94, 0.94), 0.07))
	btn.button_up.connect(func() -> void:
		var tw := create_tween()
		tw.tween_property(btn, "scale", Vector2.ONE, 0.12))


## 打开设置面板。
func _on_settings_pressed() -> void:
	_settings_panel.open()


## 设置面板开着时，Esc / 安卓返回先关面板。
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _settings_panel != null and _settings_panel.visible:
			get_viewport().set_input_as_handled()
			_settings_panel.visible = false
			return


## 安卓返回键（系统通知通路）：设置面板开着先关面板；否则返回 true 表示主菜单将退出。
func handle_android_back() -> bool:
	if _settings_panel != null and _settings_panel.visible:
		_settings_panel.visible = false
		return true
	return false
