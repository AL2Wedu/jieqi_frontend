extends Control
## 根场景：负责在「主菜单」与「游戏」之间切换。
##
## 后续若要加读档、加载过渡、全局状态等，都可以挂在这里统一管理。

const MAIN_MENU_SCENE: PackedScene = preload("res://scenes/MainMenu.tscn")
const GAME_SCENE: PackedScene = preload("res://scenes/Game.tscn")

var _current_scene: Node = null


func _ready() -> void:
	show_main_menu()


## 切换到主菜单。
func show_main_menu() -> void:
	var menu := MAIN_MENU_SCENE.instantiate()
	menu.start_requested.connect(_on_start_requested)
	menu.quit_requested.connect(_on_quit_requested)
	_switch_to(menu)


## 开始游戏：切换到游戏场景。
func _on_start_requested() -> void:
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
