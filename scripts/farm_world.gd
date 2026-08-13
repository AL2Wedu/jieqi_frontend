class_name FarmWorld
extends Control
## 农场背景容器：按季节渐变切换背景图。
## 背景层为 BackgroundImage（基础/春季），切换时 SeasonLayer 淡入新图，
## 淡入完成后把新图落到 BackgroundImage 并清空 SeasonLayer。

const FADE_SECONDS := 1.2

const SEASON_TEXTURES := {
	0: preload("res://assets/farm/farm_bg_spring.png"),  # 春（立春..谷雨）
	1: preload("res://assets/farm/farm_bg_summer.png"),  # 夏（立夏..大暑）
	2: preload("res://assets/farm/farm_bg_autumn.png"),  # 秋（立秋..霜降）
	3: preload("res://assets/farm/farm_bg_winter.png"),  # 冬（立冬..大寒）
}

var _current_season := 0
var _tween: Tween = null

@onready var _base: TextureRect = $BackgroundImage
@onready var _layer: TextureRect = $SeasonLayer


func _ready() -> void:
	# 背景不参与输入，让上层 UI 正常接收点击。
	mouse_filter = MOUSE_FILTER_IGNORE
	_layer.modulate.a = 0.0


## 根据节气下标（0-23）设置季节背景。
func set_season_by_term(term_index: int) -> void:
	var season := clampi(term_index / 6, 0, 3)
	if season == _current_season:
		return
	_current_season = season
	_crossfade(SEASON_TEXTURES[season])


## 渐变切到新背景：SeasonLayer 淡入，完成后把新图落到基础层。
func _crossfade(new_tex: Texture2D) -> void:
	_layer.texture = new_tex
	_layer.modulate.a = 0.0
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_layer, "modulate:a", 1.0, FADE_SECONDS)
	_tween.tween_callback(func() -> void:
		_base.texture = _layer.texture
		_layer.modulate.a = 0.0)
