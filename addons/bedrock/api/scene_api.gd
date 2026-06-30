extends Node
## Scenes — async scene loading and a simple overlay stack (pause menus, dialogs).

signal scene_changed(path: String)

var _overlays: Array[Node] = []


func change_scene(path: String) -> void:
	if get_tree().change_scene_to_file(path) == OK:
		scene_changed.emit(path)


## Load on a background thread, then swap. Yields until the load resolves; show a
## loading screen as an overlay around the call if you want one.
func change_scene_async(path: String) -> void:
	ResourceLoader.load_threaded_request(path)
	while true:
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var packed: PackedScene = ResourceLoader.load_threaded_get(path)
			get_tree().change_scene_to_packed(packed)
			scene_changed.emit(path)
			return
		if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("[Scenes] failed to load %s" % path)
			return
		await get_tree().process_frame


func push_overlay(path: String) -> Node:
	return push_overlay_packed(load(path))


func push_overlay_packed(packed: PackedScene) -> Node:
	var inst := packed.instantiate()
	get_tree().root.add_child(inst)
	_overlays.append(inst)
	return inst


func pop_overlay() -> void:
	if _overlays.is_empty():
		return
	var top: Node = _overlays.pop_back()
	top.queue_free()


func overlay_depth() -> int:
	return _overlays.size()
