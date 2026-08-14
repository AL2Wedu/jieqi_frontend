extends Control
## 商店占位界面（内容待做）。

signal close_requested


func _ready() -> void:
	%CloseButton.pressed.connect(_close)
	$Dim.gui_input.connect(_on_dim_input)


func _close() -> void:
	visible = false
	close_requested.emit()


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_close()
