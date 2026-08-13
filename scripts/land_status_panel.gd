class_name LandStatusPanel
extends PanelContainer
## 左下角：当前选中地块的肥力 / 湿度 / 健康。

@onready var _fertility: ProgressBar = %FertilityBar
@onready var _humidity: ProgressBar = %HumidityBar
@onready var _health: ProgressBar = %HealthBar
@onready var _fertility_value: Label = %FertilityValue
@onready var _humidity_value: Label = %HumidityValue
@onready var _health_value: Label = %HealthValue


func set_stats(fertility: int, humidity: int, health: int) -> void:
	_fertility.value = fertility
	_humidity.value = humidity
	_health.value = health
	_fertility_value.text = "%d%%" % fertility
	_humidity_value.text = "%d%%" % humidity
	_health_value.text = "%d%%" % health
