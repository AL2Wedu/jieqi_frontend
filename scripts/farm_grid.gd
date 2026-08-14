class_name FarmGrid
extends Control
## 中央农田网格：4×5 地块，处理地块选中、状态刷新、小虫害倒计时与驱赶。

signal plot_selected(index: int)
signal pest_drive_away_requested(pest_id: String, plot_id: String)
signal pest_expired(plot_id: String)

const FARM_PLOT := preload("res://scenes/farm/FarmPlot.tscn")
const COLUMNS := 4
const ROWS := 5

var _plots: Array[FarmPlot] = []
var _plot_ids: Array[String] = []

# 小虫害寄生目标：plot_id -> { "pest_id": String, "ready_at_unix": float }
var _pest_targets: Dictionary = {}
var _pest_timer: Timer = null

@onready var _grid: GridContainer = %Grid


func _ready() -> void:
	for i in COLUMNS * ROWS:
		var p := FARM_PLOT.instantiate() as FarmPlot
		p.plot_clicked.connect(_on_plot_clicked)
		_grid.add_child(p)
		_plots.append(p)
	_setup_demo()
	_pest_timer = Timer.new()
	_pest_timer.wait_time = 1.0
	_pest_timer.timeout.connect(_tick_pest)
	add_child(_pest_timer)
	_pest_timer.start()


func _on_plot_clicked(plot: FarmPlot) -> void:
	if plot.state == FarmPlot.PlotState.LOCKED:
		return  # 锁定地块：暂不响应，占位
	var idx := _plots.find(plot)
	if idx < 0:
		return
	# 点击有虫害的地块 = 驱赶（而非选中）
	var pid := _plot_ids[idx] if idx < _plot_ids.size() else ""
	if pid != "" and _pest_targets.has(pid):
		var t: Dictionary = _pest_targets[pid]
		pest_drive_away_requested.emit(str(t.get("pest_id", "")), pid)
		return
	select_index(idx)


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
	for p in _plots:
		p.set_pest(false)  # 清除 demo/上一帧残留害虫

	# 先算每格目标 key：locked→"L"，空→"E"，作物→"<slug>|<stage>"
	var keys: Array[String] = []
	keys.resize(COLUMNS * ROWS)
	for i in keys.size():
		keys[i] = ""
	var crop_by_index := {}
	for plot in plots:
		var d: Dictionary = plot
		var idx: int = int(d.get("idx", 0)) - 1
		if idx < 0 or idx >= _plots.size():
			continue
		_plot_ids[idx] = str(d.get("plot_id", ""))
		_plots[idx].set_weeded(bool(d.get("weeded", false)))  # 杂草：作物生长减速
		var crop: Variant = d.get("crop")
		if crop is Dictionary:
			var slug := Backend.crop_slug(crop)
			var stage: int = int(crop.get("stage", 1))
			keys[idx] = "%s|%d" % [slug, stage]
			crop_by_index[idx] = crop
		elif bool(d.get("locked", false)):
			keys[idx] = "L"
		else:
			keys[idx] = "E"

	# 应用：内容没变的格子跳过（避免每次刷新重下贴图/闪烁）
	for i in _plots.size():
		var plot := _plots[i]
		var key := keys[i]
		if key == plot.crop_key:
			continue
		plot.crop_key = key
		plot.reset_crop_art()
		match key:
			"L":
				plot.set_plot_state(FarmPlot.PlotState.LOCKED)
			"E":
				plot.set_plot_state(FarmPlot.PlotState.EMPTY)
			_:
				var crop: Dictionary = crop_by_index[i]
				var stage: int = int(crop.get("stage", 1))
				var pstate := FarmPlot.PlotState.SPROUT
				match stage:
					2:
						pstate = FarmPlot.PlotState.LEAFY
					3:
						pstate = FarmPlot.PlotState.MATURE
				plot.set_plot_state(pstate, str(crop.get("name", "")))
				plot.set_crop_stage_scale(stage)
				_load_crop_art(plot, crop, stage)


## 异步加载作物贴图（走 Backend 本地缓存），加载成功后覆盖文字显示。
## 下载期间地块内容若已变化（crop_key 对不上）则不应用，防止旧贴图残留。
func _load_crop_art(plot: FarmPlot, crop: Dictionary, stage: int) -> void:
	var slug := Backend.crop_slug(crop)
	var expected_key := "%s|%d" % [slug, stage]
	var tex := await Backend.get_crop_art_texture(crop, stage, 128)
	if tex != null and is_instance_valid(plot) and plot.crop_key == expected_key:
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


## ---------------- 小虫害（倒计时 + 驱赶） ----------------

## 用 /pest/state 的 active_small 刷新全部小虫害目标。
func apply_pest_state(data: Dictionary) -> void:
	_clear_pest_targets()
	for t in data.get("active_small", []):
		var d: Dictionary = t
		_add_pest_target(str(d.get("plot_id", "")), str(d.get("pest_id", "")), float(d.get("remaining_sec", 0)))


## WS pest_small：payload.targets 有 wait_seconds / ready_at，倒计时从广播起算。
func apply_pest_small(payload: Dictionary) -> void:
	for t in payload.get("targets", []):
		var d: Dictionary = t
		_add_pest_target(str(d.get("plot_id", "")), str(d.get("pest_id", "")), float(d.get("wait_seconds", 0)))


## WS pest_destroyed / 驱赶成功：移除对应地块标记。
func apply_pest_destroyed(payload: Dictionary) -> void:
	for t in payload.get("targets", []):
		var d: Dictionary = t
		_pest_targets.erase(str(d.get("plot_id", "")))
	_refresh_pest_plots()


func remove_pest_target(plot_id: String) -> void:
	_pest_targets.erase(plot_id)
	_refresh_pest_plots()


func is_pest_target(plot_id: String) -> bool:
	return _pest_targets.has(plot_id)


func _clear_pest_targets() -> void:
	_pest_targets.clear()
	_refresh_pest_plots()


func _add_pest_target(plot_id: String, pest_id: String, remaining: float) -> void:
	if plot_id == "" or remaining < 0:
		return
	_pest_targets[plot_id] = {
		"pest_id": pest_id,
		"ready_at_unix": Time.get_unix_time_from_system() + remaining,
	}
	_refresh_pest_plots()


## 每秒刷新地块倒计时显示；到点发 pest_expired（服务端已摧毁作物，等待刷新）。
func _tick_pest() -> void:
	var now := Time.get_unix_time_from_system()
	var expired: Array[String] = []
	for plot_id in _pest_targets.keys():
		var t: Dictionary = _pest_targets[plot_id]
		if float(t.get("ready_at_unix", 0.0)) <= now:
			expired.append(str(plot_id))
	for plot_id in expired:
		_pest_targets.erase(plot_id)
		pest_expired.emit(plot_id)
	if not expired.is_empty():
		_refresh_pest_plots()


func _refresh_pest_plots() -> void:
	var now := Time.get_unix_time_from_system()
	for i in _plots.size():
		var pid := _plot_ids[i] if i < _plot_ids.size() else ""
		var rem := 0
		if _pest_targets.has(pid):
			rem = int(maxf(0.0, float(_pest_targets[pid]["ready_at_unix"]) - now))
		_plots[i].set_pest_countdown(rem)
