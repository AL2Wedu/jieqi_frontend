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
@onready var _countdown_label: Label = %CountdownLabel
@onready var _unlocked_label: Label = %UnlockedLabel
@onready var _temp_label: Label = %TempLabel
@onready var _humidity_bar: ProgressBar = %HumidityBar
@onready var _humidity_label: Label = %HumidityValue
@onready var _gold_label: Label = %GoldValue
@onready var _level_label: Label = %LevelValue
@onready var _exp_bar: ProgressBar = %ExpBar
@onready var _exp_label: Label = %ExpValue


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


func set_gold(gold: int) -> void:
	_gold_label.text = str(gold)


## 等级 / 经验（EXP 条上限为展示用启发值，后端无阈值）。
func set_level(level: int) -> void:
	_level_label.text = "Lv.%d" % level


func set_exp(exp: int, exp_next: int = 0) -> void:
	var next := exp_next if exp_next > 0 else 50 + int(_level_label.text.trim_prefix("Lv.")) * 50
	_exp_bar.max_value = next
	_exp_bar.value = clampi(exp, 0, next)
	_exp_label.text = "%d/%d" % [exp, next]


## 解锁节气（term_index 0-23）。
func set_unlocked_term(term_index: int) -> void:
	if term_index < 0 or term_index >= TERM_TEXTURES.size():
		return
	_unlocked_label.text = "解锁至：%s" % [
		"立春","雨水","惊蛰","春分","清明","谷雨",
		"立夏","小满","芒种","夏至","小暑","大暑",
		"立秋","处暑","白露","秋分","寒露","霜降",
		"立冬","小雪","大雪","冬至","小寒","大寒",
	][term_index]


## 本轮节气剩余秒倒计时（秒）。
func set_remaining_sec(sec: int) -> void:
	var s := maxi(0, sec)
	var mm := s / 60
	var ss := s % 60
	_countdown_label.text = "本轮剩余 %02d:%02d" % [mm, ss]
