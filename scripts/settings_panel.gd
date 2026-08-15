extends Control
## 主菜单设置面板：服务器地址 / 音乐 / 音效 / 兑换码 / 个人管理 / 登出 / 关于。
## 兑换码、改名、注销等后端接口陆续添加，当前为占位。
## 登出/注销需二次确认；登出成功后发 logged_out 由上层导航回主页面。

signal close_requested
signal logged_out

@onready var _server_input: LineEdit = %ServerInput
@onready var _server_save: Button = %ServerSave
@onready var _server_status: Label = %ServerStatus
@onready var _music_toggle: CheckButton = %MusicToggle
@onready var _sfx_toggle: CheckButton = %SfxToggle
@onready var _redeem_input: LineEdit = %RedeemInput
@onready var _redeem_btn: Button = %RedeemBtn
@onready var _redeem_status: Label = %RedeemStatus
@onready var _uid_label: Label = %UidLabel
@onready var _rename_btn: Button = %RenameBtn
@onready var _delete_btn: Button = %DeleteBtn
@onready var _logout_btn: Button = %LogoutButton
@onready var _logout_status: Label = %LogoutStatus
@onready var _about: Label = %AboutLabel
@onready var _close: Button = %CloseButton
@onready var _dim: ColorRect = %Dim
@onready var _confirm_overlay: Control = %ConfirmOverlay
@onready var _confirm_text: Label = %ConfirmText
@onready var _confirm_ok: Button = %ConfirmOk
@onready var _confirm_cancel: Button = %ConfirmCancel

var _confirm_action: Callable = Callable()


func _ready() -> void:
	_close.pressed.connect(func() -> void: close_requested.emit())
	_close.pressed.connect(func() -> void: hide())
	_dim.gui_input.connect(_on_dim_input)
	_server_save.pressed.connect(_on_server_save)
	_server_input.text_submitted.connect(func(_t: String) -> void: _on_server_save())
	_music_toggle.toggled.connect(func(on: bool) -> void: Backend.set_music_enabled(on))
	_sfx_toggle.toggled.connect(func(on: bool) -> void: Backend.set_sfx_enabled(on))
	_redeem_btn.pressed.connect(_on_redeem)
	_redeem_input.text_submitted.connect(func(_t: String) -> void: _on_redeem())
	_rename_btn.pressed.connect(func() -> void: _placeholder("改名功能开发中，敬请期待～"))
	_delete_btn.pressed.connect(_on_delete_pressed)
	_logout_btn.pressed.connect(_on_logout_pressed)
	_confirm_ok.pressed.connect(_on_confirm_ok)
	_confirm_cancel.pressed.connect(_on_confirm_cancel)
	_about.text = "节气造物主  v%s\n二十四节气 · 模拟经营" % Backend.APP_VERSION


func open() -> void:
	visible = true
	_confirm_overlay.visible = false
	_server_input.text = Backend.base_url
	_server_status.text = ""
	_music_toggle.button_pressed = Backend.is_music_enabled()
	_sfx_toggle.button_pressed = Backend.is_sfx_enabled()
	_redeem_status.text = ""
	var pid := str(Backend.player.get("player_id", ""))
	_uid_label.text = "用户ID：%s" % (pid if pid != "" else "-")
	_logout_status.text = "已登录" if Backend.has_token() else "未登录"


## 保存服务器地址并立即生效。
func _on_server_save() -> void:
	if _server_input.text.strip_edges() == "":
		_server_status.text = "地址不能为空"
		return
	Backend.set_server(_server_input.text)
	_server_status.text = "已保存：%s" % Backend.base_url


## 兑换码：后端接口待添加，先占位提示。
func _on_redeem() -> void:
	if _redeem_input.text.strip_edges() == "":
		_redeem_status.text = "请输入兑换码"
		return
	_redeem_status.text = "兑换码功能开发中，敬请期待～"


func _placeholder(text: String) -> void:
	_logout_status.text = text


## 登出：二次确认后执行，成功后通知上层导航回主页面。
func _on_logout_pressed() -> void:
	if not Backend.has_token():
		_logout_status.text = "当前未登录"
		return
	_ask_confirm("确定要登出账号吗？", _do_logout)


func _do_logout() -> void:
	Backend.logout()
	_logout_status.text = "已登出"
	close_requested.emit()
	hide()
	logged_out.emit()


## 注销账号：后端接口待添加，二次确认后占位提示。
func _on_delete_pressed() -> void:
	_ask_confirm("注销后账号将被删除，确定要注销吗？", func() -> void:
		_placeholder("注销功能开发中，敬请期待～"))


## 弹出确认框，确认后执行 action。
func _ask_confirm(text: String, action: Callable) -> void:
	_confirm_action = action
	_confirm_text.text = text
	_confirm_overlay.visible = true


func _on_confirm_ok() -> void:
	_confirm_overlay.visible = false
	var act := _confirm_action
	_confirm_action = Callable()
	if act.is_valid():
		act.call()


func _on_confirm_cancel() -> void:
	_confirm_overlay.visible = false
	_confirm_action = Callable()


## 点击遮罩关闭。
func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close_requested.emit()
		hide()
