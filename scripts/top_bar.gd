class_name TopBar
extends PanelContainer
## 顶部信息栏：季节牌 + 日期天气湿度 + 资源。
## 季节牌按节气切换（24 张真实素材）。

const TERM_TEXTURES: Array[Texture2D] = [
	preload("res://assets/terms/lichun.png"),        # 立春
	preload("res://assets/terms/yushui.png"),        # 雨水
	preload("res://assets/terms/jingzhe.png"),       # 惊蛰
	preload("res://assets/terms/chunfen.png"),       # 春分
	preload("res://assets/terms/qingming.png"),      # 清明
	preload("res://assets/terms/guyu.png"),          # 谷雨
	preload("res://assets/terms/lixia.png"),         # 立夏
	preload("res://assets/terms/xiaoman.png"),       # 小满
	preload("res://assets/terms/mangzhong.png"),     # 芒种
	preload("res://assets/terms/xiazhi.png"),        # 夏至
	preload("res://assets/terms/xiaoshu.png"),       # 小暑
	preload("res://assets/terms/dashu.png"),         # 大暑
	preload("res://assets/terms/liqiu.png"),         # 立秋
	preload("res://assets/terms/chushu.png"),        # 处暑
	preload("res://assets/terms/bailu.png"),         # 白露
	preload("res://assets/terms/qiufen.png"),        # 秋分
	preload("res://assets/terms/hanlu.png"),         # 寒露
	preload("res://assets/terms/shuangjiang.png"),   # 霜降
	preload("res://assets/terms/lidong.png"),        # 立冬
	preload("res://assets/terms/xiaoxue.png"),       # 小雪
	preload("res://assets/terms/daxue.png"),         # 大雪
	preload("res://assets/terms/dongzhi.png"),       # 冬至
	preload("res://assets/terms/xiaohan.png"),       # 小寒
	preload("res://assets/terms/dahan.png"),         # 大寒
]

@onready var _plaque: TextureRect = %SeasonPlaque
@onready var _date_label: Label = %DateLabel
@onready var _temp_label: Label = %TempLabel
@onready var _humidity_bar: ProgressBar = %HumidityBar
@onready var _humidity_label: Label = %HumidityValue
@onready var _gold_label: Label = %GoldValue
@onready var _energy_label: Label = %EnergyValue
@onready var _water_label: Label = %WaterValue


## 设置季节牌贴图（term_index 0-23，按节气切换）。
func set_season(term_index: int) -> void:
	if term_index < 0 or term_index >= TERM_TEXTURES.size():
		return
	_plaque.texture = TERM_TEXTURES[term_index]


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
