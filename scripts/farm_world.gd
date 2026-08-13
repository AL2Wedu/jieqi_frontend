extends Control
## 农场背景容器：正式背景图为 BackgroundImage（cover 模式占满屏幕，不拉伸）。
## 如需程序化占位背景，可把下面的 _draw() 换成绘制代码；当前已停用。

func _ready() -> void:
	# 背景不参与输入，让上层 UI 正常接收点击。
	mouse_filter = MOUSE_FILTER_IGNORE
