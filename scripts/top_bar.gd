class_name TopBar
extends PanelContainer
## 顶部信息栏：季节牌 + 日期天气湿度 + 资源。

@onready var _date_label: Label = %DateLabel
@onready var _temp_label: Label = %TempLabel
@onready var _humidity_bar: ProgressBar = %HumidityBar
@onready var _humidity_label: Label = %HumidityValue
@onready var _gold_label: Label = %GoldValue
@onready var _energy_label: Label = %EnergyValue
@onready var _water_label: Label = %WaterValue


func set_season(_name_text: String) -> void:
	# 季节已由季节牌图片直接展示，文字标签已移除。
	pass


func set_date(date_text: String) -> void:
	_date_label.text = date_text


func set_temperature(celsius: int) -> void:
	_temp_label.text = "%d°C" % celsius


func set_humidity(percent: int) -> void:
	_humidity_bar.value = percent
	_humidity_label.text = "%d%%" % percent


func set_resources(gold: int, energy: String, water: int) -> void:
	_gold_label.text = str(gold)
	_energy_label.text = energy
	_water_label.text = str(water)
