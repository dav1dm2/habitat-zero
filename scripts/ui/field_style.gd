extends RefCounted

const PANEL := Color("142427")
const LINE := Color("385456")
const PAPER := Color("dfd0a8")
const TEXT := Color("e7eee4")
const MUTED := Color("9fb6af")
const SIGNAL := Color("90e3dc")
const WARM := Color("e3bd79")

static func plate(fill: Color, edge: Color, inset := 12, weight := 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(weight)
	style.set_corner_radius_all(3)
	style.content_margin_left = inset
	style.content_margin_right = inset
	style.content_margin_top = inset
	style.content_margin_bottom = inset
	return style

static func label(words: String, size: int, color: Color = TEXT) -> Label:
	var line := Label.new()
	line.text = words
	line.add_theme_font_size_override("font_size", size)
	line.add_theme_color_override("font_color", color)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return line
