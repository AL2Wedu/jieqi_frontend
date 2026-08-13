extends Control
## 游戏主场景：从后端加载节气/农场/玩家数据，工具栏操作走后端。

signal back_to_menu_requested

const SOLAR_TERMS := ["立春", "雨水", "惊蛰", "春分", "清明", "谷雨", "立夏", "小满", "芒种", "夏至", "小暑", "大暑", "立秋", "处暑", "白露", "秋分", "寒露", "霜降", "立冬", "小雪", "大雪", "冬至", "小寒", "大寒"]
const CROP_PICKER := preload("res://scenes/CropPicker.tscn")

@onready var _top_bar: TopBar = $TopBar
@onready var _world: FarmWorld = $FarmWorld
@onready var _grid: FarmGrid = $FarmGrid
@onready var _terms: SolarTermsBar = $SolarTermsBar
@onready var _toolbar: BottomToolbar = $BottomToolbar
@onready var _status: LandStatusPanel = $LandStatusPanel
@onready var _npc: NpcDialog = $NpcDialog

var _gold := 0
var _water := 0
var _energy := 0
var _energy_max := 60
var _term_index := 0
var _selected_index := 0
var _plots_data: Array = []          # 后端 /farm/state 的 plots 缓存
var _fertilizer_item_id := ""
var _crop_picker: Control = null


func _ready() -> void:
	_grid.plot_selected.connect(_on_plot_selected)
	_toolbar.action_selected.connect(_on_action_selected)
	Backend.term_changed.connect(_on_term_changed)

	# 播种选作物弹窗
	_crop_picker = CROP_PICKER.instantiate()
	add_child(_crop_picker)
	_crop_picker.picked.connect(_on_crop_picked)

	_refresh_top_bar()
	_on_plot_selected(0)
	_load_from_backend()
	Backend.check_art_updates()  # 非阻塞：对比版本并缓存素材
	Backend.ensure_ws()          # 直接进游戏（有本地 token）也要订阅节气广播


## 首屏加载：农场 + 玩家 + 节气。
func _load_from_backend() -> void:
	var farm := await Backend.get_farm_state()
	if not is_instance_valid(self):
		return
	if farm.get("code", -1) == 0:
		_plots_data = farm["data"].get("plots", [])
		_grid.apply_farm_state(_plots_data)
		_on_plot_selected(_selected_index)
	else:
		_npc.set_message("无法连接服务器，当前展示本地演示数据")
	var cal := await Backend.get_calendar()
	if cal.get("code", -1) == 0:
		_apply_term(cal["data"])
	var me := await Backend.get_player_me()
	if me.get("code", -1) == 0:
		_gold = int(me["data"].get("coins", 0))
		_refresh_top_bar()


## 操作成功后刷新农场与金币。
func _after_operation() -> void:
	var farm := await Backend.get_farm_state()
	if not is_instance_valid(self):
		return
	if farm.get("code", -1) == 0:
		_plots_data = farm["data"].get("plots", [])
		_grid.apply_farm_state(_plots_data)
		_on_plot_selected(_selected_index)
	var me := await Backend.get_player_me()
	if me.get("code", -1) == 0:
		_gold = int(me["data"].get("coins", 0))
		_refresh_top_bar()


func _apply_term(data: Dictionary) -> void:
	var ti: int = int(data.get("term_index", 1)) - 1  # 后端 1-24 → 前端 0-23
	_term_index = clampi(ti, 0, SOLAR_TERMS.size() - 1)
	_terms.set_term(_term_index)
	_world.set_season_by_term(_term_index)
	_refresh_top_bar()


func _on_term_changed(payload: Dictionary) -> void:
	_apply_term(payload)


func _on_plot_selected(index: int) -> void:
	_selected_index = index
	var plot := _grid.get_plot(index)

	if index >= 0 and index < _plots_data.size():
		var d: Dictionary = _plots_data[index]
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


func _on_action_selected(action_name: String) -> void:
	var plot_id := _grid.get_plot_id(_selected_index)
	match action_name:
		"播种":
			_on_sow_pressed()
		"灌溉":
			_on_water_pressed(plot_id)
		"施肥":
			_on_fertilize_pressed(plot_id)
		"除草":
			_npc.set_message("杂草清除干净啦～")
		"收割":
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
		return
	if not await _has_item(item_id):
		var buy_res := await Backend.buy(item_id, 1)
		if buy_res.get("code", -1) != 0:
			_npc.set_message("金币不足，买不了种子")
			return
	var res := await Backend.sow(plot_id, crop_id)
	if res.get("code", -1) == 0:
		_npc.set_message("播种成功，记得按时浇水施肥～")
		_after_operation()
	else:
		_npc.set_message(str(res.get("message", "播种失败")))


func _on_water_pressed(plot_id: String) -> void:
	if plot_id == "":
		_npc.set_message("未连接服务器，无法灌溉")
		return
	var res := await Backend.water(plot_id)
	if res.get("code", -1) == 0:
		_npc.set_message("浇灌完成，土壤湿润起来啦～")
		_after_operation()
	else:
		_npc.set_message(str(res.get("message", "浇水失败")))


func _on_fertilize_pressed(plot_id: String) -> void:
	if plot_id == "":
		_npc.set_message("未连接服务器，无法施肥")
		return
	if _fertilizer_item_id == "":
		var shop := await Backend.get_shop()
		if shop.get("code", -1) == 0:
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
			_npc.set_message("金币不足，买不了肥料")
			return
	var res := await Backend.use_item(_fertilizer_item_id, plot_id)
	if res.get("code", -1) == 0:
		_npc.set_message("施过肥了，作物更有劲啦～")
		_after_operation()
	else:
		_npc.set_message(str(res.get("message", "施肥失败")))


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
		_npc.set_message(str(res.get("message", "收割失败")))


## 背包是否已有某道具（数量 > 0）。
func _has_item(item_id: String) -> bool:
	var inv := await Backend.get_inventory()
	if inv.get("code", -1) != 0:
		return false
	for item in inv["data"]["items"]:
		if str(item.get("item_id", "")) == item_id and int(item.get("quantity", 0)) > 0:
			return true
	return false


func _refresh_top_bar() -> void:
	_top_bar.set_season(_term_index)
	_top_bar.set_date("甲子年 %s" % SOLAR_TERMS[_term_index])
	_top_bar.set_temperature(8 + _term_index * 2)
	_top_bar.set_humidity(clampi(70 - _term_index * 5, 10, 90))
	_top_bar.set_resources(_gold, "%d/%d" % [_energy, _energy_max], _water)


## 按 Esc 返回主菜单。
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		back_to_menu_requested.emit()
