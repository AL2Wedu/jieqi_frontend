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
