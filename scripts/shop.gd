extends Control
## 商店页面（当前为占位，商店内容待做）。
## 进入/退出都播放加载动画（蓝条纹进度条 3-5s 到 100%），随后淡出露出/隐藏商店。

signal close_requested
signal assets_changed

const LOAD_SECONDS := 4.0   # 加载动画时长（3-5s 区间）
const FADE_SECONDS := 0.6   # 加载页淡出时长

@onready var _title: Label = %Title
@onready var _sub: Label = %Sub
@onready var _close: Button = %CloseButton
@onready var _loading: Control = %LoadingOverlay
@onready var _load_bar: ProgressBar = %Bar
@onready var _load_pct: Label = %Pct

var _busy := false  # 加载动画播放中（开或关），避免并发


func _ready() -> void:
	_close.pressed.connect(close)
	_load_bar.value_changed.connect(func(v: float) -> void: _load_pct.text = "%d%%" % int(round(v)))
	_loading.visible = false


## 打开商店：先播放加载动画，淡出后露出商店。
func open() -> void:
	if _busy:
		return
	visible = true
	_show_content()
	_busy = true
	await _play_loading("商 店", "咻地一下冲向商店！")
	_busy = false


## 退出商店：立刻隐藏商店内容（只剩加载页盖住），动画结束再整个隐藏。
func close() -> void:
	if _busy or not visible:
		return
	_busy = true
	_hide_content()
	await _play_loading("农 场", "一溜烟跑回农场～")
	_busy = false
	hide()
	close_requested.emit()


## 隐藏商店内容（保留加载页），避免淡出时商店闪现。
func _hide_content() -> void:
	for child in get_children():
		if child != _loading:
			child.visible = false


## 恢复商店内容显示。
func _show_content() -> void:
	for child in get_children():
		if child != _loading:
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
