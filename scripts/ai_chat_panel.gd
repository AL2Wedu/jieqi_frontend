extends Control
## AI 聊天面板：OpenAI 兼容对话（后端转发），显示可用模型与用量。
## 数据来源 POST /v1/ai/chat、GET /v1/ai/models、GET /v1/ai/usage。

signal close_requested

@onready var _chat_log: RichTextLabel = %ChatLog
@onready var _model_option: OptionButton = %ModelOption
@onready var _usage_label: Label = %UsageLabel
@onready var _input: LineEdit = %Input
@onready var _send: Button = %SendButton
@onready var _hint: Label = %Hint
@onready var _close: Button = %CloseButton
@onready var _dim: ColorRect = %Dim

var _sending := false


func _ready() -> void:
	_close.pressed.connect(func() -> void: close_requested.emit())
	_close.pressed.connect(func() -> void: hide())
	_dim.gui_input.connect(_on_dim_input)
	_send.pressed.connect(_on_send_pressed)
	_input.text_submitted.connect(func(_t: String) -> void: _on_send_pressed())
	_chat_log.bbcode_enabled = true


func open() -> void:
	visible = true
	await _load_models()
	await _load_usage()


func _load_models() -> void:
	var res := await Backend.ai_models()
	if not is_instance_valid(self):
		return
	if res.get("code", -1) != 0:
		return
	_model_option.clear()
	var models: Array = res["data"].get("models", [])
	if models.is_empty():
		_model_option.add_item("deepseek-chat")
		return
	for m in models:
		_model_option.add_item(str(m))
	_model_option.select(0)


func _load_usage() -> void:
	var res := await Backend.ai_usage()
	if not is_instance_valid(self):
		return
	if res.get("code", -1) != 0:
		return
	var total: Dictionary = res["data"].get("total", {})
	_usage_label.text = "请求 %d · 总 token %d" % [
		int(total.get("requests", 0)), int(total.get("total_tokens", 0))]


func _on_send_pressed() -> void:
	if _sending:
		return
	var text := _input.text.strip_edges()
	if text == "":
		return
	_input.text = ""
	_append_line("[b]你：[/b]%s" % text)
	_sending = true
	_send.disabled = true
	_hint.visible = true
	_hint.text = "思考中…"
	var model := _model_option.get_item_text(_model_option.selected)
	var res := await Backend.ai_chat({
		"model": model,
		"messages": [{ "role": "user", "content": text }],
	})
	if not is_instance_valid(self):
		return
	_sending = false
	_send.disabled = false
	_hint.visible = false
	if res.get("code", -1) != 0:
		_append_line("[color=#d84a2a]（错误：%s）[/color]" % Backend.friendly_message(res, "AI 不可用"))
		return
	_append_reply(res["data"])
	await _load_usage()


func _append_reply(data: Variant) -> void:
	if not (data is Dictionary):
		_append_line("[color=#4a6a2a]（AI：%s）[/color]" % str(data))
		return
	var choices: Array = data.get("choices", [])
	if choices.is_empty():
		_append_line("[color=#4a6a2a]（AI 返回异常）[/color]")
		return
	var first: Dictionary = choices[0]
	var message: Variant = first.get("message")
	if message is Dictionary:
		_append_line("[b]AI：[/b]%s" % str(message.get("content", "")))
	else:
		_append_line("[b]AI：[/b]%s" % str(first))


func _append_line(line: String) -> void:
	_chat_log.append_text(line + "\n")


## 点击遮罩关闭。
func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close_requested.emit()
		hide()
