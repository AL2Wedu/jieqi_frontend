extends Node
## 后端 API 客户端（autoload 单例 Backend）。
## 封装 HTTP 请求与节气 WebSocket，供各场景 await 调用。

## 服务器地址：桌面调试默认本机。真机（Android）请改成电脑/服务器的局域网 IP，
## 或用环境变量 JIEQI_SERVER 覆盖（adb / 导出时注入）。
var base_url := "http://127.0.0.1:8000"
var api := ""
var ws_url := ""

const SAVE_PATH := "user://player.json"
const ART_VERSION_FILE := "user://art_version.json"
const SETTINGS_FILE := "user://settings.json"
const REQUEST_TIMEOUT := 10
const TERM_POLL_SECONDS := 20.0
const WS_PING_SECONDS := 30.0
const APP_VERSION := "1.0.0"

signal term_changed(payload: Dictionary)
## 资源权威变更：管理后台编辑玩家资产 → 强制刷新 /player/me 成功后发出，携带最新玩家数据。
signal resources_changed(player_data: Dictionary)
## 服务端主动推送的农场事件（虫害/枯萎/杂草），payload 为事件自带字段。
signal pest_big_event(payload: Dictionary)
signal pest_small_event(payload: Dictionary)
signal pest_destroyed_event(payload: Dictionary)
signal crop_withered_event(payload: Dictionary)
signal weed_growth_event(payload: Dictionary)
signal auth_expired
## 音乐开关变化（设置面板改时发出，供 Music 单例响应）。
signal music_enabled_changed(on: bool)

var token := ""
var player: Dictionary = {}
var current_term: Dictionary = {}

# 本地设置：服务器地址 / 音乐 / 音效（设置面板可改，持久化到 user://settings.json）。
var settings: Dictionary = {}

var _socket: WebSocketPeer = null
var _ws_timer: Timer = null
var _ws_ping_timer: Timer = null
var _term_poll_timer: Timer = null

# 素材缓存：当前已下载到的素材版本（决定缓存目录）。
var _cache_version := ""
var _art_checking := false

## 玩家可达错误码 → 用户友好文案（统一错误文案层）。
## 命中映射用前端文案（不依赖后端 message 的中文质量）；
## 未命中回退后端 message；再兜底调用方 fallback。
## 与后端 API.md 第 11 章错误码全表对应；管理端/调试码（3xxxx、22005 等）不进表。
const ERROR_MESSAGES := {
	# 1xxxx 通用
	"UNAUTHORIZED": "登录已失效，请重新登录",
	"INVALID_PARAMS": "参数不合法，请检查输入",
	# 2xxxx 账号 / 农场 / 商店
	"USER_EXISTS": "该名字已被注册，试试登录",
	"USER_NOT_FOUND": "账号不存在",
	"BAD_CREDENTIALS": "密码错误",
	"USER_BANNED": "账号已被封禁",
	"FARM_NOT_FOUND": "农场数据不存在",
	"PLOT_NOT_FOUND": "这块地不存在或未解锁",
	"PLOT_OCCUPIED": "这块地已经有作物了",
	"CROP_NOT_AVAILABLE": "当前节气不宜种植这种作物",
	"PLOT_EMPTY": "这块地没有作物",
	"CROP_NOT_FOUND": "没有找到这种作物",
	"SEED_NOT_FOUND": "找不到对应的种子，先买种子吧",
	"NOT_ENOUGH_ITEM": "道具不足，先去商店购买吧",
	"CROP_LOCKED": "这种作物还没解锁，继续升级吧",
	"NOT_ENOUGH_COINS": "金币不足",
	"ITEM_NOT_FOUND": "道具或商品不存在",
	"NOT_ENOUGH_STOCK": "商店缺货了，稍后再来",
	"NOT_ENOUGH_CROP": "收成仓里数量不足",
	"CROP_NOT_MATURE": "作物还没成熟，再等等吧",
	"EFFECT_NOT_SUPPORTED": "这个道具的效果还不支持使用",
	"TERM_NOT_FOUND": "节气数据不存在",
	# 24xxx-27xxx 扩展玩法
	"AI_DISABLED": "节气助手未启用",
	"AI_NOT_CONFIGURED": "节气助手还没配置好，请稍后再试",
	"AI_UPSTREAM_ERROR": "AI 服务暂时不可用，请稍后再试",
	"QUEST_NOT_FOUND": "任务不存在",
	"QUEST_NOT_COMPLETE": "任务还没完成，继续加油",
	"QUEST_ALREADY_CLAIMED": "任务奖励已经领过了",
	"ACHIEVEMENT_NOT_FOUND": "成就不存在",
	"ACHIEVEMENT_NOT_COMPLETE": "成就还没达成",
	"ACHIEVEMENT_ALREADY_CLAIMED": "成就奖励已经领过了",
	"ALREADY_FRIENDS": "你们已经是好友了",
	"REQUEST_EXISTS": "好友申请已发送，等待对方处理",
	"REQUEST_NOT_FOUND": "申请不存在或已处理",
	"NOT_YOUR_REQUEST": "这不是发给你的申请",
	"FRIEND_NOT_FOUND": "好友关系不存在",
	# 28xxx 虫害 / 素材
	"ART_NOT_FOUND": "素材加载失败",
	"PEST_DISABLED": "虫害系统未启用",
	"PEST_BUSY": "已有进行中的虫害",
	"PEST_NO_TARGET": "没有可寄生的作物",
	"PEST_NOT_FOUND": "虫害事件不存在或已结束",
	"PEST_RESULT_TOO_FAST": "提交太快了，稍后再试",
	"PEST_TARGET_NOT_FOUND": "寄生目标不存在或已处理",
	# 9xxxx 系统
	"INTERNAL_ERROR": "服务器开小差了，请稍后再试",
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	# 优先级：环境变量 JIEQI_SERVER > 本地设置里的服务器地址 > 硬编码默认
	var env := OS.get_environment("JIEQI_SERVER")
	if env == "":
		env = str(settings.get("server", ""))
	if env != "":
		base_url = env
	api = base_url + "/v1"
	ws_url = base_url.replace("http", "ws") + "/v1/ws"
	load_local()
	_cache_version = str(_load_json_file(ART_VERSION_FILE).get("version", ""))
	if token != "":
		start_term_poll()


func _process(_delta: float) -> void:
	if _socket == null:
		return
	_socket.poll()
	match _socket.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			while _socket.get_available_packet_count() > 0:
				var packet: Variant = _socket.get_packet()
				if packet is PackedByteArray:
					_handle_ws_message(packet.get_string_from_utf8())
		WebSocketPeer.STATE_CLOSED:
			# 4401 = token 无效/过期（服务器主动关闭）：停止重连并强制重新登录
			if _socket.get_close_code() == 4401:
				_handle_auth_expired()
				return
			# 其他断线后 3 秒自动重连
			if _ws_timer == null:
				_ws_timer = Timer.new()
				_ws_timer.one_shot = true
				_ws_timer.wait_time = 3.0
				_ws_timer.timeout.connect(_reconnect_ws)
				add_child(_ws_timer)
				_ws_timer.start()


## ---------------- 通用请求 ----------------

## 发起请求，返回响应信封 Dictionary（code/message/data）。
## 网络失败返回 {code:-1, message:"无法连接服务器"}。
func request(method: String, path: String, body: Variant = {}, authed := true) -> Dictionary:
	var req := HTTPRequest.new()
	req.timeout = REQUEST_TIMEOUT
	add_child(req)
	var url := api + path
	var headers := PackedStringArray(["Content-Type: application/json"])
	if authed and token != "":
		headers.append("Authorization: Bearer %s" % token)

	var err := OK
	var http_method := HTTPClient.METHOD_GET
	match method:
		"POST":
			http_method = HTTPClient.METHOD_POST
		"DELETE":
			http_method = HTTPClient.METHOD_DELETE
	var has_body: bool = not (body.is_empty() and (method == "GET" or method == "DELETE"))
	if not has_body:
		err = req.request(url, headers)
	else:
		err = req.request(url, headers, http_method, JSON.stringify(body))
	if err != OK:
		req.queue_free()
		return { "code": -1, "message": "请求失败(%d)" % err }

	var response: Array = await req.request_completed
	req.queue_free()
	var result: int = response[0]
	var status: int = response[1]
	var response_body: PackedByteArray = response[3]
	if result != HTTPRequest.RESULT_SUCCESS:
		return { "code": -1, "message": "无法连接服务器" }
	if status < 200 or status >= 300:
		# 业务错误也走 JSON 信封
		var data: Variant = JSON.parse_string(response_body.get_string_from_utf8())
		if data is Dictionary:
			var result_dict: Dictionary = data
			# 玩家 token 失效（未登录 / 过期，HTTP 401）或账号被封禁（HTTP 403 + USER_BANNED）：
			# 清 token 并通知上层重新登录
			if authed and _is_auth_failure(status, result_dict):
				_handle_auth_expired()
			return result_dict
		if authed and status == 401:
			_handle_auth_expired()
		return { "code": status, "message": "HTTP %d" % status }
	var parsed: Variant = JSON.parse_string(response_body.get_string_from_utf8())
	if parsed is Dictionary:
		return parsed
	return { "code": -1, "message": "响应解析失败" }


## 是否鉴权失效：401 任意（未登录/过期）；403 仅当 error_code=USER_BANNED
## （封禁是 403 而非 401，其余 403 如 ADMIN_DISABLED/DEBUG_DISABLED 不踢出）。
func _is_auth_failure(status: int, body: Dictionary) -> bool:
	if status == 401:
		return true
	return status == 403 and str(body.get("error_code", "")) == "USER_BANNED"


## 统一错误文案：优先 ERROR_MESSAGES 映射表（前端文案），
## 未命中用后端 message，再兜底 fallback。
func friendly_message(res: Dictionary, fallback: String) -> String:
	var mapped: String = ERROR_MESSAGES.get(str(res.get("error_code", "")), "")
	if mapped != "":
		return mapped
	var msg := str(res.get("message", ""))
	if msg != "":
		return msg
	return fallback


## 下载图片二进制（失败返回空数组）。
func _download_png(url: String) -> PackedByteArray:
	var req := HTTPRequest.new()
	req.timeout = REQUEST_TIMEOUT
	add_child(req)
	var err := req.request(url)
	if err != OK:
		req.queue_free()
		return PackedByteArray()
	var response: Array = await req.request_completed
	req.queue_free()
	if response[0] != HTTPRequest.RESULT_SUCCESS or response[1] != 200:
		return PackedByteArray()
	var body: PackedByteArray = response[3]
	if body.size() == 0:
		return PackedByteArray()
	return body


## 下载图片为 Texture2D（失败返回 null）。
func fetch_texture(url: String) -> Texture2D:
	var bytes := await _download_png(url)
	return _texture_from_bytes(bytes)


## ---------------- 认证 ----------------

func login(name: String, password: String) -> Dictionary:
	return await request("POST", "/auth/login", { "name": name, "password": password }, false)


func register(name: String, password: String) -> Dictionary:
	return await request("POST", "/auth/register", { "name": name, "password": password }, false)


## 登录/注册成功后接入（保存 token、启动 WS、拉取节气、检查素材更新）。
func on_login_success(new_token: String, new_player: Dictionary) -> void:
	token = new_token
	player = new_player
	save_local()
	start_ws()
	start_term_poll()
	_auto_refresh_term()
	check_art_updates()


func has_token() -> bool:
	return token != ""


## 玩家 token 失效：清空本地登录态并通知上层重新登录。
func _handle_auth_expired() -> void:
	if token == "":
		return
	logout()
	auth_expired.emit()


func logout() -> void:
	token = ""
	player = {}
	current_term = {}
	_stop_ws()
	_stop_term_poll()
	_save_to_file({})


## ---------------- 数据读取 ----------------

func get_calendar() -> Dictionary:
	return await request("GET", "/calendar/current")


func get_player_me() -> Dictionary:
	return await request("GET", "/player/me")


func get_farm_state() -> Dictionary:
	return await request("GET", "/farm/state")


func get_shop() -> Dictionary:
	return await request("GET", "/shop/items")


func get_inventory() -> Dictionary:
	return await request("GET", "/player/inventory")


## 收成仓（收获入仓 + 当前收购价）。
func get_storage() -> Dictionary:
	return await request("GET", "/shop/storage")


## ---------------- 农场操作 ----------------

func buy(item_id: String, quantity := 1) -> Dictionary:
	return await request("POST", "/shop/items/%s/buy" % item_id, { "quantity": quantity })


func sow(plot_id: String, crop_id: String) -> Dictionary:
	return await request("POST", "/farm/plots/%s/sow" % plot_id, { "crop_id": crop_id })


func water(plot_id: String) -> Dictionary:
	return await request("POST", "/farm/plots/%s/water" % plot_id)


func harvest(plot_id: String) -> Dictionary:
	return await request("POST", "/farm/plots/%s/harvest" % plot_id)


func use_item(item_id: String, plot_id: String) -> Dictionary:
	return await request("POST", "/player/inventory/%s/use" % item_id, { "target": { "plot_id": plot_id } })


func clear_plot(plot_id: String) -> Dictionary:
	return await request("POST", "/farm/plots/%s/clear" % plot_id)


## 清除单个地块杂草（POST /farm/plots/{id}/weed-clear）。
func clear_weed(plot_id: String) -> Dictionary:
	return await request("POST", "/farm/plots/%s/weed-clear" % plot_id)


## ---------------- 虫害 ----------------

## 我的虫害状态：下次触发 / 进行中的大虫害 / 寄生中的小虫害地块。
func get_pest_state() -> Dictionary:
	return await request("GET", "/pest/state")


## 大虫害成绩提交（音游结束）。当前未做音游，弃战时提交 0/100/0。
func submit_pest_result(pest_id: String, score: int, max_score: int, miss_count: int) -> Dictionary:
	return await request("POST", "/farm/pest/%s/result" % pest_id,
		{ "score": score, "max_score": max_score, "miss_count": miss_count })


## 驱赶小虫害（寄生在地块 plot_id 上）。
func drive_away(pest_id: String, plot_id: String) -> Dictionary:
	return await request("POST", "/farm/pest/%s/drive-away" % pest_id, { "plot_id": plot_id })


## ---------------- 商店 / 收成仓 ----------------

## 我的商店完整状态：商品（库存/售价）+ 作物收购价 + 当前季节。
func get_shop_state() -> Dictionary:
	return await request("GET", "/shop/state")


## 出售收成仓作物（按当前季节/分类收购价结算）。
func sell_crop(crop_id: String, quantity: int) -> Dictionary:
	return await request("POST", "/shop/crops/%s/sell" % crop_id, { "quantity": quantity })


## ---------------- 任务 / 成就 ----------------

func get_quests() -> Dictionary:
	return await request("GET", "/quests")


func claim_quest(quest_id: String) -> Dictionary:
	return await request("POST", "/quests/%s/claim" % quest_id)


func get_achievements() -> Dictionary:
	return await request("GET", "/achievements")


func claim_achievement(achievement_id: String) -> Dictionary:
	return await request("POST", "/achievements/%s/claim" % achievement_id)


## ---------------- 好友 ----------------

func get_friends() -> Dictionary:
	return await request("GET", "/social/friends")


func get_friend_requests() -> Dictionary:
	return await request("GET", "/social/requests")


func send_friend_request(player_id: String) -> Dictionary:
	return await request("POST", "/social/requests", { "player_id": player_id })


func accept_friend(player_id: String) -> Dictionary:
	return await request("POST", "/social/requests/%s/accept" % player_id)


func reject_friend(player_id: String) -> Dictionary:
	return await request("POST", "/social/requests/%s/reject" % player_id)


func remove_friend(player_id: String) -> Dictionary:
	return await request("DELETE", "/social/friends/%s" % player_id)


## ---------------- AI 聊天 ----------------

## OpenAI 兼容对话转发：请求体透传，响应原样返回。
func ai_chat(payload: Dictionary) -> Dictionary:
	return await request("POST", "/ai/chat", payload)


func ai_models() -> Dictionary:
	return await request("GET", "/ai/models")


func ai_usage() -> Dictionary:
	return await request("GET", "/ai/usage")


## ---------------- 作物美术（版本 + 本地缓存） ----------------

## 从 crop.art 路径提取 slug（路径倒数第二段，如 shuidao）。
func crop_slug(crop: Dictionary) -> String:
	var art: Dictionary = crop.get("art", {})
	var path := ""
	var stages: Array = art.get("stages", [])
	if not stages.is_empty():
		path = str(stages[0])
	elif art.get("seed", "") != "":
		path = str(art.get("seed", ""))
	if path == "":
		return ""
	var parts := path.split("/")
	if parts.size() < 2:
		return ""
	return parts[parts.size() - 2]


## 拉取当前全服素材版本（§8.3）。
func get_art_version() -> Dictionary:
	return await request("GET", "/art/version", {}, false)


## 取某作物某素材：优先本地缓存，未命中则下载并缓存。
## name: "seed" / "1" / "2" / "3"；w 为目标像素。
func get_art_texture(slug: String, name: String, w: int) -> Texture2D:
	var cache_path := _art_cache_path(slug, name, w)
	if cache_path != "" and FileAccess.file_exists(cache_path):
		var tex := _texture_from_file(cache_path)
		if tex != null:
			return tex
	var url := "%s/v1/art/crops/%s/%s.png?w=%d" % [base_url, slug, name, w]
	var bytes := await _download_png(url)
	if bytes.is_empty():
		return null
	if cache_path != "":
		_save_file(cache_path, bytes)
	return _texture_from_bytes(bytes)


## 取地块作物贴图（按 stage 1-3）。
func get_crop_art_texture(crop: Dictionary, stage: int, w: int) -> Texture2D:
	var slug := crop_slug(crop)
	if slug == "":
		return null
	return await get_art_texture(slug, str(clampi(stage, 1, 3)), w)


## 取作物种子图标。
func get_seed_art_texture(crop: Dictionary, w: int) -> Texture2D:
	var slug := crop_slug(crop)
	if slug == "":
		return null
	return await get_art_texture(slug, "seed", w)


## 检查素材更新：版本变化时后台下载并缓存（非阻塞，登录/节气切换时调用）。
## version 变 → 全量；仅某作物变 → 只刷新该作物。
func check_art_updates() -> void:
	if _art_checking:
		return
	_art_checking = true
	var res: Dictionary = await get_art_version()
	if res.get("code", -1) != 0:
		_art_checking = false
		return
	var data: Dictionary = res["data"]
	var version := str(data.get("version", ""))
	var crops: Dictionary = data.get("crops", {})
	var local := _load_json_file(ART_VERSION_FILE)
	var local_version := str(local.get("version", ""))
	var local_crops: Dictionary = local.get("crops", {})

	var changed: Array[String] = []
	for slug in crops.keys():
		if local_version != version or str(local_crops.get(slug, "")) != str(crops[slug]):
			changed.append(str(slug))
	if changed.is_empty():
		_art_checking = false
		return

	_cache_version = version
	var dir := "user://art_cache/%s" % version
	DirAccess.make_dir_recursive_absolute(dir)
	for slug in changed:
		await _download_crop_set(str(slug), dir)
	_save_json_file(ART_VERSION_FILE, { "version": version, "crops": crops })
	_art_checking = false


## 下载某作物整套素材（种子 w64 + 三个阶段 w128）到缓存目录。
func _download_crop_set(slug: String, dir: String) -> void:
	await _download_crop_art(slug, "seed", 64, dir)
	for stage in [1, 2, 3]:
		await _download_crop_art(slug, str(stage), 128, dir)


func _download_crop_art(slug: String, name: String, w: int, dir: String) -> void:
	var url := "%s/v1/art/crops/%s/%s.png?w=%d" % [base_url, slug, name, w]
	var bytes := await _download_png(url)
	if bytes.is_empty():
		return
	_save_file("%s/%s_%s_%d.png" % [dir, slug, name, w], bytes)


func _art_cache_path(slug: String, name: String, w: int) -> String:
	if _cache_version == "":
		return ""
	return "user://art_cache/%s/%s_%s_%d.png" % [_cache_version, slug, name, w]


func _texture_from_file(path: String) -> Texture2D:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var bytes := f.get_buffer(f.get_length())
	f.close()
	return _texture_from_bytes(bytes)


func _texture_from_bytes(bytes: PackedByteArray) -> Texture2D:
	if bytes.is_empty():
		return null
	var image := Image.new()
	if image.load_png_from_buffer(bytes) != OK:
		return null
	return ImageTexture.create_from_image(image)


func _save_file(path: String, bytes: PackedByteArray) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_buffer(bytes)
		f.close()


## ---------------- 节气 WebSocket ----------------

## 确保 WS 已连接（直接进游戏、跳过登录时也要启动）。
func ensure_ws() -> void:
	if _socket != null and _socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		return
	start_ws()


## 启动节气轮询兜底：WS 广播之外的服务器改动
## （如管理端 /debug/term/advance、时钟调整）不一定推广播，轮询保证跟上。
func start_term_poll() -> void:
	if _term_poll_timer != null and _term_poll_timer.is_inside_tree():
		return
	_term_poll_timer = Timer.new()
	_term_poll_timer.wait_time = TERM_POLL_SECONDS
	_term_poll_timer.timeout.connect(_poll_term)
	add_child(_term_poll_timer)
	_term_poll_timer.start()


## 停止节气轮询（登出/token 失效时调用，避免空转 401）。
func _stop_term_poll() -> void:
	if _term_poll_timer != null:
		_term_poll_timer.stop()
		_term_poll_timer.queue_free()
		_term_poll_timer = null


func _poll_term() -> void:
	var res: Dictionary = await get_calendar()
	if res.get("code", -1) != 0:
		return
	var data: Dictionary = res["data"]
	# 节气变了才广播；没变也刷新 current_term（剩余秒数等）
	var changed := int(data.get("term_index", -1)) != int(current_term.get("term_index", -1))
	current_term = data
	if changed:
		term_changed.emit(current_term)


func start_ws() -> void:
	_stop_ws()
	if token == "":
		return  # 未登录不连 WS
	_socket = WebSocketPeer.new()
	var err := _socket.connect_to_url(ws_url + "?token=" + token.uri_encode())
	if err != OK:
		push_warning("节气 WebSocket 连接失败: %s" % err)
	# 心跳：每 30s 发 ping，刷新服务端在线判定
	_ws_ping_timer = Timer.new()
	_ws_ping_timer.wait_time = WS_PING_SECONDS
	_ws_ping_timer.timeout.connect(_send_ping)
	add_child(_ws_ping_timer)
	_ws_ping_timer.start()


func _send_ping() -> void:
	if _socket != null and _socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_socket.send_text("ping")


func _stop_ws() -> void:
	if _ws_ping_timer != null:
		_ws_ping_timer.stop()
		_ws_ping_timer.queue_free()
		_ws_ping_timer = null
	if _ws_timer != null:
		_ws_timer.stop()
		_ws_timer.queue_free()
		_ws_timer = null
	if _socket != null:
		_socket.close()
		_socket = null


func _reconnect_ws() -> void:
	_ws_timer = null
	start_ws()


func _handle_ws_message(message: String) -> void:
	var parsed = JSON.parse_string(message)
	if not (parsed is Dictionary):
		return
	var msg: Dictionary = parsed
	match str(msg.get("type", "")):
		"solar_term_change":
			current_term = msg.get("payload", {})
			term_changed.emit(current_term)
			check_art_updates()
		"resources_changed":
			# 资源权威变更：不依赖轮询，立即强制刷新 /player/me 并更新本地资源
			_refresh_resources()
		"pest_big":
			pest_big_event.emit(msg.get("payload", {}))
		"pest_small":
			pest_small_event.emit(msg.get("payload", {}))
		"pest_destroyed":
			pest_destroyed_event.emit(msg.get("payload", {}))
		"crop_withered":
			crop_withered_event.emit(msg.get("payload", {}))
		"weed_growth":
			weed_growth_event.emit(msg.get("payload", {}))
		"pong":
			pass  # 心跳回复，无需处理
		_:
			pass  # 未知事件类型一律忽略（向前兼容）


## 收到 resources_changed 推送：强制刷新 /player/me，更新本地玩家缓存并广播。
func _refresh_resources() -> void:
	var me := await get_player_me()
	if me.get("code", -1) != 0:
		return
	player = me["data"]
	save_local()
	resources_changed.emit(player)


func _auto_refresh_term() -> void:
	var res := await get_calendar()
	if res.get("code", -1) == 0:
		current_term = res["data"]
		term_changed.emit(current_term)


## ---------------- 本地持久化 ----------------

func save_local() -> void:
	_save_to_file({ "token": token, "player": player })


func load_local() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		var data: Dictionary = parsed
		token = str(data.get("token", ""))
		player = data.get("player", {})


## ---------------- 设置（user://settings.json） ----------------

func load_settings() -> void:
	settings = _load_json_file(SETTINGS_FILE)


func save_settings() -> void:
	_save_json_file(SETTINGS_FILE, settings)


## 保存新的服务器地址并立即生效（重建 api/ws_url，重连 WS）。
func set_server(address: String) -> void:
	address = address.strip_edges()
	if address == "":
		return
	if not address.begins_with("http://") and not address.begins_with("https://"):
		address = "http://" + address
	base_url = address.trim_suffix("/")
	api = base_url + "/v1"
	ws_url = base_url.replace("http", "ws") + "/v1/ws"
	settings["server"] = base_url
	save_settings()
	# 已在登录态：重连到新服务器的 WS
	if token != "":
		start_ws()


func set_music_enabled(on: bool) -> void:
	settings["music"] = on
	save_settings()
	music_enabled_changed.emit(on)


func set_sfx_enabled(on: bool) -> void:
	settings["sfx"] = on
	save_settings()


func is_music_enabled() -> bool:
	return bool(settings.get("music", true))


func is_sfx_enabled() -> bool:
	return bool(settings.get("sfx", true))


## 新手教学标记：注册成功时置位，教学完成后清除。
func is_tutorial_pending() -> bool:
	return bool(settings.get("tutorial_pending", false))


func mark_tutorial_pending() -> void:
	settings["tutorial_pending"] = true
	save_settings()


func clear_tutorial_pending() -> void:
	settings["tutorial_pending"] = false
	save_settings()


func _save_to_file(data: Dictionary) -> void:
	_save_json_file(SAVE_PATH, data)


func _load_json_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		return parsed
	return {}


func _save_json_file(path: String, data: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data))
		f.close()
