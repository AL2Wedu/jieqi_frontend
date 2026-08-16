extends Control
## 大虫害音游覆盖层：害虫从屏顶落到真实地块，落地瞬间点击地块判定。
## 无音乐纯节拍（Sfx tick 提示），节拍驱动光环脉动；结算后提交成绩。
## 时间基准用 Time.get_ticks_msec()（与后端 elapsed 语义对齐，天然满足防作弊）。

signal submit_requested(pest_id: String, score: int, max_score: int, miss_count: int)
signal finished  # 结算面板关闭，game.gd 恢复 BGM

# ---- 节拍与时间常量 ----
const BEAT_SEC := 0.5            # 120 BPM
const WARNING_BEATS := 1         # 提醒 1 拍（光环+感叹号）
const FALL_BEATS := 3            # 下落 3 拍（1.5s）
const SPAWN_INTERVAL_BEATS := 6  # 生成间隔 6 拍（3s）
const PERFECT_MS := 150          # Perfect 窗口 ±0.15s
const GOOD_MS := 350            # Good 窗口 ±0.35s
const EAT_ANIM_MS := 800         # Miss 啃食动画时长
const END_DELAY_SEC := 0.6       # 游戏结束→结算面板延迟（让最后动画播完）
const PEST_NAMES := ["蚜虫", "蝗虫", "螟虫", "菜青虫", "棉铃虫", "稻飞虱"]

# ---- 害虫生命周期 ----
enum PestPhase { WARNING, FALLING, LANDED, JUDGED, MISSED }

# ---- 状态 ----
enum GameState { IDLE, PLAYING, RESULT_PENDING, RESULT_SHOWN }

var _grid: FarmGrid = null
var _state := GameState.IDLE
var _pest_id := ""
var _duration := 30.0
var _start_msec := 0             # 主时钟起点（含重连 elapsed 补偿）
var _last_beat := -1
var _next_spawn_msec := 0
var _spawned_count := 0
var _total_pests := 0
var _score := 0
var _perfect_count := 0
var _good_count := 0
var _miss_count := 0
var _combo := 0
var _max_combo := 0
var _active_pests: Array[Dictionary] = []
var _last_pest_name := ""
var _banner_tween: Tween = null
var _pest_textures: Dictionary = {}  # 害虫名 -> Texture2D（内存缓存，避免每只都下载）

@onready var _halo_layer: Control = %HaloLayer
@onready var _pest_layer: Control = %PestLayer
@onready var _banner: PanelContainer = %Banner
@onready var _banner_image: TextureRect = %BannerImage
@onready var _hud: PanelContainer = %HUD
@onready var _score_label: Label = %ScoreLabel
@onready var _combo_label: Label = %ComboLabel
@onready var _result_panel: PanelContainer = %ResultPanel
@onready var _result_title: Label = %ResultTitle
@onready var _result_score: Label = %ResultScore
@onready var _result_detail: Label = %ResultDetail
@onready var _result_reward: Label = %ResultReward
@onready var _retry_button: Button = %RetryButton
@onready var _confirm_button: Button = %ConfirmButton


func _ready() -> void:
	_retry_button.pressed.connect(_on_retry)
	_confirm_button.pressed.connect(_close_result)
	_banner.visible = false
	_hud.visible = false
	_result_panel.visible = false


## 绑定农场地块网格（game.gd 挂载后调用一次）。
func setup(grid: FarmGrid) -> void:
	_grid = grid


## 开始音游。返回 false = 无可攻击地块（全锁定），调用方走兜底逻辑。
func start(payload: Dictionary) -> bool:
	if _state != GameState.IDLE:
		return true  # 已在游戏中，忽略重复
	_pest_id = str(payload.get("pest_id", ""))
	_duration = float(payload.get("duration_seconds", 30))
	var elapsed := float(payload.get("elapsed_seconds", 0))
	var remaining := _duration - elapsed
	if remaining < 1.0:
		# 重连时已超时：直接提交弃战成绩（elapsed ≥ duration ≥ 18s，不会 TOO_FAST）
		submit_requested.emit(_pest_id, 0, 100, 0)
		return true
	if _grid == null or _grid.get_attackable_plot_indices().is_empty():
		return false  # 全锁定 → 调用方走 _start_legacy_big
	_reset()
	_total_pests = _pest_count_for(_duration)
	_start_msec = Time.get_ticks_msec() - int(elapsed * 1000.0)  # 主时钟含重连补偿
	_next_spawn_msec = _start_msec
	_state = GameState.PLAYING
	Music.pause_for_loading()
	visible = true
	_banner.visible = true
	_hud.visible = true
	_play_banner()
	_load_banner_image()
	return true


func is_active() -> bool:
	return _state != GameState.IDLE


## 返回键：音游中消费不退出；结算面板显示时关闭面板。
func handle_back() -> void:
	match _state:
		GameState.PLAYING, GameState.RESULT_PENDING:
			pass  # 音游中：消费返回键，不退出
		GameState.RESULT_SHOWN:
			_close_result()


## 提交结果回填结算面板（game.gd 提交完成后调用）。
func show_result(data: Dictionary) -> void:
	if _state != GameState.RESULT_SHOWN:
		return
	if data.is_empty():
		_result_title.text = "提交失败"
		_result_reward.text = "网络异常，请重试"
		_retry_button.visible = true
		return
	if data.get("passed", false):
		_result_title.text = "大虫害处理成功！"
		var reward: Dictionary = data.get("reward", {})
		var text := "奖励：金币 +%d，经验 +%d" % [int(reward.get("coins", 0)), int(reward.get("exp", 0))]
		var items: Array = reward.get("items", [])
		if not items.is_empty():
			text += "，道具 +%d 个" % items.size()
		_result_reward.text = text
	else:
		_result_title.text = "大虫害处理失败…"
		var penalty: Dictionary = data.get("penalty", {})
		_result_reward.text = "害虫啃食了作物，%d 块地出现小虫害" % int(penalty.get("targets", 0))


func _unhandled_input(event: InputEvent) -> void:
	if _state == GameState.IDLE:
		return
	if event.is_action_pressed("ui_cancel"):
		handle_back()
		get_viewport().set_input_as_handled()


## 点击判定：落地窗口内点中目标地块 → Perfect/Good；过早/点错无影响。
func _gui_input(event: InputEvent) -> void:
	if _state != GameState.PLAYING:
		return
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		for pest in _active_pests:
			if pest["phase"] != PestPhase.LANDED:
				continue
			var rect: Rect2 = pest["plot_rect"]
			if not rect.has_point(event.position):
				continue
			var dt := Time.get_ticks_msec() - int(pest["land_msec"])
			if absi(dt) <= PERFECT_MS:
				_judge(pest, "perfect")
			elif absi(dt) <= GOOD_MS:
				_judge(pest, "good")
			return  # 命中即消费；单只并发无歧义
		# 点错地块 / 过早点击：无任何影响


func _process(_delta: float) -> void:
	if _state != GameState.PLAYING:
		return
	var now := Time.get_ticks_msec()
	var elapsed := (now - _start_msec) / 1000.0

	# 1. 节拍：拍边界播 tick
	var beat := int(elapsed / BEAT_SEC)
	if beat != _last_beat:
		_last_beat = beat
		Sfx.play("tick")

	# 2. 调度新害虫
	if now >= _next_spawn_msec and _spawned_count < _total_pests:
		_spawn_pest()
		_spawned_count += 1
		_next_spawn_msec += int(SPAWN_INTERVAL_BEATS * BEAT_SEC * 1000.0)

	# 3. 每只害虫状态机（清理延后，避免遍历中改数组）
	var to_remove: Array[Dictionary] = []
	for pest in _active_pests:
		_tick_pest(pest, now, to_remove)
	for pest in to_remove:
		_remove_pest(pest)

	# 4. 光环随节拍脉动（拍点最亮，渐暗）
	var beat_phase := fmod(elapsed, BEAT_SEC) / BEAT_SEC
	var pulse := 1.0 - beat_phase
	for pest in _active_pests:
		if pest["phase"] == PestPhase.WARNING or pest["phase"] == PestPhase.FALLING:
			var halo: Control = pest["halo"]
			halo.scale = Vector2(1.0 + 0.15 * pulse, 1.0 + 0.15 * pulse)
			halo.modulate.a = 0.35 + 0.35 * pulse

	# 5. 结束检测：时长到 + 无未决害虫
	if elapsed >= _duration and _active_pests.is_empty():
		_finish_game()


func _tick_pest(pest: Dictionary, now: int, to_remove: Array[Dictionary]) -> void:
	match pest["phase"]:
		PestPhase.WARNING:
			if now >= int(pest["fall_start_msec"]):
				pest["phase"] = PestPhase.FALLING
				var token: Control = pest["token"]
				token.visible = true
		PestPhase.FALLING:
			var fall_ms := int(FALL_BEATS * BEAT_SEC * 1000.0)
			var progress := float(now - int(pest["fall_start_msec"])) / float(fall_ms)
			var center: Vector2 = pest["plot_rect"].get_center()
			var token: Control = pest["token"]
			if progress >= 1.0:
				pest["phase"] = PestPhase.LANDED
				token.position = center - token.size / 2.0
				_land_bounce(token)
			else:
				var y := lerpf(-token.size.y, center.y - token.size.y / 2.0, progress)
				token.position = Vector2(center.x - token.size.x / 2.0, y)
		PestPhase.LANDED:
			if now - int(pest["land_msec"]) > GOOD_MS:
				_register_miss(pest)
		PestPhase.JUDGED, PestPhase.MISSED:
			if now >= int(pest["cleanup_msec"]):
				to_remove.append(pest)


func _spawn_pest() -> void:
	var candidates := _grid.get_attackable_plot_indices()
	if candidates.is_empty():
		return  # 运行中地块全锁（极端）：跳过本次生成
	var idx: int = candidates.pick_random()
	var name: String = PEST_NAMES.pick_random()
	while name == _last_pest_name and PEST_NAMES.size() > 1:
		name = PEST_NAMES.pick_random()
	_last_pest_name = name
	var rect := _grid.get_plot_global_rect(idx)
	var has_crop: bool = _grid.get_plot(idx).state != FarmPlot.PlotState.EMPTY
	var now := Time.get_ticks_msec()
	var pest := {
		"name": name,
		"plot_index": idx,
		"plot_rect": rect,
		"has_crop": has_crop,
		"phase": PestPhase.WARNING,
		"spawn_msec": now,
		"fall_start_msec": now + int(WARNING_BEATS * BEAT_SEC * 1000.0),
		"land_msec": now + int((WARNING_BEATS + FALL_BEATS) * BEAT_SEC * 1000.0),
		"cleanup_msec": 0,
		"token": _make_pest_token(name),
		"halo": _make_halo(rect),
	}
	_active_pests.append(pest)
	_load_pest_image(pest["token"], name)


## 判定成功：加分/连击/飘字/音效/地块绿闪。
func _judge(pest: Dictionary, grade: String) -> void:
	pest["phase"] = PestPhase.JUDGED
	pest["cleanup_msec"] = Time.get_ticks_msec() + 400
	var center: Vector2 = pest["plot_rect"].get_center()
	if grade == "perfect":
		_score += 100
		_perfect_count += 1
		_combo += 1
		Sfx.play("perfect")
		_spawn_float_text(center - Vector2(0, 70), "Perfect!", Color(1, 0.8, 0.2, 1))
	else:
		_score += 50
		_good_count += 1
		_combo += 1
		Sfx.play("good")
		_spawn_float_text(center - Vector2(0, 70), "Good", Color(0.5, 0.8, 1, 1))
	_max_combo = maxi(_max_combo, _combo)
	_update_hud()
	_flash_plot(pest["plot_rect"], Color(0.4, 0.9, 0.5, 0.35), 0.3)
	_fade_out(pest["token"], 0.25)


## Miss：害虫啃食作物动画（教育性）+ 计 miss。
func _register_miss(pest: Dictionary) -> void:
	pest["phase"] = PestPhase.MISSED
	pest["cleanup_msec"] = Time.get_ticks_msec() + EAT_ANIM_MS
	_miss_count += 1
	_combo = 0
	Sfx.play("miss")
	_shake(pest["token"], 0.5)
	_flash_plot(pest["plot_rect"], Color(0.9, 0.25, 0.2, 0.4), 0.8)
	var center: Vector2 = pest["plot_rect"].get_center()
	var text := "作物被啃食！" if pest["has_crop"] else "害虫入侵！"
	_spawn_float_text(center - Vector2(0, 70), text, Color(0.9, 0.3, 0.25, 1))
	_update_hud()


func _remove_pest(pest: Dictionary) -> void:
	var token: Control = pest["token"]
	if is_instance_valid(token):
		token.queue_free()
	var halo: Control = pest["halo"]
	if is_instance_valid(halo):
		halo.queue_free()
	_active_pests.erase(pest)


func _finish_game() -> void:
	_state = GameState.RESULT_PENDING
	_banner.visible = false
	await get_tree().create_timer(END_DELAY_SEC).timeout
	if not is_instance_valid(self):
		return
	if _state != GameState.RESULT_PENDING:
		return
	_show_result_panel()
	submit_requested.emit(_pest_id, _score, _total_pests * 100, _miss_count)


func _show_result_panel() -> void:
	_result_panel.visible = true
	_result_score.text = "得分 %d / %d" % [_score, _total_pests * 100]
	_result_detail.text = "Perfect %d　Good %d　Miss %d" % [_perfect_count, _good_count, _miss_count]
	_result_reward.text = "提交中…"
	_retry_button.visible = false
	_state = GameState.RESULT_SHOWN  # 先置 SHOWN 再 emit，防重入


func _close_result() -> void:
	if _state != GameState.RESULT_SHOWN:
		return
	_state = GameState.IDLE
	_result_panel.visible = false
	visible = false
	finished.emit()


func _on_retry() -> void:
	_retry_button.visible = false
	_result_title.text = "大虫害"
	_result_reward.text = "提交中…"
	submit_requested.emit(_pest_id, _score, _total_pests * 100, _miss_count)


func _reset() -> void:
	_score = 0
	_perfect_count = 0
	_good_count = 0
	_miss_count = 0
	_combo = 0
	_max_combo = 0
	_spawned_count = 0
	_last_beat = -1
	_last_pest_name = ""
	_active_pests.clear()
	_clear_layer(_halo_layer)
	_clear_layer(_pest_layer)
	_result_panel.visible = false
	_update_hud()


func _clear_layer(layer: Control) -> void:
	for child in layer.get_children():
		child.queue_free()


## 顶部警示横幅：1.5s 后淡出。
func _play_banner() -> void:
	if _banner_tween != null:
		_banner_tween.kill()
	_banner.modulate.a = 1.0
	_banner_tween = create_tween()
	_banner_tween.tween_interval(1.5)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.4)
	_banner_tween.tween_callback(func() -> void: _banner.visible = false)


## 按时长算害虫总数（30s→10 只，间隔 3s）。
func _pest_count_for(duration: float) -> int:
	return maxi(1, int(duration / (SPAWN_INTERVAL_BEATS * BEAT_SEC)))


## 下落害虫节点：圆角气泡 + 害虫名（图片异步加载后插入，见 _load_pest_image）。
func _make_pest_token(name: String) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(96, 44)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.55, 0.2, 0.12, 0.95)
	sb.set_corner_radius_all(22)
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.border_color = Color(0.3, 0.1, 0.05, 1)
	panel.add_theme_stylebox_override("panel", sb)
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)
	var label := Label.new()
	label.text = name
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(1, 0.95, 0.85, 1))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	vbox.add_child(label)
	panel.visible = false
	panel.position = Vector2(-200, -200)  # 屏外待命
	_pest_layer.add_child(panel)
	return panel


## 异步加载害虫图（后端 /v1/assets/pests/main/，内存缓存）；失败保持文字气泡。
func _load_pest_image(token: Control, name: String) -> void:
	var tex: Texture2D = _pest_textures.get(name)
	if tex == null:
		tex = await Backend.fetch_texture("%s/v1/assets/pests/main/%s.png" % [Backend.base_url, name.uri_encode()])
		if tex == null:
			return  # 素材拉不到则保持文字气泡
		_pest_textures[name] = tex
	if not is_instance_valid(token):
		return
	var img := TextureRect.new()
	img.texture = tex
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.custom_minimum_size = Vector2(56, 40)
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vbox := token.get_child(0) as VBoxContainer
	vbox.add_child(img)
	vbox.move_child(img, 0)  # 图片在名字上方


## 异步加载大虫害横幅配图（后端 /v1/assets/pests/banner/）；失败保持文字横幅。
func _load_banner_image() -> void:
	var url := "%s/v1/assets/pests/banner/%s.png" % [Backend.base_url, "大虫害开场横幅配图".uri_encode()]
	var tex: Texture2D = await Backend.fetch_texture(url)
	if tex == null or not is_instance_valid(self):
		return
	_banner_image.texture = tex
	_banner_image.visible = true


## 目标地块提醒光环：半透明圆角框 + 感叹号，随节拍脉动。
func _make_halo(rect: Rect2) -> Control:
	var halo := Panel.new()
	halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	halo.position = rect.position - Vector2(6, 6)
	halo.size = rect.size + Vector2(12, 12)
	halo.pivot_offset = halo.size / 2.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 0.85, 0.2, 0.25)
	sb.set_corner_radius_all(16)
	sb.border_width_left = 4
	sb.border_width_top = 4
	sb.border_width_right = 4
	sb.border_width_bottom = 4
	sb.border_color = Color(1, 0.8, 0.15, 1)
	halo.add_theme_stylebox_override("panel", sb)
	var mark := Label.new()
	mark.text = "!"
	mark.add_theme_font_size_override("font_size", 40)
	mark.add_theme_color_override("font_color", Color(1, 0.9, 0.3, 1))
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	halo.add_child(mark)
	_halo_layer.add_child(halo)
	return halo


## 飘字：上浮 + 淡出，结束后自毁。
func _spawn_float_text(pos: Vector2, text: String, color: Color) -> void:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = text
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.3, 0.2, 0.1, 1))
	label.add_theme_constant_override("outline_size", 4)
	label.position = pos - Vector2(100, 20)  # 文字盒居中于 pos
	label.size = Vector2(200, 40)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_halo_layer.add_child(label)
	var start_y := label.position.y
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "position:y", start_y - 50, 0.8)
	tw.tween_property(label, "modulate:a", 0.0, 0.8).set_delay(0.2)
	tw.chain().tween_callback(label.queue_free)


## 地块闪光覆盖层（判定成功绿 / 啃食红），淡出后自毁。
func _flash_plot(rect: Rect2, color: Color, dur: float) -> void:
	var flash := ColorRect.new()
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.position = rect.position
	flash.size = rect.size
	flash.color = color
	_halo_layer.add_child(flash)
	var tw := create_tween()
	tw.tween_property(flash, "color:a", 0.0, dur)
	tw.tween_callback(flash.queue_free)


## 落地小动画：轻微回弹。
func _land_bounce(token: Control) -> void:
	token.pivot_offset = token.size / 2.0
	token.scale = Vector2(1.2, 1.2)
	var tw := create_tween()
	tw.tween_property(token, "scale", Vector2.ONE, 0.15) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 抖动动画（啃食）。
func _shake(node: Control, dur: float) -> void:
	var tw := create_tween()
	var base := node.position
	for i in 6:
		var dir := 1.0 if i % 2 == 0 else -1.0
		tw.tween_property(node, "position", base + Vector2(6 * dir, 0), dur / 12.0)
	tw.tween_property(node, "position", base, dur / 12.0)


func _fade_out(node: Control, dur: float) -> void:
	var tw := create_tween()
	tw.tween_property(node, "modulate:a", 0.0, dur)


func _update_hud() -> void:
	_score_label.text = "得分 %d" % _score
	_combo_label.text = "连击 %d" % _combo
