extends Control
## 根场景：负责在「主菜单 / 登录 / 游戏」之间切换。
## 也统一处理安卓返回键（NOTIFICATION_WM_GO_BACK_REQUEST）。

const MAIN_MENU_SCENE: PackedScene = preload("res://scenes/MainMenu.tscn")
const LOGIN_SCENE: PackedScene = preload("res://scenes/Login.tscn")
const GAME_SCENE: PackedScene = preload("res://scenes/Game.tscn")

var _current_scene: Node = null


func _ready() -> void:
	Backend.auth_expired.connect(_on_auth_expired)
	show_main_menu()


## 安卓返回键：系统通知（独立于 ui_cancel 输入事件通路）。
## 各场景的返回键处理：关闭最上层面板由场景内 _unhandled_input(ui_cancel) 完成，
## 这里只处理“无面板可关、需要返回上一页”的层级导航；命中后 set_input_as_handled。
func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST:
		return
	_handle_android_back()


func _handle_android_back() -> void:
	var scene := _current_scene
	if scene == null:
		return
	# 把返回意图交给当前场景：它先关面板（返回 true = 已消费），否则导航回上一页
	if scene.has_method("handle_android_back") and scene.handle_android_back():
		return
	# 无面板可关：主菜单 → 直接退出；登录/游戏 → 回主菜单
	if scene.name.begins_with("MainMenu"):
		get_tree().quit()
	elif scene.name.begins_with("Login"):
		show_main_menu()
	else:
		_back_from_scene(scene)


## 从当前场景退回主菜单。
func _back_from_scene(scene: Node) -> void:
	if scene.name.begins_with("Game"):
		_switch_to(show_main_menu_instant())
	elif scene.name.begins_with("Login"):
		show_main_menu()


## 切换到主菜单。
func show_main_menu() -> void:
	_switch_to(show_main_menu_instant())


func show_main_menu_instant() -> Control:
	var menu := MAIN_MENU_SCENE.instantiate()
	menu.start_requested.connect(_on_start_requested)
	menu.quit_requested.connect(_on_quit_requested)
	return menu


## 玩家 token 失效（401）：切回登录页并提示重新登录。
func _on_auth_expired() -> void:
	var login := LOGIN_SCENE.instantiate()
	login.login_success.connect(_open_game)
	login.back_requested.connect(show_main_menu)
	login.show_error("登录已失效，请重新登录")
	_switch_to(login)


## 开始游戏：有本地 token 直接进游戏，否则先登录。
func _on_start_requested() -> void:
	if Backend.has_token():
		_open_game()
	else:
		var login := LOGIN_SCENE.instantiate()
		login.login_success.connect(_open_game)
		login.back_requested.connect(show_main_menu)
		_switch_to(login)


func _open_game() -> void:
	var game := GAME_SCENE.instantiate()
	game.back_to_menu_requested.connect(show_main_menu)
	_switch_to(game)


## 退出游戏。
func _on_quit_requested() -> void:
	get_tree().quit()


## 移除当前场景，挂载新场景。
func _switch_to(new_scene: Node) -> void:
	if _current_scene != null:
		_current_scene.queue_free()
	_current_scene = new_scene
	add_child(_current_scene)
