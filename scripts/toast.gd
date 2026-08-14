extends Control
## 顶部居中的事件提示条：逐条显示，淡入 → 停留 → 淡出。
## game.gd 用 show_message() 提示枯萎/杂草/虫害等事件。

@onready var _panel: PanelContainer = %ToastPanel
@onready var _label: Label = %ToastLabel

var _queue: Array[Dictionary] = []
var _showing := false
var _tween: Tween = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false


## 追加一条提示（顶部居中，自动排队）。
func show_message(text: String, duration: float = 3.0) -> void:
	_queue.append({ "text": text, "duration": duration })
	_process_queue()


func _process_queue() -> void:
	if _showing or _queue.is_empty():
		return
	_showing = true
	var item: Dictionary = _queue.pop_front()
	_label.text = str(item["text"])
	_panel.visible = true
	_panel.modulate.a = 0.0
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_panel, "modulate:a", 1.0, 0.2)
	_tween.tween_interval(float(item.get("duration", 3.0)))
	_tween.tween_property(_panel, "modulate:a", 0.0, 0.3)
	_tween.tween_callback(func() -> void:
		_panel.visible = false
		_showing = false
		_process_queue())
