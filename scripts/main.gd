extends Control
## 根场景：负责在「主菜单 / 登录 / 游戏」之间切换。

const MAIN_MENU_SCENE: PackedScene = preload("res://scenes/MainMenu.tscn")
const LOGIN_SCENE: PackedScene = preload("res://scenes/Login.tscn")
const GAME_SCENE: PackedScene = preload("res://scenes/Game.tscn")

var _current_scene: Node = null


func _ready() -> void:
	Backend.auth_expired.connect(_on_auth_expired)
	show_main_menu()


## 切换到主菜单。
func show_main_menu() -> void:
	var menu := MAIN_MENU_SCENE.instantiate()
	menu.start_requested.connect(_on_start_requested)
	menu.quit_requested.connect(_on_quit_requested)
	_switch_to(menu)


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
