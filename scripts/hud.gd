class_name Hud
extends Control
## 顶部 HUD：显示当前节气、日期、资源等信息（数据均为占位）。

@onready var _season_label: Label = $MarginContainer/HBoxContainer/SeasonLabel
@onready var _date_label: Label = $MarginContainer/HBoxContainer/DateLabel
@onready var _resource_label: Label = $MarginContainer/HBoxContainer/ResourceLabel
@onready var _settings_button: Button = $MarginContainer/HBoxContainer/SettingsButton

# 二十四节气名称，占位展示用。
const SOLAR_TERMS: Array[String] = [
	"立春", "雨水", "惊蛰", "春分", "清明", "谷雨",
	"立夏", "小满", "芒种", "夏至", "小暑", "大暑",
	"立秋", "处暑", "白露", "秋分", "寒露", "霜降",
	"立冬", "小雪", "大雪", "冬至", "小寒", "大寒",
]

var _current_term_index: int = 0
var _resource_amount: int = 0


func _ready() -> void:
	_settings_button.pressed.connect(_on_settings_pressed)
	_refresh()


## 刷新 HUD 显示。
func _refresh() -> void:
	_season_label.text = SOLAR_TERMS[_current_term_index]
	_date_label.text = "第 %d / 24 候" % (_current_term_index + 1)
	_resource_label.text = "灵气 %d" % _resource_amount


## 推进到下一个节气（占位接口，供游戏逻辑调用）。
func advance_season() -> void:
	_current_term_index = (_current_term_index + 1) % SOLAR_TERMS.size()
	_refresh()


## 增加资源（占位接口，供游戏逻辑调用）。
func add_resource(amount: int) -> void:
	_resource_amount += amount
	_refresh()


func _on_settings_pressed() -> void:
	print("[HUD] 设置按钮被点击（占位）")
