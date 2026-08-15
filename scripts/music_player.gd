extends Node
## 全局背景音乐单例（autoload Music）。
## 遵循设置的「音乐」开关；进出商店加载动画期间暂停（进度条区域不播放），动画结束恢复。

const BGM := preload("res://assets/audio/bgm.wav")

var _player: AudioStreamPlayer = null
var _paused_for_loading := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.stream = BGM
	_player.volume_db = -8.0
	add_child(_player)
	Backend.music_enabled_changed.connect(_on_music_setting)
	_refresh_playing()


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
