extends Control
## 主菜单：提供「开始游戏 / 设置 / 退出」入口。

signal start_requested
signal quit_requested

const SETTINGS_PANEL := preload("res://scenes/SettingsPanel.tscn")

@onready var _start_button: Button = $CenterContainer/VBoxContainer/StartButton
@onready var _settings_button: Button = $CenterContainer/VBoxContainer/SettingsButton
@onready var _quit_button: Button = $CenterContainer/VBoxContainer/QuitButton

var _settings_panel: Control = null


func _ready() -> void:
	_start_button.pressed.connect(func() -> void: start_requested.emit())
	_settings_button.pressed.connect(_on_settings_pressed)
	_quit_button.pressed.connect(func() -> void: quit_requested.emit())

	_settings_panel = SETTINGS_PANEL.instantiate()
	add_child(_settings_panel)
	_settings_panel.visible = false
	_settings_panel.close_requested.connect(func() -> void: _settings_panel.visible = false)


## 打开设置面板。
func _on_settings_pressed() -> void:
	_settings_panel.open()
