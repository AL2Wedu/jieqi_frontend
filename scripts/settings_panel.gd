extends Control
## 主菜单设置面板：服务器地址 / 音乐 / 音效 / 登出 / 关于。

signal close_requested

@onready var _server_input: LineEdit = %ServerInput
@onready var _server_save: Button = %ServerSave
@onready var _server_status: Label = %ServerStatus
@onready var _music_toggle: CheckButton = %MusicToggle
@onready var _sfx_toggle: CheckButton = %SfxToggle
@onready var _logout_btn: Button = %LogoutButton
@onready var _logout_status: Label = %LogoutStatus
@onready var _about: Label = %AboutLabel
@onready var _close: Button = %CloseButton
@onready var _dim: ColorRect = %Dim


func _ready() -> void:
	_close.pressed.connect(func() -> void: close_requested.emit())
	_close.pressed.connect(func() -> void: hide())
	_dim.gui_input.connect(_on_dim_input)
	_server_save.pressed.connect(_on_server_save)
	_server_input.text_submitted.connect(func(_t: String) -> void: _on_server_save())
	_music_toggle.toggled.connect(func(on: bool) -> void: Backend.set_music_enabled(on))
	_sfx_toggle.toggled.connect(func(on: bool) -> void: Backend.set_sfx_enabled(on))
	_logout_btn.pressed.connect(_on_logout)
	_about.text = "节气造物主  v%s\n二十四节气 · 模拟经营" % Backend.APP_VERSION


func open() -> void:
	visible = true
	_server_input.text = Backend.base_url
	_server_status.text = ""
	_music_toggle.button_pressed = Backend.is_music_enabled()
	_sfx_toggle.button_pressed = Backend.is_sfx_enabled()
	_logout_status.text = "已登录" if Backend.has_token() else "未登录"


## 保存服务器地址并立即生效。
func _on_server_save() -> void:
	if _server_input.text.strip_edges() == "":
		_server_status.text = "地址不能为空"
		return
	Backend.set_server(_server_input.text)
	_server_status.text = "已保存：%s" % Backend.base_url


## 登出：清除本地 token，下次开始游戏需重新登录。
func _on_logout() -> void:
	if Backend.has_token():
		Backend.logout()
		_logout_status.text = "已登出"
	else:
		_logout_status.text = "当前未登录"


## 点击遮罩关闭。
func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close_requested.emit()
		hide()
