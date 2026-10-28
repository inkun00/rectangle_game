"""Generate original, code-native quadrilateral studies for the drawing studio.

These educational SVGs are not reproductions or raster-image substitutes. Their
explicit regions make the silhouettes usable as precise geometric drawing guides.
All colored references use the same vector regions as their gray underdrawings.
"""
from __future__ import annotations

from math import atan2, cos, hypot, pi, sin
from pathlib import Path
from xml.sax.saxutils import escape

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets/generated/drawing/masterpieces"
Point = tuple[float, float]
Region = tuple[list[Point], str]


class Study:
    def __init__(self, key: str, title: str, background: str):
        self.key, self.title, self.background = key, title, background
        self.regions: list[Region] = []

    def quad(self, points: list[Point], color: str):
        assert len(points) == 4
        self.regions.append((points, color))

    def rect(self, x: float, y: float, w: float, h: float, color: str):
        self.quad([(x, y), (x + w, y), (x + w, y + h), (x, y + h)], color)

    def diamond(self, x: float, y: float, rx: float, ry: float, color: str):
        self.quad([(x, y - ry), (x + rx, y), (x, y + ry), (x - rx, y)], color)

    def convex(self, points: list[Point], color: str):
        """Split a convex silhouette into four-sided cells with shared edges."""
        cx = sum(p[0] for p in points) / len(points)
        cy = sum(p[1] for p in points) / len(points)
        for i, point in enumerate(points):
            before, after = points[i - 1], points[(i + 1) % len(points)]
            self.quad([((before[0] + point[0]) / 2, (before[1] + point[1]) / 2),
                       point, ((after[0] + point[0]) / 2, (after[1] + point[1]) / 2),
                       (cx, cy)], color)

    def ribbon(self, points: list[Point], width: float, color: str):
        offsets: list[Point] = []
        for i, point in enumerate(points):
            prev, nxt = points[max(0, i - 1)], points[min(len(points) - 1, i + 1)]
            dx, dy = nxt[0] - prev[0], nxt[1] - prev[1]
            distance = hypot(dx, dy)
            offsets.append((-dy / distance * width / 2, dx / distance * width / 2))
        for i in range(len(points) - 1):
            p, q, a, b = points[i], points[i + 1], offsets[i], offsets[i + 1]
            self.quad([(p[0] + a[0], p[1] + a[1]), (q[0] + b[0], q[1] + b[1]),
                       (q[0] - b[0], q[1] - b[1]), (p[0] - a[0], p[1] - a[1])], color)

    def save(self):
        OUTPUT.mkdir(parents=True, exist_ok=True)
        for reference in (False, True):
            bg = self.background if reference else "#fffdf8"
            stroke = "#3b494e" if reference else "#9ba5a5"
            lines = [f'<svg xmlns="http://www.w3.org/2000/svg" width="960" height="600" viewBox="0 0 960 600">',
                     f'<title>{escape(self.title)} · original quadrilateral study</title>',
                     f'<rect width="960" height="600" fill="{bg}"/>',
                     f'<g stroke="{stroke}" stroke-width="2.1" stroke-linejoin="round">']
            for points, color in self.regions:
                serialized = " ".join(f"{x:.2f},{y:.2f}" for x, y in points)
                fill = color if reference else "#f9f8f3"
                lines.append(f'<polygon points="{serialized}" fill="{fill}"/>')
            lines.extend(['</g>', '</svg>'])
            suffix = "-reference" if reference else ""
            (OUTPUT / f"{self.key}{suffix}.svg").write_text("\n".join(lines) + "\n", encoding="utf-8")


def starry_night() -> Study:
    s = Study("starry_night", "별이 빛나는 밤", "#21395f")
    s.quad([(0, 400), (960, 340), (960, 490), (0, 490)], "#4c6884")
    s.quad([(0, 410), (960, 340), (960, 600), (0, 600)], "#263c4e")
    # Broad, faceted ribbons translate the moving sky into pieces students can fill.
    s.ribbon([(280, 190), (350, 140), (470, 130), (580, 170), (650, 220), (770, 230), (890, 190)], 24, "#6c9da8")
    s.ribbon([(350, 215), (435, 185), (505, 195), (550, 240), (520, 280), (450, 280), (420, 250)], 22, "#b9c9ab")
    for x, y, radius in [(100, 90, 19), (295, 80, 20), (575, 70, 17), (770, 105, 24), (900, 80, 28), (815, 315, 15), (340, 315, 13)]:
        s.diamond(x, y, radius * 1.25, radius * 1.25, "#edd58a")
        s.diamond(x, y, radius * .45, radius * .45, "#fff0b4")
    for x, y, w, h, shade in [(270, 445, 90, 100, "#6b7881"), (385, 415, 78, 125, "#596c7a"), (475, 455, 100, 90, "#7e827b"), (605, 425, 82, 120, "#667b8a"), (730, 465, 105, 80, "#596c7a")]:
        s.rect(x, y, w, h, shade)
        s.quad([(x - 7, y), (x + 20, y - 30), (x + w - 13, y - 30), (x + w + 7, y)], "#354c60")
        s.rect(x + w * .35, y + 32, 22, 30, "#e7c67a")
    s.quad([(560, 345), (575, 310), (589, 345), (590, 500)], "#b3b7ad")
    s.rect(551, 404, 47, 134, "#949e98")
    # The tall cypress remains one readable foreground silhouette.
    s.quad([(110, 580), (104, 300), (153, 115), (188, 580)], "#233c36")
    s.quad([(104, 580), (77, 390), (105, 245), (153, 580)], "#304b3f")
    s.quad([(154, 580), (155, 270), (185, 175), (211, 580)], "#1e332e")
    return s


def sunflowers() -> Study:
    s = Study("sunflowers", "해바라기", "#e9d6a0")
    s.rect(0, 473, 960, 127, "#cba45e")
    flowers = [(340, 190, 48), (455, 130, 52), (575, 180, 47), (280, 303, 42), (420, 270, 49), (570, 300, 43), (663, 247, 37)]
    for x, y, radius in flowers:
        s.quad([(x - 5, y), (x + 5, y), (490, 442), (478, 442)], "#6e8950")
        for i in range(8):
            a = i * pi / 4
            rx, ry = cos(a), sin(a)
            px, py = -sin(a), cos(a)
            s.quad([(x + rx * radius * .42, y + ry * radius * .42),
                    (x + rx * radius + px * 12, y + ry * radius + py * 12),
                    (x + rx * radius * 1.45, y + ry * radius * 1.45),
                    (x + rx * radius - px * 12, y + ry * radius - py * 12)], "#e7b340" if i % 2 else "#f1c850")
        s.diamond(x, y, radius * .56, radius * .56, "#89643b")
    s.quad([(384, 371), (572, 371), (555, 511), (401, 511)], "#d1a24c")
    s.quad([(384, 371), (572, 371), (572, 407), (384, 407)], "#dfc27c")
    s.quad([(401, 511), (555, 511), (541, 538), (415, 538)], "#b98b44")
    return s


def bedroom() -> Study:
    s = Study("bedroom", "아를의 침실", "#93aab9")
    s.quad([(0, 0), (280, 48), (280, 350), (0, 500)], "#94a4bd")
    s.quad([(280, 48), (960, 0), (960, 411), (280, 350)], "#a8b4c6")
    s.quad([(0, 500), (280, 350), (960, 411), (960, 600)], "#bb925e")
    s.rect(0, 570, 960, 30, "#d4a565")
    s.quad([(380, 79), (530, 69), (530, 244), (380, 254)], "#6b826b")
    for x in [390, 460]:
        for y in [91, 165]:
            s.quad([(x, y), (x + 56, y - 4), (x + 56, y + 61), (x, y + 65)], "#8daf94")
    s.quad([(371, 65), (385, 66), (385, 261), (371, 263)], "#766445")
    s.quad([(531, 57), (547, 56), (547, 251), (531, 253)], "#766445")
    # Bed perspective: all four-sided regions, with quilt and two pillows.
    s.quad([(586, 320), (849, 280), (936, 503), (604, 548)], "#c39a52")
    s.quad([(607, 328), (837, 298), (905, 465), (620, 503)], "#b66d53")
    s.quad([(616, 342), (718, 327), (736, 379), (630, 397)], "#e7d1a4")
    s.quad([(732, 325), (826, 314), (845, 363), (747, 378)], "#eee0b7")
    s.quad([(576, 276), (591, 274), (613, 570), (594, 573)], "#aa8042")
    s.quad([(839, 226), (856, 223), (945, 537), (927, 542)], "#9b743d")
    s.quad([(589, 272), (854, 223), (859, 263), (592, 309)], "#b99a55")
    s.quad([(604, 503), (934, 461), (940, 499), (608, 548)], "#bf9952")
    # A table at left and a yellow chair in the foreground.
    s.quad([(128, 327), (251, 307), (309, 341), (162, 371)], "#d2ad62")
    s.quad([(162, 371), (177, 368), (176, 469), (160, 473)], "#96773f")
    s.quad([(286, 345), (302, 342), (305, 443), (289, 448)], "#96773f")
    s.quad([(199, 290), (236, 285), (243, 309), (205, 315)], "#82a7a5")
    s.quad([(237, 429), (311, 415), (342, 445), (258, 465)], "#d9b64f")
    s.quad([(223, 354), (238, 352), (258, 465), (244, 469)], "#ba9540")
    s.quad([(297, 343), (311, 341), (326, 433), (312, 437)], "#ba9540")
    s.quad([(229, 370), (305, 355), (309, 379), (234, 394)], "#e1bf5d")
    s.quad([(258, 465), (272, 462), (275, 548), (260, 552)], "#967b3e")
    s.quad([(327, 447), (341, 444), (350, 519), (336, 525)], "#967b3e")
    for x, y, w, h in [(613, 86, 71, 71), (753, 93, 91, 75), (683, 214, 70, 45)]:
        s.rect(x, y, w, h, "#b09257")
        s.rect(x + 8, y + 8, w - 16, h - 16, "#c0c4a5")
    return s


def mona_lisa() -> Study:
    s = Study("mona_lisa", "모나리자", "#a4b0a4")
    s.quad([(0, 235), (260, 170), (510, 255), (0, 388)], "#7f9383")
    s.quad([(500, 250), (745, 173), (960, 205), (960, 381)], "#7e938e")
    s.quad([(0, 388), (480, 256), (960, 381), (960, 600)], "#938369")
    s.quad([(68, 294), (181, 251), (204, 270), (95, 319)], "#c9bea0")
    s.rect(0, 442, 960, 58, "#756e59")
    s.quad([(296, 600), (321, 379), (573, 360), (682, 600)], "#3e5147")
    s.quad([(303, 598), (329, 389), (403, 371), (425, 600)], "#64705a")
    s.quad([(522, 377), (570, 355), (640, 451), (674, 599)], "#4a5b49")
    s.convex([(359, 110), (438, 66), (518, 80), (564, 134), (574, 296), (532, 359), (361, 346), (332, 211)], "#484c3c")
    s.convex([(389, 129), (440, 105), (494, 125), (522, 169), (512, 244), (476, 283), (427, 272), (394, 225)], "#dbc49a")
    s.quad([(425, 268), (477, 279), (492, 335), (408, 332)], "#c4ab7e")
    s.quad([(392, 176), (425, 169), (431, 179), (397, 184)], "#756c53")
    s.quad([(462, 169), (493, 173), (490, 182), (461, 180)], "#756c53")
    s.quad([(443, 180), (454, 184), (461, 218), (442, 219)], "#bba079")
    s.quad([(425, 242), (472, 239), (469, 247), (438, 252)], "#a58b69")
    s.quad([(341, 419), (411, 435), (507, 482), (447, 503)], "#8d8b66")
    s.quad([(463, 459), (565, 440), (601, 486), (509, 499)], "#a8a080")
    s.quad([(396, 448), (454, 456), (524, 483), (473, 499)], "#d4bd94")
    s.quad([(480, 460), (542, 447), (566, 460), (518, 481)], "#e0cca6")
    return s


def pearl_earring() -> Study:
    s = Study("pearl_earring", "진주 귀걸이를 한 소녀", "#253c3f")
    s.quad([(289, 600), (331, 443), (525, 367), (714, 600)], "#ad9763")
    s.quad([(332, 444), (418, 414), (510, 539), (380, 600)], "#c3ad7c")
    s.quad([(525, 368), (607, 428), (712, 600), (570, 600)], "#8c7e52")
    s.quad([(425, 365), (493, 347), (525, 395), (474, 441)], "#dec9a3")
    s.convex([(369, 185), (445, 128), (526, 155), (570, 221), (555, 296), (512, 362), (446, 372), (393, 318)], "#e4cdaa")
    s.quad([(355, 160), (429, 94), (526, 120), (546, 171)], "#447c9a")
    s.quad([(355, 160), (421, 127), (430, 194), (371, 229)], "#73a4ba")
    s.quad([(429, 94), (526, 120), (581, 166), (510, 165)], "#c9ae66")
    s.quad([(522, 165), (581, 166), (644, 354), (584, 378)], "#d3bb79")
    s.quad([(584, 378), (644, 354), (626, 447), (598, 423)], "#b7a16c")
    s.quad([(381, 228), (415, 218), (420, 228), (388, 238)], "#645b47")
    s.quad([(468, 214), (500, 222), (494, 232), (466, 226)], "#645b47")
    s.quad([(438, 229), (449, 225), (474, 271), (446, 278)], "#c5a77e")
    s.quad([(420, 307), (446, 296), (468, 307), (440, 316)], "#b57f6d")
    s.diamond(519, 342, 18, 25, "#f6edd3")
    s.diamond(515, 334, 7, 8, "#fffaf0")
    return s


def great_wave() -> Study:
    s = Study("great_wave", "가나가와 해변의 높은 파도", "#e6dfca")
    s.rect(0, 443, 960, 157, "#426d8c")
    s.quad([(598, 445), (657, 352), (684, 352), (744, 445)], "#7790a1")
    s.quad([(636, 384), (657, 352), (684, 352), (705, 384)], "#f7f3df")
    s.ribbon([(0, 493), (107, 441), (171, 370), (188, 267), (245, 193), (333, 153), (420, 165), (491, 216), (516, 274)], 112, "#305f80")
    s.ribbon([(0, 487), (104, 433), (165, 364), (185, 267), (246, 188), (334, 148), (422, 162), (493, 213), (520, 274)], 29, "#faf5e5")
    for x, y, a in [(246, 153, -.7), (295, 127, -.4), (357, 119, 0), (410, 136, .3), (454, 165, .5), (496, 199, .7), (526, 239, 1.0)]:
        dx, dy, px, py = cos(a), sin(a), -sin(a), cos(a)
        s.quad([(x - dx * 9, y - dy * 9), (x + dx * 20 + px * 12, y + dy * 20 + py * 12),
                (x + dx * 42, y + dy * 42), (x + dx * 20 - px * 12, y + dy * 20 - py * 12)], "#faf5e5")
    s.ribbon([(0, 574), (144, 520), (267, 482), (385, 508), (502, 562), (650, 580), (805, 543), (960, 516)], 25, "#b4c2bc")
    s.ribbon([(0, 587), (150, 552), (300, 551), (454, 588), (650, 599), (805, 581), (960, 555)], 20, "#244d70")
    for x, y, width in [(200, 440, 235), (520, 480, 250), (640, 391, 238)]:
        s.quad([(x, y), (x + width, y - 30), (x + width - 22, y - 10), (x + 25, y + 15)], "#b99563")
        s.quad([(x + 28, y - 9), (x + width - 25, y - 34), (x + width - 22, y - 22), (x + 31, y + 2)], "#e4d2a7")
    return s


def water_lilies() -> Study:
    s = Study("water_lilies", "수련", "#7f9fa3")
    for x, y, w, h, color in [(65, 20, 90, 160, "#78998c"), (240, 0, 70, 215, "#91a991"), (512, 0, 76, 200, "#779487"), (788, 0, 102, 190, "#6c938d"), (109, 205, 157, 29, "#b5bfad"), (440, 140, 192, 33, "#a7b9ae"), (697, 260, 175, 25, "#b9c5b7"), (320, 490, 150, 30, "#a6b4b7")]:
        s.quad([(x, y), (x + w, y + 12), (x + w - 12, y + h), (x + 14, y + h - 5)], color)
    for i, (x, y, rx) in enumerate([(147, 326, 68), (366, 269, 62), (585, 346, 74), (800, 411, 69), (315, 471, 72), (99, 502, 55), (669, 533, 65), (844, 216, 49)]):
        s.diamond(x, y, rx, rx * .38, "#648c76" if i % 2 else "#769b80")
        s.diamond(x - 7, y - 10, rx * .42, rx * .37, "#e1d4d5")
        s.diamond(x - 17, y - 15, rx * .25, rx * .23, "#f1e7dc")
        s.diamond(x + 8, y - 16, rx * .25, rx * .21, "#e8d7df")
        s.diamond(x - 4, y - 22, rx * .15, rx * .20, "#f5eddf")
    return s


def red_blue_yellow() -> Study:
    s = Study("red_blue_yellow", "빨강, 파랑, 노랑의 구성", "#eee8d9")
    # An original wide geometric study of the characteristic asymmetric balance.
    s.rect(92, 48, 204, 220, "#f5efdf")
    s.rect(92, 268, 204, 177, "#f6f1e6")
    s.rect(296, 48, 571, 397, "#ca5343")
    s.rect(92, 445, 204, 107, "#3c7097")
    s.rect(296, 445, 449, 107, "#f5f1e6")
    s.rect(745, 445, 122, 59, "#eee9d9")
    s.rect(745, 504, 122, 48, "#e7bc43")
    # These bars are guide regions too, so students can build the full composition.
    s.rect(286, 48, 14, 504, "#283c40")
    s.rect(92, 437, 775, 14, "#283c40")
    s.rect(92, 261, 194, 14, "#283c40")
    s.rect(738, 451, 14, 101, "#283c40")
    s.rect(752, 498, 115, 12, "#283c40")
    return s


def the_scream() -> Study:
    s = Study("the_scream", "절규", "#d7a47f")
    s.ribbon([(0, 76), (180, 62), (362, 103), (540, 96), (740, 41), (960, 64)], 53, "#c76b56")
    s.ribbon([(0, 163), (180, 138), (365, 184), (570, 179), (780, 125), (960, 141)], 50, "#e2ba85")
    s.quad([(276, 269), (647, 187), (960, 259), (960, 478)], "#6d8b92")
    s.quad([(647, 187), (960, 208), (960, 259), (694, 237)], "#6d7768")
    s.quad([(0, 250), (276, 269), (960, 600), (0, 600)], "#ae8966")
    s.quad([(0, 287), (22, 262), (960, 552), (960, 585)], "#70675a")
    s.quad([(0, 356), (15, 331), (814, 600), (730, 600)], "#796a56")
    for x, y in [(137, 319), (311, 378), (655, 494)]:
        s.quad([(x, y), (x + 14, y + 4), (x + 12, y + 89), (x - 2, y + 85)], "#766a57")
    # The two distant figures and the foreground figure.
    for x, y in [(100, 246), (158, 259)]:
        s.diamond(x, y, 10, 16, "#404c4b")
        s.quad([(x - 12, y + 15), (x + 12, y + 15), (x + 17, y + 77), (x - 15, y + 76)], "#3f4f4d")
    s.quad([(408, 600), (426, 427), (526, 411), (584, 600)], "#3f514c")
    s.convex([(432, 307), (476, 279), (525, 303), (551, 349), (529, 404), (492, 438), (446, 409), (420, 357)], "#dcc7a7")
    s.diamond(454, 342, 11, 10, "#5e675b")
    s.diamond(509, 338, 11, 10, "#5e675b")
    s.diamond(483, 390, 17, 27, "#657063")
    s.quad([(406, 397), (424, 349), (441, 356), (429, 422)], "#cbb997")
    s.quad([(532, 350), (550, 345), (571, 397), (548, 420)], "#cbb997")
    return s


def apple_basket() -> Study:
    s = Study("apple_basket", "사과 바구니", "#9faba2")
    s.quad([(0, 348), (960, 303), (960, 600), (0, 600)], "#b49b77")
    s.quad([(108, 364), (474, 311), (765, 492), (442, 600)], "#e5dfc9")
    s.quad([(108, 364), (299, 372), (367, 600), (166, 600)], "#d3d4c4")
    s.quad([(474, 311), (553, 339), (643, 600), (509, 571)], "#f2ead6")
    s.quad([(148, 285), (370, 241), (354, 365), (180, 401)], "#aa8353")
    s.quad([(148, 285), (370, 241), (378, 269), (157, 314)], "#d0b47d")
    s.quad([(177, 318), (355, 282), (351, 309), (184, 346)], "#c39c62")
    s.quad([(186, 361), (352, 327), (347, 352), (195, 384)], "#bc935c")
    # A dark bottle, a small plate of bread, and faceted apples.
    s.quad([(520, 188), (573, 188), (591, 337), (501, 342)], "#416052")
    s.rect(530, 133, 33, 62, "#3d594e")
    s.rect(526, 127, 41, 17, "#667657")
    s.quad([(646, 383), (844, 366), (881, 407), (666, 435)], "#f2e4c2")
    for x, y in [(669, 365), (718, 357), (771, 352), (693, 394), (751, 386)]:
        s.quad([(x, y), (x + 39, y - 4), (x + 46, y + 19), (x + 8, y + 24)], "#d2ad69")
    for i, (x, y, radius) in enumerate([(177, 274, 30), (228, 256, 35), (287, 242, 32), (335, 254, 30), (230, 320, 35), (298, 305, 35), (361, 405, 34), (434, 437, 35), (512, 485, 34), (282, 482, 38), (191, 454, 31), (605, 454, 30)]):
        color = ["#bf7653", "#d6ad61", "#a5a363"][i % 3]
        s.diamond(x, y, radius, radius * .88, color)
        s.quad([(x, y - radius * .88), (x + radius * .6, y - radius * .35), (x + radius * .17, y), (x - radius * .35, y - radius * .3)], "#e0bd77")
    return s


if __name__ == "__main__":
    studies = [starry_night(), sunflowers(), bedroom(), mona_lisa(), pearl_earring(), great_wave(), water_lilies(), red_blue_yellow(), the_scream(), apple_basket()]
    for study in studies:
        for points, _color in study.regions:
            turns = [(points[(i + 1) % 4][0] - points[i][0]) * (points[(i + 2) % 4][1] - points[(i + 1) % 4][1])
                     - (points[(i + 1) % 4][1] - points[i][1]) * (points[(i + 2) % 4][0] - points[(i + 1) % 4][0]) for i in range(4)]
            assert all(t > .0001 for t in turns) or all(t < -.0001 for t in turns), (study.key, points)
        study.save()
        print(f"{study.key}: {len(study.regions)} quadrilateral regions")
