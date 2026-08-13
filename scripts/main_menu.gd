extends Control
## 主菜单：提供「开始游戏 / 设置 / 退出」入口。

signal start_requested
signal quit_requested

@onready var _start_button: Button = $CenterContainer/VBoxContainer/StartButton
@onready var _settings_button: Button = $CenterContainer/VBoxContainer/SettingsButton
@onready var _quit_button: Button = $CenterContainer/VBoxContainer/QuitButton


func _ready() -> void:
	_start_button.pressed.connect(func() -> void: start_requested.emit())
	_settings_button.pressed.connect(_on_settings_pressed)
	_quit_button.pressed.connect(func() -> void: quit_requested.emit())


## 设置界面尚未实现，先打桩。
func _on_settings_pressed() -> void:
	print("[主菜单] 设置按钮被点击（占位）")
