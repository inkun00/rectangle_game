extends RefCounted

const ART_ROOT: String = "res://assets/generated/wall-commissions/"
const PAINTABLE: Dictionary = {
	"harbor": Rect2(0.16172, 0.19306, 0.67734, 0.62500),
	"garden": Rect2(0.14609, 0.20000, 0.70782, 0.60972),
	"station": Rect2(0.17109, 0.19861, 0.66797, 0.58750),
	"library": Rect2(0.17500, 0.25278, 0.65000, 0.52083),
	"bakery": Rect2(0.16641, 0.23056, 0.66484, 0.54305),
	"playground": Rect2(0.12578, 0.27778, 0.74609, 0.47500),
	"forest": Rect2(0.12969, 0.29861, 0.73515, 0.47639),
	"museum": Rect2(0.13750, 0.26389, 0.72891, 0.52500),
	"orchard": Rect2(0.12187, 0.29028, 0.75469, 0.48750),
	"observatory": Rect2(0.11016, 0.28750, 0.77968, 0.57917),
}

static func path_for(id: String) -> String:
	return ART_ROOT + id + ".webp"

# Source-image coordinates; the same rectangle is used in the studio and the export.
static func wall_rect(id: String) -> Rect2:
	return PAINTABLE.get(id, Rect2(0.18, 0.32, 0.64, 0.46))
