extends Node
## 全局音效单例（autoload Sfx）：程序生成 16-bit PCM 短音，播放时遵循设置开关。
## 无任何音频素材依赖；节拍 tick / Perfect / Good / Miss 判定音（大虫害音游用）。

const RATE := 44100
const POOL_SIZE := 6

var _streams: Dictionary = {}  # 音名 -> AudioStreamWAV
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	_streams["tick"] = _tone(880.0, 0.06, 0.30, 45.0)      # 节拍：短促高音
	_streams["tap"] = _tone(500.0, 0.05, 0.35, 40.0)      # 小虫害连击点击：短促中音
	_streams["perfect"] = _chime([1046.5, 1318.5], [0.10, 0.16], 0.40)  # C6→E6 上行双音
	_streams["good"] = _tone(660.0, 0.10, 0.32, 30.0)     # 单中音
	_streams["miss"] = _tone(220.0, 0.22, 0.40, 12.0)     # 低频下坠感
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.volume_db = -6.0
		add_child(p)
		_players.append(p)


## 播放音效（设置关闭时静默）。
func play(name: String) -> void:
	if not Backend.is_sfx_enabled():
		return
	var s: AudioStreamWAV = _streams.get(name)
	if s == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = s
	p.play()


## 生成单音：正弦波 × 指数衰减包络（避免爆音）。
func _tone(freq: float, dur: float, vol: float, decay: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / RATE
		var env := exp(-t * decay)
		var s := sin(TAU * freq * t) * vol * env
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	return _make_wav(data)


## 生成双音（Perfect 上行琶音）：两段音拼接进同一缓冲。
func _chime(freqs: Array, durs: Array, vol: float) -> AudioStreamWAV:
	var total := 0
	for d in durs:
		total += int(d * RATE)
	var data := PackedByteArray()
	data.resize(total * 2)
	var off := 0
	for k in freqs.size():
		var n := int(durs[k] * RATE)
		for i in n:
			var t := float(i) / RATE
			var env := exp(-t * 25.0)
			var s := sin(TAU * freqs[k] * t) * vol * env
			data.encode_s16((off + i) * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
		off += n
	return _make_wav(data)


func _make_wav(data: PackedByteArray) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav
