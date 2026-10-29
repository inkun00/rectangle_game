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
	quit()
