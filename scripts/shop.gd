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

var _busy := false  # 加载动画播放中（开或关），避免并发
var _walk_tween: Tween = null
var _walk_final_pos := Vector2.ZERO  # 动物最终位置（场景中定义，_ready 时记录）


func _ready() -> void:
	_close.pressed.connect(close)
	_load_bar.value_changed.connect(func(v: float) -> void: _load_pct.text = "%d%%" % int(round(v)))
	_loading.visible = false
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


## 动物回到起点状态（上方远处、透明、微小、隐藏），避免加载淡出时闪现。
func _reset_walk_in() -> void:
	_animal.position = _walk_final_pos - Vector2(0, WALK_IN_DROP)
	_animal.modulate.a = 0.0
	_animal.scale = Vector2(0.12, 0.12)
	_animal.visible = false


## 随机一只动物从上方远处走近：起点在上方、透明且小（远景），
## 滑动到最终位置的同时变清晰、变大（近景）。
## 素材从后端 /v1/assets/images/animals/ 实时获取（情绪：happy；进入商店随机挑一只）。
func _play_walk_in() -> void:
	var name: String = ANIMALS.pick_random()
	var url := "%s/v1/assets/images/animals/happy/%s.png?w=128" % [Backend.base_url, name]
	var tex: Texture2D = await Backend.fetch_texture(url)
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
