extends Control
## 游戏主场景：从后端加载节气/农场/玩家数据，工具栏操作走后端。

signal back_to_menu_requested

const SOLAR_TERMS := ["立春", "雨水", "惊蛰", "春分", "清明", "谷雨", "立夏", "小满", "芒种", "夏至", "小暑", "大暑", "立秋", "处暑", "白露", "秋分", "寒露", "霜降", "立冬", "小雪", "大雪", "冬至", "小寒", "大寒"]
const CROP_PICKER := preload("res://scenes/CropPicker.tscn")
const SHOP := preload("res://scenes/Shop.tscn")
const STORAGE_PANEL := preload("res://scenes/farm/StoragePanel.tscn")
const TOAST := preload("res://scenes/farm/Toast.tscn")
const PEST_RHYTHM := preload("res://scenes/farm/PestRhythmGame.tscn")
const INVENTORY_PANEL := preload("res://scenes/farm/InventoryPanel.tscn")
const QUESTS_PANEL := preload("res://scenes/farm/QuestsPanel.tscn")
const ACHIEVEMENTS_PANEL := preload("res://scenes/farm/AchievementsPanel.tscn")
const SOCIAL_PANEL := preload("res://scenes/farm/SocialPanel.tscn")
const AI_CHAT_PANEL := preload("res://scenes/farm/AiChatPanel.tscn")
const SETTINGS_PANEL := preload("res://scenes/SettingsPanel.tscn")
const TUTORIAL := preload("res://scenes/farm/TutorialOverlay.tscn")

@onready var _top_bar: TopBar = $TopBar
@onready var _world: FarmWorld = $FarmWorld
@onready var _grid: FarmGrid = $FarmGrid
@onready var _terms: SolarTermsBar = $SolarTermsBar
@onready var _toolbar: BottomToolbar = $BottomBar/BottomToolbar
@onready var _status: LandStatusPanel = $BottomBar/LandStatusPanel
@onready var _npc: NpcDialog = $BottomBar/NpcDialog
@onready var _shop_hotspot: Button = %ShopHotspot
@onready var _storage_button: Button = %StorageButton
@onready var _feature_rail: VBoxContainer = %FeatureRail

var _gold := 0
var _level := 1
var _exp := 0
var _unlocked_term_index := 0
var _term_index := 0
var _term_remaining := 0
var _selected_index := 0
var _plots_data: Array = []          # 后端 /farm/state 的 plots 缓存
var _fertilizer_item_id := ""
var _crop_picker: Control = null
var _shop: Control = null
var _storage_panel: Control = null
var _toast_node: Control = null
var _rhythm_game: Control = null
var _inventory_panel: Control = null
var _quests_panel: Control = null
var _achievements_panel: Control = null
var _social_panel: Control = null
var _ai_chat_panel: Control = null
var _settings_panel: Control = null
var _countdown_timer: Timer = null
var _tutorial: Control = null
var _tutorial_step := -1


func _ready() -> void:
	_grid.plot_selected.connect(_on_plot_selected)
	_toolbar.action_selected.connect(_on_action_selected)
	Backend.term_changed.connect(_on_term_changed)
	Backend.resources_changed.connect(_on_resources_changed)
	Backend.pest_big_event.connect(_on_pest_big)
	Backend.pest_small_event.connect(_on_pest_small)
	Backend.pest_destroyed_event.connect(_on_pest_destroyed)
	Backend.crop_withered_event.connect(_on_crop_withered)
	Backend.weed_growth_event.connect(_on_weed_growth)

	# 顶部事件提示条
	_toast_node = TOAST.instantiate()
	add_child(_toast_node)

	# 虫害交互（小虫害连击驱赶；大虫害走音游，见下方 _rhythm_game）
	_grid.pest_drive_away_requested.connect(_on_pest_drive_away_requested)
	_grid.pest_expired.connect(_on_pest_expired)

	# 播种选作物弹窗
	_crop_picker = CROP_PICKER.instantiate()
	add_child(_crop_picker)
	_crop_picker.picked.connect(_on_crop_picked)

	# 商店面板
	_shop = SHOP.instantiate()
	add_child(_shop)
	_shop.visible = false
	_shop.close_requested.connect(_on_shop_closed)
	_shop.opened.connect(_on_shop_opened)
	_shop.assets_changed.connect(_refresh_player_and_topbar)

	# 商店入口热区（透明，悬停高亮）
	_style_shop_hotspot()
	_shop_hotspot.pressed.connect(_open_shop)

	# 收成仓入口（顶栏下方右侧，图标按钮，透明背景，无悬停框）
	_storage_button.icon = load("res://assets/icons/storage_silo.png")
	_storage_button.expand_icon = true
	_storage_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_storage_button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	_storage_button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	_storage_button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	_storage_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_storage_button.pivot_offset = _storage_button.size / 2.0
	_storage_button.button_down.connect(func() -> void: _storage_button.scale = Vector2(0.9, 0.9))
	_storage_button.button_up.connect(func() -> void: _storage_button.scale = Vector2.ONE)
	_storage_button.pressed.connect(_open_storage)

	# 收成仓查看面板
	_storage_panel = STORAGE_PANEL.instantiate()
	add_child(_storage_panel)
	_storage_panel.visible = false
	_storage_panel.close_requested.connect(func() -> void: _storage_panel.visible = false)
	_storage_panel.assets_changed.connect(_refresh_player_and_topbar)

	# 新手教学覆盖层
	_tutorial = TUTORIAL.instantiate()
	add_child(_tutorial)
	_tutorial.visible = false

	# 功能入口面板：背包 / 任务 / 成就 / 好友 / AI
	_inventory_panel = _add_panel(INVENTORY_PANEL)
	_quests_panel = _add_panel(QUESTS_PANEL)
	_achievements_panel = _add_panel(ACHIEVEMENTS_PANEL)
	_social_panel = _add_panel(SOCIAL_PANEL)
	_ai_chat_panel = _add_panel(AI_CHAT_PANEL)
	_settings_panel = _add_panel(SETTINGS_PANEL)
	_settings_panel.logged_out.connect(func() -> void:
		back_to_menu_requested.emit.call_deferred())
	_build_feature_rail()

	# 大虫害音游覆盖层（最后挂载，覆盖所有面板）
	_rhythm_game = PEST_RHYTHM.instantiate()
	add_child(_rhythm_game)
	_rhythm_game.setup(_grid)
	_rhythm_game.submit_requested.connect(_on_rhythm_submit_requested)
	_rhythm_game.finished.connect(_on_rhythm_finished)

	_refresh_top_bar()
	_grid.select_index(0)  # 同步高亮与逻辑选中（会触发 plot_selected → _on_plot_selected）
	_load_from_backend()
	Backend.check_art_updates()  # 非阻塞：对比版本并缓存素材
	Backend.ensure_ws()          # 直接进游戏（有本地 token）也要订阅节气广播

	# 新手教学：注册后首进游戏展示
	_maybe_start_tutorial()

	# 节气剩余秒倒计时：每秒递减，到 0 重拉
	_countdown_timer = Timer.new()
	_countdown_timer.wait_time = 1.0
	_countdown_timer.timeout.connect(_tick_countdown)
	add_child(_countdown_timer)
	_countdown_timer.start()


## 首屏加载：农场 + 玩家 + 节气。
func _load_from_backend() -> void:
	var farm := await Backend.get_farm_state()
	if not is_instance_valid(self):
		return
	if farm.get("code", -1) == 0:
		_plots_data = farm["data"].get("plots", [])
		_grid.apply_farm_state(_plots_data)
		_handle_farm_events(farm["data"])
		_on_plot_selected(_selected_index)
	else:
		_npc.set_message("无法连接服务器，当前展示本地演示数据")
	var cal := await Backend.get_calendar()
	if cal.get("code", -1) == 0:
		_apply_term(cal["data"])
	var me := await Backend.get_player_me()
	if me.get("code", -1) == 0:
		_gold = int(me["data"].get("coins", 0))
		_level = int(me["data"].get("level", 1))
		_exp = int(me["data"].get("exp", 0))
		_unlocked_term_index = clampi(int(me["data"].get("unlocked_term_index", 1)) - 1, 0, 23)
		_refresh_top_bar()
	# 虫害状态：寄生中的小虫害地块 + 进行中的大虫害
	var pest := await Backend.get_pest_state()
	if pest.get("code", -1) == 0:
		_grid.apply_pest_state(pest["data"])
		var big: Variant = pest["data"].get("active_big")
		if big is Dictionary:
			_on_pest_big(big)


## 操作成功后刷新农场与金币。
func _after_operation() -> void:
	var farm := await Backend.get_farm_state()
	if not is_instance_valid(self):
		return
	if farm.get("code", -1) == 0:
		_plots_data = farm["data"].get("plots", [])
		_grid.apply_farm_state(_plots_data)
		_handle_farm_events(farm["data"])
		_on_plot_selected(_selected_index)
	var me := await Backend.get_player_me()
	if me.get("code", -1) == 0:
		_gold = int(me["data"].get("coins", 0))
		_level = int(me["data"].get("level", 1))
		_exp = int(me["data"].get("exp", 0))
		_unlocked_term_index = clampi(int(me["data"].get("unlocked_term_index", 1)) - 1, 0, 23)
		_refresh_top_bar()


## /farm/state 里的本次事件（枯萎/杂草）→ Toast 提示。
func _handle_farm_events(data: Dictionary) -> void:
	for e in data.get("wither_events", []):
		var d: Dictionary = e
		_toast("%s 枯萎了" % str(d.get("crop_name", "作物")))
	if not (data.get("weed_events", []) as Array).is_empty():
		_toast("地里长杂草了，作物生长变慢")


func _apply_term(data: Dictionary) -> void:
	var ti: int = int(data.get("term_index", 1)) - 1  # 后端 1-24 → 前端 0-23
	_term_index = clampi(ti, 0, SOLAR_TERMS.size() - 1)
	_term_remaining = int(data.get("remaining_sec", 0))
	_terms.set_term(_term_index)
	_world.set_season_by_term(_term_index)
	_refresh_top_bar()


func _tick_countdown() -> void:
	_term_remaining = maxi(0, _term_remaining - 1)
	_top_bar.set_remaining_sec(_term_remaining)
	if _term_remaining == 0:
		# 服务端到点会推 solar_term_change；兜底再拉一次
		var cal := await Backend.get_calendar()
		if cal.get("code", -1) == 0:
			_apply_term(cal["data"])


func _on_term_changed(payload: Dictionary) -> void:
	_apply_term(payload)


## 管理后台改了玩家资产（resources_changed 推送）：以强制刷新后的 /player/me 为准。
func _on_resources_changed(player_data: Dictionary) -> void:
	_gold = int(player_data.get("coins", _gold))
	_level = int(player_data.get("level", _level))
	_exp = int(player_data.get("exp", _exp))
	_unlocked_term_index = clampi(int(player_data.get("unlocked_term_index", _unlocked_term_index + 1)) - 1, 0, 23)
	_refresh_top_bar()


func _toast(text: String, duration := 3.0) -> void:
	if _toast_node != null:
		_toast_node.show_message(text, duration)


## WS：作物枯萎（玩家季节进入作物枯萎季节）。
func _on_crop_withered(payload: Dictionary) -> void:
	for t in payload.get("targets", []):
		var d: Dictionary = t
		_toast("%s 枯萎了" % str(d.get("crop_name", "作物")))
	await _after_operation()


## WS：杂草生长（随机地块附杂草，作物生长减速）。
func _on_weed_growth(_payload: Dictionary) -> void:
	_toast("地里长杂草了，作物生长变慢")
	await _after_operation()


## WS：大虫害来袭（音游对抗：害虫落地瞬间点击地块驱赶）。
func _on_pest_big(payload: Dictionary) -> void:
	if _rhythm_game != null and _rhythm_game.is_active():
		return  # 重连/重复推送：已有进行中的音游
	if _rhythm_game != null and _rhythm_game.start(payload):
		# 音游覆盖全屏：先收起已打开的面板
		if _shop != null and _shop.visible:
			_shop.close()
		for panel in [_settings_panel, _ai_chat_panel, _social_panel, _achievements_panel,
				_quests_panel, _inventory_panel, _storage_panel, _crop_picker]:
			if panel != null and panel.visible:
				panel.visible = false
		_toast("大虫害来袭！害虫落地瞬间点击地块驱赶！")
	else:
		_start_legacy_big(payload)


## 无可攻击地块（全锁定）兜底：等满时长后提交弃战成绩。
func _start_legacy_big(payload: Dictionary) -> void:
	var pest_id := str(payload.get("pest_id", ""))
	var duration := int(payload.get("duration_seconds", 30))
	var elapsed := int(payload.get("elapsed_seconds", 0))
	_toast("大虫害来袭！")
	await get_tree().create_timer(maxf(0.0, duration - elapsed)).timeout
	if is_instance_valid(self):
		await _submit_pest_result(pest_id, 0, 100, 0)


## WS：小虫害寄生（地块倒计时，点击地块驱赶）。
func _on_pest_small(payload: Dictionary) -> void:
	_grid.apply_pest_small(payload)
	_toast("害虫入侵！点击红色地块驱赶")


## WS：寄生倒计时到点，作物被摧毁。
func _on_pest_destroyed(payload: Dictionary) -> void:
	_grid.apply_pest_destroyed(payload)
	_toast("作物被害虫毁坏了")
	await _after_operation()


## 小虫害连击达标：直接驱赶（POST /farm/pest/{id}/drive-away）。
func _on_pest_drive_away_requested(pest_id: String, plot_id: String) -> void:
	var res := await Backend.drive_away(pest_id, plot_id)
	if not is_instance_valid(self):
		return
	if res.get("code", -1) == 0:
		_grid.remove_pest_target(plot_id)
		var destroyed: bool = bool(res["data"].get("destroyed", false))
		Sfx.play("perfect")
		_toast("驱赶成功！" if not destroyed else "来晚了，作物已被害虫毁坏")
	else:
		_toast(Backend.friendly_message(res, "驱赶失败"))
	await _after_operation()


## 小虫害倒计时到点（服务端已摧毁作物）。
func _on_pest_expired(_plot_id: String) -> void:
	await _after_operation()


## 大虫害成绩提交（音游/兜底共用）：TOO_FAST 3 秒重试、未达标惩罚、刷新。
## 返回后端 data（空字典 = 提交失败）。
func _submit_pest_result(pest_id: String, score: int, max_score: int, miss_count: int) -> Dictionary:
	var res := await Backend.submit_pest_result(pest_id, score, max_score, miss_count)
	if not is_instance_valid(self):
		return {}
	if res.get("code", -1) != 0:
		if str(res.get("error_code", "")) == "PEST_RESULT_TOO_FAST":
			await get_tree().create_timer(3.0).timeout
			if is_instance_valid(self):
				return await _submit_pest_result(pest_id, score, max_score, miss_count)
		return {}
	var data: Dictionary = res["data"]
	if not data.get("passed", false) and data.has("pest_small"):
		var penalty: Variant = data["pest_small"]
		if penalty is Dictionary:
			_on_pest_small(penalty)  # 未达标 → 惩罚寄生小虫害
	_toast("大虫害已处理")
	await _after_operation()
	return data


## 音游结束：提交成绩并把结果回传结算面板。
func _on_rhythm_submit_requested(pest_id: String, score: int, max_score: int, miss_count: int) -> void:
	var data := await _submit_pest_result(pest_id, score, max_score, miss_count)
	if is_instance_valid(_rhythm_game):
		_rhythm_game.show_result(data)


## 音游结算面板关闭：恢复 BGM。
func _on_rhythm_finished() -> void:
	Music.resume_after_loading()


func _open_shop() -> void:
	_shop.open()


## 商店打开完成（加载动画结束、内容可见）：教学第 4 步 → 第 5 步（指引关闭商店）。
func _on_shop_opened() -> void:
	_tutorial_advance(4)


## 商店关闭：教学第 5 步 → 第 6 步（背包）。
func _on_shop_closed() -> void:
	_shop.visible = false
	_tutorial_advance(5)


## 面板操作改变资产（购买/出售/领奖）后重拉 /player/me 刷顶栏。
func _refresh_player_and_topbar() -> void:
	var me := await Backend.get_player_me()
	if not is_instance_valid(self):
		return
	if me.get("code", -1) == 0:
		_on_resources_changed(me["data"])


func _open_storage() -> void:
	_storage_panel.open()
	_tutorial_advance(3)


## 统一挂载弹窗面板：隐藏 + 关连接 + 资产变更刷新。
func _add_panel(scene: PackedScene) -> Control:
	var p := scene.instantiate()
	add_child(p)
	p.visible = false
	p.close_requested.connect(func() -> void: p.visible = false)
	if p.has_signal("assets_changed"):
		p.assets_changed.connect(_refresh_player_and_topbar)
	return p


## 左侧功能入口竖列：背包 / 任务 / 成就 / 好友 / 设置。
func _build_feature_rail() -> void:
	_make_rail_button("res://assets/icons/rail_背包.png", "背包",
		func() -> void:
			_inventory_panel.open()
			_tutorial_advance(6))
	_make_rail_button("res://assets/icons/rail_任务.png", "任务",
		func() -> void:
			_quests_panel.open()
			_tutorial_advance(7))
	_make_rail_button("res://assets/icons/rail_成就.png", "成就",
		func() -> void:
			_achievements_panel.open()
			_tutorial_advance(8))
	_make_rail_button("res://assets/icons/rail_好友.png", "好友",
		func() -> void:
			_social_panel.open()
			_tutorial_advance(9))
	_make_rail_button("res://assets/icons/settings.svg", "设置",
		func() -> void: _settings_panel.open())


func _make_rail_button(icon_path: String, tooltip: String, callback: Callable) -> void:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(44, 44)
	btn.icon = load(icon_path) as Texture2D
	btn.expand_icon = true
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.tooltip_text = tooltip
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.pivot_offset = Vector2(22, 22)
	btn.button_down.connect(func() -> void: btn.scale = Vector2(0.85, 0.85))
	btn.button_up.connect(func() -> void: btn.scale = Vector2.ONE)
	btn.pressed.connect(callback)
	_feature_rail.add_child(btn)


## 商店入口热区透明化，悬停轻微高亮提示可点。
func _style_shop_hotspot() -> void:
	for state in ["normal", "hover", "pressed", "focus"]:
		_shop_hotspot.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(1, 1, 0.6, 0.12)
	hover.set_corner_radius_all(16)
	hover.border_width_left = 3
	hover.border_width_top = 3
	hover.border_width_right = 3
	hover.border_width_bottom = 3
	hover.border_color = Color(0.9, 0.75, 0.3, 0.6)
	_shop_hotspot.add_theme_stylebox_override("hover", hover)


func _on_plot_selected(index: int) -> void:
	_selected_index = index
	var plot := _grid.get_plot(index)

	var d := _plot_data_at(index)
	if not d.is_empty():
		var soil: int = int(d.get("soil_quality", 1))
		var fertility := clampi(20 + soil * 20, 0, 100)
		var water_level := 0
		var crop_data: Variant = d.get("crop")
		if crop_data is Dictionary:
			water_level = int(crop_data.get("water_level", 0))
		_status.set_stats(fertility, water_level, 80)
	else:
		# 本地演示兜底
		var fertility := 60 + (index * 7) % 40
		var humidity := 35 + (index * 11) % 50
		var health := 80 + (index * 3) % 15
		_status.set_stats(fertility, humidity, health)

	match plot.state:
		FarmPlot.PlotState.EMPTY:
			_npc.set_message("土壤肥沃，适合播种～\n点击下方「播种」选作物吧！")
		FarmPlot.PlotState.LOCKED:
			_npc.set_message("这块农田还没解锁哦，继续加油吧！")
		_:
			_npc.set_message("作物长势不错，记得按时灌溉与施肥～")


## 按 idx 查找地块数据（不依赖数组位置；后端 idx 1-20 → 前端 index 0-19）。
func _plot_data_at(index: int) -> Dictionary:
	for d in _plots_data:
		if int(d.get("idx", 0)) - 1 == index:
			return d
	return {}


func _on_action_selected(action_name: String) -> void:
	# 按选中地块状态门控操作
	var st := _grid.get_plot(_selected_index).state
	if st == FarmPlot.PlotState.LOCKED:
		_npc.set_message("这块农田还没解锁哦")
		return
	var plot_id := _grid.get_plot_id(_selected_index)
	match action_name:
		"播种":
			if st != FarmPlot.PlotState.EMPTY:
				_npc.set_message("这块地已经有作物了，先收割或铲除吧")
				return
			_on_sow_pressed()
		"灌溉":
			if st == FarmPlot.PlotState.EMPTY:
				_npc.set_message("先播种才能灌溉哦")
				return
			_on_water_pressed(plot_id)
		"施肥":
			if st == FarmPlot.PlotState.EMPTY:
				_npc.set_message("先播种才能施肥哦")
				return
			_on_fertilize_pressed(plot_id)
		"除草":
			if not _grid.get_plot(_selected_index).weeded:
				_npc.set_message("这里没有杂草，无需除草")
				return
			_on_weed_clear_pressed(plot_id)
		"收割":
			if st != FarmPlot.PlotState.MATURE:
				_npc.set_message("作物还没成熟哦")
				return
			_on_harvest_pressed(plot_id)


func _on_sow_pressed() -> void:
	if _grid.get_plot_id(_selected_index) == "":
		_npc.set_message("未连接服务器，无法播种")
		return
	_crop_picker.open()


func _on_crop_picked(seed_item: Dictionary) -> void:
	var plot_id := _grid.get_plot_id(_selected_index)
	if plot_id == "":
		_npc.set_message("未连接服务器，无法播种")
		return
	var effect: Dictionary = seed_item.get("effect", {})
	var crop_id := str(effect.get("crop_id", ""))
	var item_id := str(seed_item.get("item_id", ""))
	if crop_id == "" or item_id == "":
		_npc.set_message("这个种子无法播种")
		return
	if not await _has_item(item_id):
		var buy_res := await Backend.buy(item_id, 1)
		if buy_res.get("code", -1) != 0:
			# 后端区分金币不足(22003)/库存不足(22006)/商品不存在(22002)等，统一走文案层
			_npc.set_message(Backend.friendly_message(buy_res, "购买种子失败"))
			return
	var res := await Backend.sow(plot_id, crop_id)
	if res.get("code", -1) == 0:
		_npc.set_message("播种成功，记得按时浇水施肥～")
		_tutorial_advance(0)
		_after_operation()
	else:
		_npc.set_message(Backend.friendly_message(res, "播种失败"))
		await _after_operation()  # 可能已扣了买种子的金币，失败也刷新


func _on_water_pressed(plot_id: String) -> void:
	if plot_id == "":
		_npc.set_message("未连接服务器，无法灌溉")
		return
	var res := await Backend.water(plot_id)
	if res.get("code", -1) == 0:
		_npc.set_message("浇灌完成，土壤湿润起来啦～")
		_tutorial_advance(1)
		_after_operation()
	else:
		_npc.set_message(Backend.friendly_message(res, "浇水失败"))


func _on_fertilize_pressed(plot_id: String) -> void:
	if plot_id == "":
		_npc.set_message("未连接服务器，无法施肥")
		return
	if _fertilizer_item_id == "":
		var shop := await Backend.get_shop()
		if shop.get("code", -1) != 0:
			_npc.set_message("无法连接服务器，获取商店失败")
			return
		for item in shop["data"]["items"]:
			if str(item.get("code", "")) == "fertilizer":
				_fertilizer_item_id = str(item.get("item_id", ""))
				break
	if _fertilizer_item_id == "":
		_npc.set_message("商店里没有肥料")
		return
	if not await _has_item(_fertilizer_item_id):
		var buy_res := await Backend.buy(_fertilizer_item_id, 1)
		if buy_res.get("code", -1) != 0:
			# 后端区分金币不足(22003)/库存不足(22006)/商品不存在(22002)等，统一走文案层
			_npc.set_message(Backend.friendly_message(buy_res, "购买肥料失败"))
			return
	var res := await Backend.use_item(_fertilizer_item_id, plot_id)
	if res.get("code", -1) == 0:
		_npc.set_message("施过肥了，作物更有劲啦～")
		_tutorial_advance(2)
		_after_operation()
	else:
		_npc.set_message(Backend.friendly_message(res, "施肥失败"))
		await _after_operation()  # 可能已扣了买肥料的金币，失败也刷新


## 清除选中地块杂草（后端 POST /farm/plots/{id}/weed-clear）。
func _on_weed_clear_pressed(plot_id: String) -> void:
	if plot_id == "":
		_npc.set_message("未连接服务器，无法除草")
		return
	var res := await Backend.clear_weed(plot_id)
	if res.get("code", -1) == 0:
		_npc.set_message("杂草清除干净啦～")
		_after_operation()
	else:
		_npc.set_message(str(res.get("message", "除草失败")))


## 铲除地块作物（后端 POST /farm/plots/{id}/clear）。
func _on_clear_pressed(plot_id: String) -> void:
	if plot_id == "":
		_npc.set_message("未连接服务器，无法铲除")
		return
	var res := await Backend.clear_plot(plot_id)
	if res.get("code", -1) == 0:
		_npc.set_message("已铲除，土地空出来了")
		_after_operation()
	else:
		_npc.set_message(Backend.friendly_message(res, "铲除失败"))


func _on_harvest_pressed(plot_id: String) -> void:
	if plot_id == "":
		_npc.set_message("未连接服务器，无法收割")
		return
	var res := await Backend.harvest(plot_id)
	if res.get("code", -1) == 0:
		var data: Dictionary = res["data"]
		var yield_amt: int = int(data.get("yield", 0))
		var storage_after: int = int(data.get("storage_after", yield_amt))
		var crop_name := str(data.get("crop_name", ""))
		_npc.set_message("收获 %d 株%s，已入收成仓（仓内 %d），可去商店出售" % [yield_amt, crop_name, storage_after])
		_after_operation()
	else:
		_npc.set_message(Backend.friendly_message(res, "收割失败"))


## 背包是否已有某道具（数量 > 0）。
func _has_item(item_id: String) -> bool:
	var inv := await Backend.get_inventory()
	if inv.get("code", -1) != 0:
		return false
	for item in inv["data"]["items"]:
		if str(item.get("item_id", "")) == item_id and int(item.get("quantity", 0)) > 0:
			return true
	return false


## ---------------- 新手教学 ----------------

## 注册后首进游戏时展示新手引导（功能一览，实际操作推进）。
func _maybe_start_tutorial() -> void:
	if not Backend.is_tutorial_pending():
		return
	_tutorial_step = 0
	_tutorial.visible = true
	_tutorial_show_step()


## 展示当前教学步骤：手指指向对应功能，文字提示"试试看"。
func _tutorial_show_step() -> void:
	match _tutorial_step:
		0:
			_tutorial.point_at(_toolbar.get_action_button("播种"), "咻～点一下「播种」，种下你的第一颗小苗苗吧！")
		1:
			_tutorial.point_at(_toolbar.get_action_button("灌溉"), "小苗苗想喝水啦，试试「灌溉」润一润～")
		2:
			_tutorial.point_at(_toolbar.get_action_button("施肥"), "再施点肥，小苗苗能长得更壮哦～")
		3:
			_tutorial.point_at(_storage_button, "收获的宝贝都藏在「收成仓」里，悄悄点开看看～")
		4:
			_tutorial.point_at(_shop_hotspot, "去「商店」逛一圈，看看有什么好东西！")
		5:
			_tutorial.point_at(_shop.close_button(), "逛完啦，点「返回」回农场吧～")
		6:
			_tutorial.point_at(_feature_rail.get_child(0), "左排第一个是「背包」，点开看看你的家当～")
		7:
			_tutorial.point_at(_feature_rail.get_child(1), "「任务」会告诉你接下来要做什么，点开瞅瞅～")
		8:
			_tutorial.point_at(_feature_rail.get_child(2), "「成就」记录你的每一个小里程碑，点开瞧瞧～")
		9:
			_tutorial.point_at(_feature_rail.get_child(3), "最后看看「好友」，可以拜访朋友的农场哦！")
		10:
			_tutorial.finish()
			Backend.complete_tutorial()


## 玩家完成某一步实际操作后调用，推进到下一步。
## expected 为当前期望步骤（可选）：不匹配则忽略，防误点跳步。
func _tutorial_advance(expected := -1) -> void:
	if not _tutorial.visible or _tutorial_step < 0:
		return
	if expected >= 0 and _tutorial_step != expected:
		return
	_tutorial_step += 1
	_tutorial_show_step()


func _refresh_top_bar() -> void:
	_top_bar.set_season(_term_index)
	_top_bar.set_date("甲子年 %s" % SOLAR_TERMS[_term_index])
	_top_bar.set_temperature(8 + _term_index * 2)
	_top_bar.set_humidity(clampi(70 - _term_index * 5, 10, 90))
	_top_bar.set_gold(_gold)
	_top_bar.set_level(_level)
	_top_bar.set_exp(_exp)
	_top_bar.set_unlocked_term(_unlocked_term_index)
	_top_bar.set_remaining_sec(_term_remaining)


## 按 Esc / 安卓返回：先关最上层弹窗，再返回主菜单。
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		# 音游特殊：进行中消费返回键（不退出），结算面板显示时关闭面板
		if _rhythm_game != null and _rhythm_game.is_active():
			_rhythm_game.handle_back()
			return
		# 商店特殊：带加载动画退出
		if _shop != null and _shop.visible:
			_shop.close()
			return
		for panel in [_settings_panel, _ai_chat_panel, _social_panel, _achievements_panel, _quests_panel,
				_inventory_panel, _storage_panel, _crop_picker]:
			if panel != null and panel.visible:
				panel.visible = false
				return
		# 无弹窗可关：交由 Main 处理返回主菜单（避免同帧双处理用 call_deferred）
		get_viewport().set_input_as_handled()
		back_to_menu_requested.emit.call_deferred()


## 安卓返回键：系统通知通路。返回 true = 已消费（有面板可关），false = 需退到主菜单。
func handle_android_back() -> bool:
	# 音游特殊：进行中消费返回键（不退出），结算面板显示时关闭面板
	if _rhythm_game != null and _rhythm_game.is_active():
		_rhythm_game.handle_back()
		return true
	# 商店特殊：带加载动画退出
	if _shop != null and _shop.visible:
		_shop.close()
		return true
	for panel in [_settings_panel, _ai_chat_panel, _social_panel, _achievements_panel, _quests_panel,
			_inventory_panel, _storage_panel, _crop_picker]:
		if panel != null and panel.visible:
			panel.visible = false
			return true
	return false
