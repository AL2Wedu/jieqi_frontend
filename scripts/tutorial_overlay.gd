extends Control
## 新手教学覆盖层：朝右下角手指指引 + 文字气泡（无遮罩，鼠标穿透）。
## 由 game.gd 驱动步骤：point_at(target, text) 指向某控件，玩家操作后 advance()。

signal tutorial_done

const VIEW_W := 720.0
const VIEW_H := 1280.0
const FINGER_SIZE := 110.0   # 手指图容器（指尖=图片右下角）
const FINGER_GAP := 8.0      # 指尖与目标中心的间距
const BUBBLE_GAP := 26.0

@onready var _finger: TextureRect = %Finger
@onready var _bubble: PanelContainer = %Bubble
@onready var _text: Label = %Text


func _ready() -> void:
	# 覆盖层与子节点全部穿透输入，让玩家能点到底下的功能
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_finger.visible = false
	_bubble.visible = false


## 指向某个控件，展示文字与手指。
func point_at(target: Control, text: String) -> void:
	visible = true
	_bubble.visible = true
	_text.text = text
	_update_finger(target)
	_update_bubble(target)


## 手指指尖（图片右下角）对准目标中心左上方，朝右下指向目标。
func _update_finger(target: Control) -> void:
	var center := target.get_global_rect().get_center()
	_finger.size = Vector2(FINGER_SIZE, FINGER_SIZE)
	_finger.position = center - Vector2(FINGER_SIZE + FINGER_GAP, FINGER_SIZE + FINGER_GAP)
	_finger.visible = true


## 气泡放在目标另一侧（目标在上→放下方；在下→放上方），并在屏内。
func _update_bubble(target: Control) -> void:
	var rect := target.get_global_rect()
	var center := rect.get_center()
	_bubble.reset_size()
	var bubble_size := _bubble.size
	var below: bool = center.y < VIEW_H / 2.0
	var bx := clampf(center.x - bubble_size.x / 2.0, 12.0, VIEW_W - bubble_size.x - 12.0)
	var by := 0.0
	if below:
		by = center.y + FINGER_SIZE / 2.0 + BUBBLE_GAP
	else:
		by = center.y - FINGER_SIZE / 2.0 - bubble_size.y - BUBBLE_GAP
	by = clampf(by, 12.0, VIEW_H - bubble_size.y - 12.0)
	_bubble.position = Vector2(bx, by)
	_bubble.visible = true


## 结束教学。
func finish() -> void:
	visible = false
	_finger.visible = false
	_bubble.visible = false
	tutorial_done.emit()
