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
	# Encode the original once; the imported scene texture is already lossy.
	var loading_image: Image = Image.load_from_file("res://assets/generated/starfront-hd/backgrounds/observatory.png")
	if loading_image == null or loading_image.is_empty():
		push_error("Could not load the original loading background")
		quit(1)
		return
	var loading_error: Error = loading_image.save_webp("res://build/web/frontier-loading.webp", true, 0.95)
	if loading_error != OK:
		push_error("Could not export the WebP loading background")
		quit(1)
		return
	quit()
