extends RefCounted
static func apply(root: Control) -> void:
	var theme := Theme.new()
	theme.default_font_size = 18
	for state in ["normal","hover","pressed","focus","disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color("142728") if state == "normal" else Color("24413c")
		if state == "disabled": box.bg_color = Color("142021")
		box.border_color = Color("7fa797") if state in ["hover","focus"] else Color("345049")
		box.set_border_width_all(2 if state == "focus" else 1)
		box.set_corner_radius_all(3)
		box.content_margin_left = 18
		box.content_margin_right = 18
		box.content_margin_top = 10
		box.content_margin_bottom = 10
		if state == "focus": box.bg_color = Color(0,0,0,0)
		theme.set_stylebox(state,"Button",box)
	theme.set_color("font_color","Button",Color("e2e9df"))
	theme.set_color("font_hover_color","Button",Color("c9f4d8"))
	theme.set_color("font_disabled_color","Button",Color("6c8078"))
	theme.set_color("font_color","Label",Color("dce5da"))
	root.theme = theme
