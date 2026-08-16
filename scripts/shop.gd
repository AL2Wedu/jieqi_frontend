extends Control
## 商店页面（当前为占位，商店内容待做）。
## 进入/退出都播放加载动画（蓝条纹进度条 3-5s 到 100%），随后淡出露出/隐藏商店。

signal close_requested
signal assets_changed
signal opened  # 打开完成（加载动画结束、内容可见）

const LOAD_SECONDS := 4.0   # 加载动画时长（3-5s 区间）
const FADE_SECONDS := 0.6   # 加载页淡出时长
const WALK_IN_SECONDS := 2.6  # 动物从远处走近动画时长
const WALK_IN_DROP := 190.0   # 起点在最终位置上方多少像素（远处）

## 商店动物（情绪为 happy）；进入商店随机挑一只走入。
## 素材走 /v1/assets/images/animals/{emotion}/{animal}.png?w=128（预渲染选档）。
const ANIMALS := ["bear", "cat", "cat2", "chicken", "crow", "deer", "dog", "dog2",
	"fox", "frog", "hedgehog", "horse", "mouse", "owl", "ox", "panda",
	"penguin", "pig", "rabbit", "raccoon", "sheep", "sheep2", "squirrel", "wolf"]

@onready var _title: Label = %Title
@onready var _sub: Label = %Sub
@onready var _close: Button = %CloseButton
@onready var _loading: Control = %LoadingOverlay
@onready var _load_bar: ProgressBar = %Bar
@onready var _load_pct: Label = %Pct
@onready var _animal: TextureRect = %AnimalWalkIn
@onready var _guest_bubble: PanelContainer = %GuestBubble
@onready var _guest_text: Label = %GuestText
@onready var _confirm_button: Button = %ConfirmButton
@onready var _cancel_button: Button = %CancelButton
@onready var _shelf_list: VBoxContainer = %ShelfList
@onready var _basket_list: VBoxContainer = %BasketList
@onready var _take_button: Button = %TakeButton
@onready var _reject_button: Button = %RejectButton
@onready var _send_button: Button = %SendButton
@onready var _restock_button: Button = %RestockButton
@onready var _input_box: LineEdit = %InputBox

var _busy := false  # 加载动画播放中（开或关），避免并发
var _walk_tween: Tween = null
var _walk_final_pos := Vector2.ZERO  # 动物最终位置（场景中定义，_ready 时记录）
var _guest_session_id := ""  # AI 客人点菜会话（赶客/成交用；跨商店开关保持）
var _order_items: Array = []  # AI 点单 [{crop_id, quantity}]
var _order_total := 0  # AI 报的总价（服务端 confirm 时重算校验）
var _shelf_items: Array[Dictionary] = []  # 货架物品
var _basket_items: Array[Dictionary] = []  # 菜篮物品
var _shelf_selected := -1  # 货架选中项索引
var _revisit_timer: Timer = null  # 客人走后 10-20s 再来
var _guest_animal := ""  # 客人动物名（情绪换头像用）
var _guest_mood := "calm"
var _ai_busy := false  # AI 回复中，禁止发送


## AI 调用期间禁用发送按钮（避免连点/回车造成并发请求）。
func _set_ai_busy(busy: bool) -> void:
	_ai_busy = busy
	_send_button.disabled = busy

## 客人情绪 → 动物表情目录（plain 用平静）。
const MOOD_EMOTION := { "plain": "calm", "happy": "happy", "sad": "sad", "confused": "confused" }


func _ready() -> void:
	_close.pressed.connect(close)
	_cancel_button.pressed.connect(_on_reject)
	_confirm_button.pressed.connect(_on_confirm_order)
	_take_button.pressed.connect(_on_take)
	_reject_button.pressed.connect(_on_reject)
	_send_button.pressed.connect(_on_send)
	_restock_button.pressed.connect(_on_restock)
	_input_box.text_submitted.connect(func(_t: String) -> void: _on_send())
	_load_bar.value_changed.connect(func(v: float) -> void: _load_pct.text = "%d%%" % int(round(v)))
	_loading.visible = false
	_guest_bubble.visible = false
	_confirm_button.visible = false
	_walk_final_pos = _animal.position


## 打开商店：先播放加载动画，淡出后露出商店。
func open() -> void:
	if _busy:
		return
	visible = true
	_show_content()
	_reset_walk_in()
	_busy = true
	await _play_loading("商 店", "咻地一下冲向商店！")
	_busy = false
	opened.emit()
	_play_walk_in()


## 退出商店：立刻隐藏商店内容（只剩加载页盖住），动画结束再整个隐藏。
func close() -> void:
	if _busy or not visible:
		return
	if _revisit_timer != null:
		_revisit_timer.stop()  # 商店关闭时不再自动来客
	_busy = true
	_hide_content()
	await _play_loading("农 场", "一溜烟跑回农场～")
	_busy = false
	hide()
	close_requested.emit()


## 返回按钮（新手教学指向用）。
func close_button() -> Button:
	return _close


## 隐藏商店内容（保留加载页），避免淡出时商店闪现。
## 只操作 Control 子节点（_revisit_timer 等非 Control 节点无 visible 属性）。
func _hide_content() -> void:
	for child in get_children():
		if child != _loading and child is Control:
			child.visible = false


## 恢复商店内容显示。
func _show_content() -> void:
	for child in get_children():
		if child != _loading and child is Control:
			child.visible = true


## 重置加载页并播放进度条 + 淡出（加载期间暂停背景音乐，进度条区域不播放）。
func _play_loading(title_text: String, sub_text: String) -> void:
	Music.pause_for_loading()
	_title.text = title_text
	_sub.text = sub_text
	_load_bar.value = 0.0
	_load_pct.text = "0%"
	_loading.modulate.a = 1.0
	_loading.visible = true
	await _animate_loading()
	await _fade_loading()
	Music.resume_after_loading()


## 蓝色条纹进度条 0→100%，3-5 秒内到达。
func _animate_loading() -> void:
	var tw := create_tween()
	tw.tween_property(_load_bar, "value", 100.0, LOAD_SECONDS) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished


## 加载页渐渐变淡。
func _fade_loading() -> void:
	var tw := create_tween()
	tw.tween_property(_loading, "modulate:a", 0.0, FADE_SECONDS)
	await tw.finished
	_loading.visible = false


## 动物回到起点状态（上方远处、透明、微小、隐藏），避免加载淡出时闪现。
func _reset_walk_in() -> void:
	_animal.position = _walk_final_pos - Vector2(0, WALK_IN_DROP)
	_animal.modulate.a = 0.0
	_animal.scale = Vector2(0.12, 0.12)
	_animal.visible = false
	_guest_bubble.visible = false


## 客人从上方远处走近：起点在上方、透明且小（远景），
## 滑动到最终位置的同时变清晰、变大（近景）。
## 客人身份从后端 /v1/shop/guest/encounter 获取（头像走 images/animals 预渲染）；
## 拉取失败则随机挑一只动物兜底（无气泡）。
func _play_walk_in() -> void:
	var guest: Dictionary = {}
	print("[shop] _play_walk_in 开始，base_url=", Backend.base_url, " api=", Backend.api)
	var enc := await Backend.guest_encounter()
	if enc.get("code", -1) == 0:
		guest = enc["data"]
	print("[shop] encounter code=", enc.get("code", -1), " guest=", guest)
	var tex: Texture2D = null
	if not guest.is_empty():
		var avatar_url := str(guest.get("avatar_url", ""))
		if avatar_url != "":
			tex = await Backend.fetch_texture("%s%s" % [Backend.base_url, avatar_url])
	if tex == null:
		# 兜底：随机动物
		var name: String = ANIMALS.pick_random()
		var url := "%s/v1/assets/images/animals/happy/%s.png?w=128" % [Backend.base_url, name]
		tex = await Backend.fetch_texture(url)
	if tex == null:
		return  # 素材拉不到则静默跳过动画
	_animal.texture = tex
	_animal.pivot_offset = Vector2(_animal.size.x / 2.0, _animal.size.y)  # 以脚底为中心放大
	_animal.position = _walk_final_pos - Vector2(0, WALK_IN_DROP)
	_animal.modulate.a = 0.0
	_animal.scale = Vector2(0.12, 0.12)
	_animal.visible = true
	if _walk_tween != null:
		_walk_tween.kill()
	_walk_tween = create_tween()
	_walk_tween.tween_property(_animal, "modulate:a", 1.0, WALK_IN_SECONDS) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_walk_tween.parallel().tween_property(_animal, "scale", Vector2.ONE, WALK_IN_SECONDS) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_walk_tween.parallel().tween_property(_animal, "position", _walk_final_pos, WALK_IN_SECONDS) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if not guest.is_empty():
		_show_guest_bubble(guest)


## 客人头顶对话气泡：自动开单（order 融合接口，AI 自动点单）显示需求。
## 已有进行中的会话（上次没赶客）→ 直接取快照恢复。
func _show_guest_bubble(guest: Dictionary) -> void:
	_guest_bubble.visible = true
	_guest_text.text = "……"
	_confirm_button.visible = false
	# 记录客人动物名（情绪换头像用）；去掉扩展名，避免拼 URL 时重复后缀
	var avatar_url := str(guest.get("avatar_url", ""))
	var parts := avatar_url.split("/")
	if parts.size() >= 7:
		_guest_animal = parts[6].split("?")[0].get_basename()
	_guest_mood = "calm"
	if _guest_session_id != "":
		var snap := await Backend.order_snapshot(_guest_session_id)
		if snap.get("code", -1) == 0:
			_apply_guest_snapshot(snap["data"])
			return
		_guest_session_id = ""
	# 自动开单：order 融合接口（无 session_id → AI 自动点单）
	_set_ai_busy(true)
	var res := await Backend.order_chat("", "")
	_set_ai_busy(false)
	if not is_instance_valid(self):
		return
	if res.get("code", -1) != 0:
		# 已有进行中的会话（上次没赶客）：错误里带 session_id，恢复会话供赶客/成交
		var busy_sid := str(res.get("data", {}).get("session_id", ""))
		if busy_sid != "":
			_guest_session_id = busy_sid
			var snap := await Backend.order_snapshot(busy_sid)
			if snap.get("code", -1) == 0:
				_apply_guest_snapshot(snap["data"])
			return
		_guest_text.text = Backend.friendly_message(res, "……")
		return
	var data: Dictionary = res["data"]
	_guest_session_id = str(data.get("session_id", ""))
	_apply_order_start(data)


## 应用 AI 点单开场：记录点单内容，气泡显示客人说的话。
func _apply_order_start(data: Dictionary) -> void:
	_order_items.clear()
	_order_total = int(data.get("total_price", 0))
	for cid in data.get("items", []):
		_order_items.append({ "crop_id": str(cid), "quantity": 1 })
	_guest_text.text = str(data.get("raw_text", "……"))
	_apply_mood("calm")


## 从点菜会话快照恢复：气泡显示最后一条客人消息 + 情绪 + 点单。
func _apply_guest_snapshot(data: Dictionary) -> void:
	var history: Array = data.get("history", [])
	if not history.is_empty():
		var last: Dictionary = history[history.size() - 1]
		_guest_text.text = str(last.get("content", "……"))
	else:
		_guest_text.text = "……"
	_order_items.clear()
	var oi: Dictionary = data.get("order_items", {})
	for cid in oi.keys():
		_order_items.append({ "crop_id": str(cid), "quantity": int(oi[cid]) })
	_order_total = int(data.get("order_total", 0))
	_apply_mood(str(data.get("emotion", "calm")))


## 情绪反馈：客人头像换成对应表情（happy/calm/sad/confused）。
func _apply_mood(mood: String) -> void:
	var emotion := str(MOOD_EMOTION.get(mood, "calm"))
	if _guest_animal == "" or emotion == _guest_mood:
		return
	_guest_mood = emotion
	var url := "%s/v1/assets/images/animals/%s/%s.png?w=128" % [Backend.base_url, emotion, _guest_animal]
	var tex: Texture2D = await Backend.fetch_texture(url)
	if tex == null or not is_instance_valid(_animal):
		return
	_animal.texture = tex


## 补货：打开收成仓（选择模式），选中的作物放到货架。
func _on_restock() -> void:
	var storage := get_parent().get_node_or_null("StoragePanel")
	if storage == null:
		return
	if not storage.item_selected.is_connected(_on_storage_selected):
		storage.item_selected.connect(_on_storage_selected)
	storage.open_for_select()


func _on_storage_selected(item: Dictionary) -> void:
	_shelf_items.append(item)
	_refresh_shelf()


## 取货：货架选中的东西移到菜篮。
func _on_take() -> void:
	if _shelf_selected < 0 or _shelf_selected >= _shelf_items.size():
		return
	_basket_items.append(_shelf_items[_shelf_selected])
	_shelf_items.remove_at(_shelf_selected)
	_shelf_selected = -1
	_refresh_shelf()
	_refresh_basket()


## 发送：把输入框消息发给客人（order 多轮对话）。无会话时先自动开单。
func _on_send() -> void:
	if _ai_busy:
		return  # AI 回复中，忽略
	var text := _input_box.text.strip_edges()
	if text == "":
		return
	_input_box.clear()
	_set_ai_busy(true)
	if _guest_session_id == "":
		# 无会话：先自动开单（AI 点单），再发消息
		var res := await Backend.order_chat("", "")
		if not is_instance_valid(self):
			return
		if res.get("code", -1) != 0:
			_set_ai_busy(false)
			_guest_text.text = Backend.friendly_message(res, "……")
			return
		_guest_session_id = str(res["data"].get("session_id", ""))
		_apply_order_start(res["data"])
	var chat := await Backend.order_chat(_guest_session_id, text)
	_set_ai_busy(false)
	if not is_instance_valid(self):
		return
	if chat.get("code", -1) != 0:
		_guest_text.text = Backend.friendly_message(chat, "……")
		return
	var data: Dictionary = chat["data"]
	_guest_text.text = str(data.get("raw_text", "……"))
	_apply_mood(str(data.get("emotion", "calm")))
	_confirm_button.visible = bool(data.get("need_confirm", false))
	if str(data.get("status", "bargaining")) != "bargaining":
		# 关闭（超轮数/无菜等）：客人离开，10-20s 后新客人来
		_guest_session_id = ""
		_confirm_button.visible = false
		await get_tree().create_timer(2.0).timeout
		if is_instance_valid(self):
			_leave_guest()
			_schedule_next_guest()


## 成交：核对 AI 点单后确认（服务端重算价校验）。
func _on_confirm_order() -> void:
	if _guest_session_id == "" or _order_items.is_empty():
		return
	_confirm_button.visible = false
	_guest_text.text = "成交中…"
	var res := await Backend.order_confirm(_guest_session_id, _order_items, _order_total)
	if not is_instance_valid(self):
		return
	if res.get("code", -1) != 0:
		_guest_text.text = Backend.friendly_message(res, "成交失败")
		return
	var data: Dictionary = res["data"]
	if data.get("is_right", false):
		var settle: Dictionary = data.get("settle", {})
		_guest_text.text = "成交！%s" % _settle_summary(settle)
	else:
		_guest_text.text = str(data.get("raw_text", "……"))
	_guest_session_id = ""
	_confirm_button.visible = false
	await get_tree().create_timer(2.0).timeout
	if is_instance_valid(self):
		_leave_guest()
		_schedule_next_guest()


## 结算摘要：如 "水稻×2、萝卜×1，共 54 金币"。
func _settle_summary(settle: Dictionary) -> String:
	var details: Array = settle.get("details", [])
	var parts: Array[String] = []
	var total := 0
	for d in details:
		var dd: Dictionary = d
		parts.append("%s×%d" % [str(dd.get("name", "菜")), int(dd.get("quantity", 0))])
		total += int(dd.get("price", 0))
	return "%s，共 %d 金币" % ["、".join(parts), total]


## 拒绝/赶客：结束点菜会话（如有），客人淡出离开，10-20s 后新客人来。
func _on_reject() -> void:
	if _guest_session_id != "":
		var res := await Backend.order_cancel(_guest_session_id)
		_guest_session_id = ""
		if not is_instance_valid(self):
			return
		if res.get("code", -1) != 0:
			_guest_text.text = Backend.friendly_message(res, "赶客失败")
			return
	_guest_bubble.visible = false
	_confirm_button.visible = false
	_leave_guest()
	_schedule_next_guest()


## 客人走后 10-20s 再来一位（商店开着时）。
func _schedule_next_guest() -> void:
	if _revisit_timer == null:
		_revisit_timer = Timer.new()
		_revisit_timer.one_shot = true
		_revisit_timer.timeout.connect(_play_walk_in)
		add_child(_revisit_timer)
	_revisit_timer.wait_time = randf_range(10.0, 20.0)
	_revisit_timer.start()


## 客人离开：淡出消失。
func _leave_guest() -> void:
	if _walk_tween != null:
		_walk_tween.kill()
	_walk_tween = create_tween()
	_walk_tween.tween_property(_animal, "modulate:a", 0.0, 0.5)
	_walk_tween.tween_callback(func() -> void: _animal.visible = false)


## 刷新货架列表（选中项高亮）。
func _refresh_shelf() -> void:
	for child in _shelf_list.get_children():
		child.queue_free()
	for i in _shelf_items.size():
		var it: Dictionary = _shelf_items[i]
		var btn := Button.new()
		btn.text = str(it.get("name", "?"))
		btn.custom_minimum_size = Vector2(0, 40)
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", 18)
		btn.add_theme_color_override("font_color", Color(0.42, 0.3, 0.15))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.55, 0.8, 0.4, 1) if i == _shelf_selected else Color(0.85, 0.68, 0.4, 1)
		sb.set_corner_radius_all(10)
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		btn.pressed.connect(_on_shelf_item_pressed.bind(i))
		_shelf_list.add_child(btn)


func _on_shelf_item_pressed(i: int) -> void:
	_shelf_selected = i
	_refresh_shelf()


## 刷新菜篮列表（只读）。
func _refresh_basket() -> void:
	for child in _basket_list.get_children():
		child.queue_free()
	for it in _basket_items:
		var label := Label.new()
		label.text = str(it.get("name", "?"))
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_color", Color(0.42, 0.3, 0.15))
		_basket_list.add_child(label)
