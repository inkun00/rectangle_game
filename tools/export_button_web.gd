extends SceneTree

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://build/web")
	for primary: bool in [false, true]:
		var filename: String = "button-primary.png" if primary else "button-secondary.png"
		var error: Error = ButtonArt.texture(primary).get_image().save_png("res://build/web/" + filename)
		if error != OK:
			push_error("Could not export generated loading button: " + filename)
			quit(1)
			return
	var panel: Image = StarfrontArt.panel(0).texture.get_image()
	if panel.save_png("res://build/web/loading-panel.png") != OK:
		push_error("Could not export the generated loading panel")
		quit(1)
		return
	# The browser-only image is excluded from the PCK and already encoded.
	var panorama: String = ProjectSettings.globalize_path("res://assets/generated/browser-arrival-v1/night-village.webp")
	var destination: String = ProjectSettings.globalize_path("res://build/web/frontier-loading.webp")
	if DirAccess.copy_absolute(panorama, destination) != OK:
		push_error("Could not copy the loading-screen illustration")
		quit(1)
		return
	quit()
