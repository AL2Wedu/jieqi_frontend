class_name FarmGrid
extends Control
## 中央农田网格：4×5 地块，处理地块选中、状态刷新。

signal plot_selected(index: int)

const FARM_PLOT := preload("res://scenes/farm/FarmPlot.tscn")
const COLUMNS := 4
const ROWS := 5

var _plots: Array[FarmPlot] = []

@onready var _grid: GridContainer = %Grid


func _ready() -> void:
	# 伪 3D：整片农田轻微倾斜 + 纵向压扁，营造地面透视感。
	rotation = -0.75
	scale = Vector2(1.0, 0.9)
	pivot_offset = size * 0.5
	resized.connect(func() -> void: pivot_offset = size * 0.5)

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
