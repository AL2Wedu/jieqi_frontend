extends Control
## 好友面板：好友列表 / 收到申请 / 添加好友。
## 数据来源 GET /v1/social/friends、GET /v1/social/requests、POST /v1/social/requests 等。

signal close_requested

@onready var _friends_tab: Button = %FriendsTab
@onready var _requests_tab: Button = %RequestsTab
@onready var _friends_scroll: ScrollContainer = %FriendsScroll
@onready var _requests_scroll: ScrollContainer = %RequestsScroll
@onready var _friends_list: VBoxContainer = %FriendsList
@onready var _requests_list: VBoxContainer = %RequestsList
@onready var _player_id_edit: LineEdit = %PlayerIdEdit
@onready var _add_button: Button = %AddButton
@onready var _hint: Label = %Hint
@onready var _close: Button = %CloseButton
@onready var _dim: ColorRect = %Dim


func _ready() -> void:
	_close.pressed.connect(func() -> void: close_requested.emit())
	_close.pressed.connect(func() -> void: hide())
	_dim.gui_input.connect(_on_dim_input)
	_friends_tab.pressed.connect(func() -> void: _show_tab(true))
	_requests_tab.pressed.connect(func() -> void: _show_tab(false))
	_add_button.pressed.connect(_on_add_pressed)
	_show_tab(true)


func open() -> void:
	visible = true
	_hint.visible = true
	_hint.text = "加载中…"
	await _refresh()


func _refresh() -> void:
	await _load_friends()
	await _load_requests()
	if is_instance_valid(self):
		_hint.visible = false


func _show_tab(friends: bool) -> void:
	_friends_scroll.visible = friends
	_requests_scroll.visible = not friends
	_friends_tab.button_pressed = friends
	_requests_tab.button_pressed = not friends


func _clear_list(list_node: VBoxContainer) -> void:
	for child in list_node.get_children():
		list_node.remove_child(child)
		child.queue_free()


func _load_friends() -> void:
	_clear_list(_friends_list)
	var res := await Backend.get_friends()
	if not is_instance_valid(self) or res.get("code", -1) != 0:
		return
	var items: Array = res["data"].get("items", [])
	if items.is_empty():
		_add_hint_row(_friends_list, "还没有好友")
		return
	for item in items:
		var d: Dictionary = item
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var name := Label.new()
		name.text = str(d.get("name", "?"))
		name.add_theme_font_size_override("font_size", 18)
		name.add_theme_color_override("font_color", Color(0.42, 0.3, 0.15))
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name)
		var rm := Button.new()
		rm.text = "删除"
		rm.custom_minimum_size = Vector2(80, 40)
		rm.focus_mode = Control.FOCUS_NONE
		rm.add_theme_color_override("font_color", Color(0.42, 0.3, 0.15))
		rm.add_theme_font_size_override("font_size", 16)
		var pid := str(d.get("player_id", ""))
		rm.pressed.connect(_remove_friend.bind(pid))
		row.add_child(rm)
		_friends_list.add_child(row)


func _load_requests() -> void:
	_clear_list(_requests_list)
	var res := await Backend.get_friend_requests()
	if not is_instance_valid(self) or res.get("code", -1) != 0:
		return
	var items: Array = res["data"].get("items", [])
	if items.is_empty():
		_add_hint_row(_requests_list, "没有收到好友申请")
		return
	for item in items:
		var d: Dictionary = item
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var name := Label.new()
		name.text = str(d.get("name", "?"))
		name.add_theme_font_size_override("font_size", 18)
		name.add_theme_color_override("font_color", Color(0.42, 0.3, 0.15))
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name)
		var pid := str(d.get("player_id", ""))
		var accept := Button.new()
		accept.text = "接受"
		accept.focus_mode = Control.FOCUS_NONE
		accept.add_theme_color_override("font_color", Color(0.42, 0.3, 0.15))
		accept.add_theme_font_size_override("font_size", 16)
		accept.pressed.connect(_accept_friend.bind(pid))
		row.add_child(accept)
		var reject := Button.new()
		reject.text = "拒绝"
		reject.focus_mode = Control.FOCUS_NONE
		reject.add_theme_color_override("font_color", Color(0.42, 0.3, 0.15))
		reject.add_theme_font_size_override("font_size", 16)
		reject.pressed.connect(_reject_friend.bind(pid))
		row.add_child(reject)
		_requests_list.add_child(row)


func _add_hint_row(list_node: VBoxContainer, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.42, 0.2))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	list_node.add_child(lbl)


func _on_add_pressed() -> void:
	var pid := _player_id_edit.text.strip_edges()
	if pid == "":
		_show_hint("请输入对方 player_id")
		return
	_player_id_edit.text = ""
	var res := await Backend.send_friend_request(pid)
	if not is_instance_valid(self):
		return
	if res.get("code", -1) != 0:
		_show_hint(str(res.get("message", "发送失败")))
		return
	_show_hint("好友申请已发送")
	await _refresh()


func _remove_friend(player_id: String) -> void:
	var res := await Backend.remove_friend(player_id)
	if not is_instance_valid(self):
		return
	if res.get("code", -1) != 0:
		_show_hint(str(res.get("message", "删除失败")))
		return
	await _refresh()


func _accept_friend(player_id: String) -> void:
	var res := await Backend.accept_friend(player_id)
	if not is_instance_valid(self):
		return
	if res.get("code", -1) != 0:
		_show_hint(str(res.get("message", "操作失败")))
		return
	await _refresh()


func _reject_friend(player_id: String) -> void:
	var res := await Backend.reject_friend(player_id)
	if not is_instance_valid(self):
		return
	if res.get("code", -1) != 0:
		_show_hint(str(res.get("message", "操作失败")))
		return
	await _refresh()


func _show_hint(text: String) -> void:
	_hint.visible = true
	_hint.text = text
	await get_tree().create_timer(2.5).timeout
	if is_instance_valid(self):
		_hint.visible = false


## 点击遮罩关闭。
func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close_requested.emit()
		hide()
