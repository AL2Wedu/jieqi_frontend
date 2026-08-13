extends Control
## 登录/注册界面：调用后端认证接口，成功后发出 login_success。

signal login_success
signal back_requested

@onready var _name_edit: LineEdit = %NameEdit
@onready var _password_edit: LineEdit = %PasswordEdit
@onready var _error_label: Label = %ErrorLabel

var _pending_error := ""


func _ready() -> void:
	%LoginButton.pressed.connect(_on_login_pressed)
	%RegisterButton.pressed.connect(_on_register_pressed)
	%BackButton.pressed.connect(func() -> void: back_requested.emit())
	_password_edit.text_submitted.connect(func(_t: String) -> void: _on_login_pressed())
	if _pending_error != "":
		_set_error(_pending_error)


func _on_login_pressed() -> void:
	var name := _name_edit.text.strip_edges()
	var password := _password_edit.text
	if name == "" or password == "":
		_set_error("请输入名字和密码")
		return
	_set_error("")
	var res := await Backend.login(name, password)
	_handle_auth_result(res, false)


func _on_register_pressed() -> void:
	var name := _name_edit.text.strip_edges()
	var password := _password_edit.text
	if name == "" or password == "":
		_set_error("请输入名字和密码")
		return
	if password.length() < 6:
		_set_error("密码至少 6 位")
		return
	_set_error("")
	var res := await Backend.register(name, password)
	_handle_auth_result(res, true)


func _handle_auth_result(res: Dictionary, is_register: bool) -> void:
	if res.get("code", -1) != 0:
		var error_code := str(res.get("error_code", ""))
		var message := str(res.get("message", ""))
		if error_code == "USER_EXISTS":
			_set_error("该名字已被注册，试试登录")
		elif error_code == "BAD_CREDENTIALS":
			_set_error("密码错误")
		elif error_code == "USER_BANNED":
			_set_error("账号已被封禁")
		elif res.get("code", -1) == -1:
			_set_error(message if message != "" else "无法连接服务器")
		else:
			_set_error(message if message != "" else "操作失败，请重试")
		return

	var data: Dictionary = res["data"]
	Backend.on_login_success(str(data.get("token", "")), data.get("player", {}))
	login_success.emit()


## 在进入场景前也可调用；未就绪时先缓存，_ready 后展示。
func show_error(text: String) -> void:
	if _error_label == null:
		_pending_error = text
	else:
		_set_error(text)


func _set_error(text: String) -> void:
	_error_label.text = text
