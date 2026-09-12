extends Node
signal changed
const VERSION := "0.7.6"
const API := "https://api.github.com/repos/linkq8/adam-summit/releases?per_page=20"
const RELEASES := "https://github.com/linkq8/adam-summit/releases"
const APK := "user://updates/adam-update.apk"
var status := "تحقق من إصدار جديد عبر GitHub"
var busy := false
var install_ready := false
var asset: Dictionary = {}
var request: HTTPRequest
var downloading := false
static func newer(tag: String) -> bool:
	var parts := tag.trim_prefix("v").split(".")
	var local := VERSION.split(".")
	if parts.size() != 3: return false
	for part in parts:
		if not part.is_valid_int(): return false
	for i in range(3):
		if int(parts[i]) != int(local[i]): return int(parts[i]) > int(local[i])
	return false
static func valid_asset(a: Dictionary) -> bool:
	return a.get("name", "") == "adam-summit-android.apk" and str(a.get("browser_download_url", "")).begins_with(RELEASES + "/download/") and str(a.get("digest", "")).begins_with("sha256:") and str(a.get("digest", "")).length() == 71 and int(a.get("size", 0)) > 0 and int(a.get("size", 0)) < 250000000
func _ready() -> void:
	request = HTTPRequest.new()
	request.use_threads = false
	request.timeout = 30
	add_child(request)
	request.request_completed.connect(completed)
func check_update() -> void:
	if busy: return
	asset.clear(); install_ready = false; downloading = false; busy = true
	status = "جارٍ التحقق…"; changed.emit()
	request.download_file = ""
	request.body_size_limit = 2000000
	if request.request(API, ["Accept: application/vnd.github+json", "User-Agent: AdamSummit/" + VERSION]) != OK: fail("تعذر الاتصال. أعد المحاولة.")
func download() -> void:
	if busy or not valid_asset(asset): return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://updates"))
	busy = true; downloading = true; install_ready = false
	status = "جارٍ تنزيل التحديث…"; changed.emit()
	request.download_file = APK
	request.body_size_limit = 250000000
	request.timeout = 300
	if request.request(asset.browser_download_url) != OK: fail("تعذر بدء التنزيل. أعد المحاولة.")
func fail(message: String) -> void:
	busy = false; install_ready = false
	status = message
	if downloading: DirAccess.remove_absolute(ProjectSettings.globalize_path(APK))
	downloading = false
	changed.emit()
func completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	busy = false
	print("UPDATE_HTTP result=%d status=%d" % [result, code])
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		fail("تعذر الاتصال بـ GitHub. تحقق من الإنترنت وأعد المحاولة."); return
	if downloading:
		downloading = false
		if FileAccess.get_sha256(APK) != str(asset.digest).trim_prefix("sha256:"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(APK))
			fail("لم ينجح التحقق من الملف. أعد التنزيل."); return
		install_ready = true; status = "التحديث جاهز. اختر تثبيت التحديث."
	else:
		var releases = JSON.parse_string(body.get_string_from_utf8())
		if not releases is Array: fail("استجابة غير صالحة. أعد المحاولة."); return
		for release in releases:
			if not release is Dictionary or release.get("draft", true) or not newer(str(release.get("tag_name", ""))): continue
			for item in release.get("assets", []):
				if item is Dictionary and valid_asset(item): asset = item; break
			if not asset.is_empty(): break
		status = "يوجد تحديث جديد جاهز للتنزيل" if not asset.is_empty() else "أنت تستخدم أحدث إصدار متاح"
	changed.emit()
func install() -> void:
	if not install_ready: return
	if OS.get_name() != "Android": OS.shell_open(RELEASES); return
	if not Engine.has_singleton("AndroidRuntime"): fail("التثبيت غير متاح على هذا الجهاز."); return
	var bridge = JavaClassWrapper.wrap("com.godot.game.AdamUpdates")
	var result = bridge.install(Engine.get_singleton("AndroidRuntime").getActivity(), ProjectSettings.globalize_path(APK))
	status = "اسمح بالتحديث من هذا التطبيق، ثم ارجع واضغط تثبيت مرة أخرى." if result == "permission" else ("أكمل التثبيت في نافذة Android" if result == "opened" else "تعذر فتح المثبّت على الجهاز.")
	changed.emit()
