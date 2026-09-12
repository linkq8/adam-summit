extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var http := HTTPRequest.new(); root.add_child(http); http.timeout = 30
	http.request("https://api.github.com/repos/linkq8/adam-summit/releases?per_page=5", ["User-Agent: AdamSummit-test"])
	var response = await http.request_completed
	if response[0] != 0 or response[1] != 200: printerr("Metadata request failed"); quit(1); return
	var releases = JSON.parse_string(response[3].get_string_from_utf8())
	var u = load("res://scripts/updater.gd").new(); root.add_child(u)
	for release in releases:
		for asset in release.get("assets", []):
			if u.valid_asset(asset): u.asset = asset; break
		if not u.asset.is_empty(): break
	if u.asset.is_empty(): printerr("No downloadable fixture"); quit(1); return
	u.download()
	while u.busy: await process_frame
	var passed: bool = u.install_ready
	print("UPDATE_DOWNLOAD_SHA256: ", "PASS" if passed else u.status)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(u.APK))
	u.queue_free(); http.queue_free(); await process_frame; await process_frame
	quit(0 if passed else 1)
