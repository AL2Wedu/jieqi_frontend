extends Control
## 游戏主场景：承载农场世界与各层 UI（均为占位，可替换正式资源）。

signal back_to_menu_requested

const SOLAR_TERMS := ["立春", "雨水", "惊蛰", "春分", "清明", "谷雨", "立夏", "小满", "芒种", "夏至", "小暑", "大暑", "立秋", "处暑", "白露", "秋分", "寒露", "霜降", "立冬", "小雪", "大雪", "冬至", "小寒", "大寒"]

@onready var _top_bar: TopBar = $TopBar
@onready var _grid: FarmGrid = $FarmGrid
@onready var _terms: SolarTermsBar = $SolarTermsBar
@onready var _toolbar: BottomToolbar = $BottomToolbar
@onready var _status: LandStatusPanel = $LandStatusPanel
@onready var _npc: NpcDialog = $NpcDialog

var _gold := 12860
var _water := 1280
var _energy := 36
var _energy_max := 60
var _term_index := 0


func _ready() -> void:
	_grid.plot_selected.connect(_on_plot_selected)
	_terms.term_selected.connect(_on_term_selected)
	_toolbar.action_selected.connect(_on_action_selected)

	_refresh_top_bar()
	_on_plot_selected(2)


func _on_plot_selected(index: int) -> void:
	var plot := _grid.get_plot(index)
	# 演示：不同地块展示不同的肥力/湿度/健康。
	var fertility := 60 + (index * 7) % 40
	var humidity := 35 + (index * 11) % 50
	var health := 80 + (index * 3) % 15
	_status.set_stats(fertility, humidity, health)
	match plot.state:
		FarmPlot.PlotState.EMPTY:
			_npc.set_message("土壤肥沃，适合播种～\n记得及时浇水和施肥哦！")
		FarmPlot.PlotState.LOCKED:
			_npc.set_message("这块农田还没解锁哦，继续加油吧！")
		_:
			_npc.set_message("作物长势不错，记得按时灌溉与施肥～")


func _on_term_selected(term_name: String) -> void:
	_term_index = SOLAR_TERMS.find(term_name)
	_top_bar.set_season(term_name)
	_top_bar.set_date("甲子年 %s" % term_name)
	# 演示：切换节气时刷新天气。
	_top_bar.set_temperature(8 + _term_index * 2)
	_top_bar.set_humidity(70 - _term_index * 5)


func _on_action_selected(action_name: String) -> void:
	print("[游戏] 操作「%s」（占位）" % action_name)
	match action_name:
		"播种":
			_npc.set_message("已经撒下种子啦～")
		"灌溉":
			_water = max(0, _water - 10)
			_npc.set_message("浇灌完成，土壤湿润起来啦～")
		"施肥":
			_npc.set_message("施过肥了，作物更有劲啦～")
		"除草":
			_npc.set_message("杂草清除干净啦～")
		"收割":
			_gold += 200
			_npc.set_message("收获满满，金币 +200！")
	_refresh_top_bar()


func _refresh_top_bar() -> void:
	_top_bar.set_season(SOLAR_TERMS[_term_index])
	_top_bar.set_date("甲子年 %s" % SOLAR_TERMS[_term_index])
	_top_bar.set_temperature(8)
	_top_bar.set_humidity(70)
	_top_bar.set_resources(_gold, "%d/%d" % [_energy, _energy_max], _water)


## 按 Esc 返回主菜单。
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		back_to_menu_requested.emit()
