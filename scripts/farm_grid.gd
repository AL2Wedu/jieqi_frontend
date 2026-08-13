class_name FarmGrid
extends Control
## 中央农田网格：4×5 地块，处理地块选中、状态刷新。

signal plot_selected(index: int)

const FARM_PLOT := preload("res://scenes/farm/FarmPlot.tscn")
const COLUMNS := 4
const ROWS := 5

var _plots: Array[FarmPlot] = []
var _plot_ids: Array[String] = []

@onready var _grid: GridContainer = %Grid


func _ready() -> void:
	for i in COLUMNS * ROWS:
		var p := FARM_PLOT.instantiate() as FarmPlot
		p.plot_clicked.connect(_on_plot_clicked)
		_grid.add_child(p)
		_plots.append(p)
	_setup_demo()


func _on_plot_clicked(plot: FarmPlot) -> void:
	if plot.state == FarmPlot.PlotState.LOCKED:
		return  # 锁定地块：暂不响应，占位
	select_index(_plots.find(plot))


func select_index(index: int) -> void:
	for p in _plots:
		p.set_selected(p == _plots[index])
	plot_selected.emit(index)


func get_plot(index: int) -> FarmPlot:
	return _plots[index]


func get_plot_id(index: int) -> String:
	if index < 0 or index >= _plot_ids.size():
		return ""
	return _plot_ids[index]


## 用后端农场状态刷新 20 个地块。
## plots 为 /farm/state 返回的 plots 数组（idx 1-20）。
func apply_farm_state(plots: Array) -> void:
	_plot_ids.resize(COLUMNS * ROWS)
	for i in _plot_ids.size():
		_plot_ids[i] = ""
	for plot in plots:
		var d: Dictionary = plot
		var idx: int = int(d.get("idx", 0)) - 1
		if idx < 0 or idx >= _plots.size():
			continue
		_plot_ids[idx] = str(d.get("plot_id", ""))
		if bool(d.get("locked", false)):
			_plots[idx].set_plot_state(FarmPlot.PlotState.LOCKED)
		elif d.get("crop") == null:
			_plots[idx].set_plot_state(FarmPlot.PlotState.EMPTY)
		else:
			var crop: Dictionary = d["crop"]
			var stage: int = int(crop.get("stage", 1))
			var pstate := FarmPlot.PlotState.SPROUT
			match stage:
				2:
					pstate = FarmPlot.PlotState.LEAFY
				3:
					pstate = FarmPlot.PlotState.MATURE
			_plots[idx].set_plot_state(pstate, str(crop.get("name", "")))
			_load_crop_art(_plots[idx], crop, stage)


## 异步加载作物贴图（走 Backend 本地缓存），加载成功后覆盖文字显示。
func _load_crop_art(plot: FarmPlot, crop: Dictionary, stage: int) -> void:
	var tex := await Backend.get_crop_art_texture(crop, stage, 128)
	if tex != null and is_instance_valid(plot):
		plot.set_crop_texture(tex)


## 演示用初始状态（对应参考图的农田：作物、幼苗、锁定、选中、害虫）。
func _setup_demo() -> void:
	var layout: Array[Array] = [
		# [状态, 作物名]
		[FarmPlot.PlotState.MATURE, "小麦"],
		[FarmPlot.PlotState.LEAFY, "叶菜"],
		[FarmPlot.PlotState.SPROUT, "幼苗"],
		[FarmPlot.PlotState.EMPTY, ""],
		[FarmPlot.PlotState.MATURE, "小麦"],
		[FarmPlot.PlotState.LEAFY, "叶菜"],
		[FarmPlot.PlotState.SPROUT, "幼苗"],
		[FarmPlot.PlotState.SPROUT, "幼苗"],
		[FarmPlot.PlotState.EMPTY, ""],
		[FarmPlot.PlotState.MATURE, "小麦"],
		[FarmPlot.PlotState.LEAFY, "叶菜"],
		[FarmPlot.PlotState.MATURE, "小麦"],
		[FarmPlot.PlotState.SPROUT, "幼苗"],
		[FarmPlot.PlotState.LOCKED, ""],
		[FarmPlot.PlotState.EMPTY, ""],
		[FarmPlot.PlotState.LEAFY, "叶菜"],
		[FarmPlot.PlotState.LOCKED, ""],
		[FarmPlot.PlotState.LOCKED, ""],
		[FarmPlot.PlotState.LOCKED, ""],
		[FarmPlot.PlotState.LOCKED, ""],
	]
	for i in layout.size():
		_plots[i].set_plot_state(layout[i][0], layout[i][1])

	# 默认选中一块地 + 某块地出现害虫
	select_index(2)
	_plots[9].set_pest(true)
