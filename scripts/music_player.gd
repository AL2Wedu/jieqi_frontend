extends Node
## 全局背景音乐单例（autoload Music）。
## 遵循设置的「音乐」开关；进出商店加载动画期间暂停（进度条区域不播放），动画结束恢复。
## 启动先播本地压缩 mp3（小包体），后台从后端拉大 wav 后无缝替换（不阻塞首载）。

const BGM_LOW := preload("res://assets/audio/bgm.mp3")

var _player: AudioStreamPlayer = null
var _paused_for_loading := false
var _swapped := false  # 是否已换成高音质 wav


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.stream = BGM_LOW
	_player.volume_db = -8.0
	add_child(_player)
	Backend.music_enabled_changed.connect(_on_music_setting)
	_refresh_playing()
	fetch_high_quality()  # 后台拉大 wav，不阻塞


## 后台下载高音质 wav 并替换（失败静默，继续用 mp3）。
func fetch_high_quality() -> void:
	if _swapped:
		return
	var bytes := await Backend.download_audio("bgm", "main", "wav")
	if bytes.is_empty() or not is_instance_valid(_player):
		return
	var wav := _wav_from_bytes(bytes)
	if wav == null:
		return
	_swapped = true
	var was_playing := _player.playing
	var pos := _player.get_playback_position()
	_player.stream = wav
	if was_playing and not _paused_for_loading:
		_player.play(pos)


## 解析 WAV 头构造 AudioStreamWAV（PCM 16-bit）。
func _wav_from_bytes(bytes: PackedByteArray) -> AudioStreamWAV:
	if bytes.size() < 44:
		return null
	if bytes.slice(0, 4).get_string_from_utf8() != "RIFF" or bytes.slice(8, 12).get_string_from_utf8() != "WAVE":
		return null
	var channels := bytes.decode_u16(22)
	var sample_rate := bytes.decode_u32(24)
	var bits := bytes.decode_u16(34)
	if bits != 16:
		return null  # 仅支持 16-bit PCM
	# 定位 data 块
	var pos := 12
	var data_start := -1
	var data_size := 0
	while pos + 8 <= bytes.size():
		var chunk := bytes.slice(pos, pos + 4).get_string_from_utf8()
		var size := bytes.decode_u32(pos + 4)
		if chunk == "data":
			data_start = pos + 8
			data_size = size
			break
		pos += 8 + size + (size & 1)
	if data_start < 0:
		return null
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = channels == 2
	wav.data = bytes.slice(data_start, data_start + data_size)
	return wav


func _on_music_setting(on: bool) -> void:
	if not on:
		_player.stop()
	elif not _paused_for_loading:
		_player.play()


## 进入商店加载动画：暂停（重置进度），加载页区域不播放。
func pause_for_loading() -> void:
	_paused_for_loading = true
	_player.stop()


## 退出加载动画：按设置恢复播放（从头开始）。
func resume_after_loading() -> void:
	_paused_for_loading = false
	if Backend.is_music_enabled():
		_player.play()


## 依当前设置启停（启动时 / 开关变化时）。
func _refresh_playing() -> void:
	if Backend.is_music_enabled() and not _paused_for_loading:
		_player.play()
	else:
		_player.stop()
