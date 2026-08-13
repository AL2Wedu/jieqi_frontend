class_name NpcDialog
extends PanelContainer
## 右下角：猫咪 NPC 提示框。

@onready var _text_label: Label = %NpcText


func set_message(text: String) -> void:
	_text_label.text = text
