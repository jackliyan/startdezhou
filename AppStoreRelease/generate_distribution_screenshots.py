from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = ROOT / "DistributionScreenshots" / "zh-Hans"
WIDTH = 1320
HEIGHT = 2868

FONT_CANDIDATES = [
    "/System/Library/Fonts/STHeiti Medium.ttc",
    "/System/Library/Fonts/STHeiti Light.ttc",
    "/System/Library/Fonts/Supplemental/Arial Unicode.ttf",
    "/Library/Fonts/Arial Unicode.ttf",
]


def font(size, weight="regular"):
    path = FONT_CANDIDATES[0 if weight in {"bold", "medium"} else 1]
    return ImageFont.truetype(path, size=size)


FONTS = {
    "hero": font(64, "bold"),
    "title": font(48, "bold"),
    "subtitle": font(31),
    "body": font(28),
    "small": font(23),
    "tiny": font(19),
    "card_rank": font(26, "bold"),
    "metric": font(34, "bold"),
}

COLORS = {
    "bg_top": (7, 28, 48),
    "bg_bottom": (2, 10, 26),
    "panel": (9, 29, 47),
    "panel_2": (12, 42, 61),
    "panel_3": (6, 20, 34),
    "stroke": (50, 132, 160),
    "stroke_soft": (31, 91, 118),
    "cyan": (76, 218, 232),
    "blue": (38, 124, 255),
    "gold": (234, 185, 78),
    "white": (235, 248, 255),
    "muted": (128, 160, 176),
    "red": (255, 127, 82),
    "dark_text": (14, 28, 39),
}


def rounded(draw, box, radius, fill, outline=None, width=1):
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def text(draw, xy, value, fill, size_key="body", anchor=None):
    draw.text(xy, value, font=FONTS[size_key], fill=fill, anchor=anchor)


def text_size(draw, value, size_key):
    bbox = draw.textbbox((0, 0), value, font=FONTS[size_key])
    return bbox[2] - bbox[0], bbox[3] - bbox[1]


def gradient_background():
    img = Image.new("RGB", (WIDTH, HEIGHT), COLORS["bg_bottom"])
    px = img.load()
    for y in range(HEIGHT):
        t = y / (HEIGHT - 1)
        r = int(COLORS["bg_top"][0] * (1 - t) + COLORS["bg_bottom"][0] * t)
        g = int(COLORS["bg_top"][1] * (1 - t) + COLORS["bg_bottom"][1] * t)
        b = int(COLORS["bg_top"][2] * (1 - t) + COLORS["bg_bottom"][2] * t)
        for x in range(WIDTH):
            left_glow = max(0, 1 - x / 760) * max(0, 1 - abs(y - 620) / 950)
            px[x, y] = (
                min(255, int(r + 14 * left_glow)),
                min(255, int(g + 36 * left_glow)),
                min(255, int(b + 48 * left_glow)),
            )
    overlay = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    od = ImageDraw.Draw(overlay)
    od.polygon([(0, 0), (640, 0), (0, 1540)], fill=(24, 82, 105, 36))
    od.polygon([(WIDTH, 0), (915, 0), (WIDTH, 1040)], fill=(0, 0, 0, 28))
    return Image.alpha_composite(img.convert("RGBA"), overlay)


def add_header(draw, title, subtitle, eyebrow="弈筹机", include_badges=True):
    text(draw, (92, 118), eyebrow, COLORS["gold"], "small")
    text(draw, (92, 178), title, COLORS["white"], "hero")
    text(draw, (94, 288), subtitle, COLORS["cyan"], "subtitle")
    if include_badges:
        x = 94
        for label in ["本地计算", "无接口", "无第三方"]:
            w, h = text_size(draw, label, "small")
            box = (x, 378, x + w + 42, 428)
            rounded(draw, box, 19, (41, 35, 17), COLORS["gold"], 2)
            text(draw, (x + 21, 389), label, COLORS["gold"], "small")
            x = box[2] + 16


def add_shadow(base, box, radius=36, opacity=135, blur=42):
    shadow = Image.new("RGBA", base.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle(box, radius=radius, fill=(0, 0, 0, opacity))
    shadow = shadow.filter(ImageFilter.GaussianBlur(blur))
    base.alpha_composite(shadow)


def phone_frame(base, top=870):
    left = 178
    right = WIDTH - 178
    bottom = HEIGHT - 158
    add_shadow(base, (left, top, right, bottom), 52, 115, 42)
    draw = ImageDraw.Draw(base)
    rounded(draw, (left, top, right, bottom), 52, COLORS["panel_3"], COLORS["stroke"], 4)
    rounded(draw, (left + 38, top + 128, right - 38, bottom - 136), 28, COLORS["panel"], COLORS["stroke_soft"], 2)
    text(draw, (left + 62, top + 72), "弈筹机", COLORS["white"], "title")
    text(draw, (right - 62, top + 84), "复盘", COLORS["muted"], "body", anchor="ra")
    return (left, top, right, bottom)


def tab_bar(draw, frame, selected):
    left, top, right, bottom = frame
    bar = (left + 40, bottom - 112, right - 40, bottom - 38)
    rounded(draw, bar, 18, (3, 18, 32), COLORS["stroke_soft"], 1)
    mid = (bar[0] + bar[2]) // 2
    if selected == "hand":
        active = (bar[0] + 6, bar[1] + 6, mid - 4, bar[3] - 6)
    else:
        active = (mid + 4, bar[1] + 6, bar[2] - 6, bar[3] - 6)
    rounded(draw, active, 14, COLORS["cyan" if selected == "hand" else "blue"])
    text(draw, ((bar[0] + mid) // 2, bar[1] + 24), "牌局", COLORS["white"], "small", anchor="ma")
    text(draw, ((mid + bar[2]) // 2, bar[1] + 24), "复盘", COLORS["white"], "small", anchor="ma")


def card(draw, x, y, rank, suit, scale=1.0):
    w = int(60 * scale)
    h = int(78 * scale)
    rounded(draw, (x, y, x + w, y + h), int(8 * scale), (235, 249, 252))
    is_red = suit in {"♥", "♦"}
    fill = COLORS["red"] if is_red else (9, 30, 43)
    draw.text((x + w / 2, y + h * 0.28), rank, font=FONTS["card_rank"], fill=fill, anchor="mm")
    draw.text((x + w / 2, y + h * 0.66), suit, font=FONTS["small"], fill=fill, anchor="mm")


def board_cards(draw, x, y, cards, gap=14, scale=1.0):
    for i, (rank, suit) in enumerate(cards):
        card(draw, x + i * int(74 * scale + gap), y, rank, suit, scale)


def chip(draw, x, y, label, fill):
    draw.ellipse((x - 22, y - 22, x + 22, y + 22), fill=fill)
    text(draw, (x, y - 13), label, COLORS["white"], "tiny", anchor="ma")


def draw_overview():
    img = gradient_background()
    draw = ImageDraw.Draw(img)
    add_header(draw, "德州复盘，一屏记录", "手牌、公共牌、盲注、码量，最多 9 人同桌记录")
    frame = phone_frame(img, 900)
    left, top, right, bottom = frame
    card_area = (left + 72, top + 150, right - 72, top + 430)
    rounded(draw, card_area, 26, COLORS["panel_2"], COLORS["stroke_soft"], 2)
    text(draw, (card_area[0] + 32, card_area[1] + 34), "手牌库", COLORS["muted"], "body")
    for row, suit in enumerate(["♠", "♥", "♦"]):
        for col, rank in enumerate(["A", "K", "Q", "J", "10", "9"]):
            card(draw, card_area[0] + 34 + col * 80, card_area[1] + 82 + row * 70, rank, suit, 0.66)

    seats = (left + 72, top + 470, right - 72, top + 740)
    rounded(draw, seats, 26, COLORS["panel_2"], COLORS["stroke_soft"], 2)
    text(draw, (seats[0] + 32, seats[1] + 34), "最多 9 人 · 盲注 · 码量 · 手牌", COLORS["white"], "body")
    rows = [
        ("P1", "BTN", [("A", "♠"), ("A", "♥")], "200"),
        ("P2", "SB", [("K", "♥"), ("8", "♦")], "230"),
        ("P3", "BB", [("Q", "♣"), ("J", "♠")], "260"),
    ]
    for idx, (name, pos, cards, stack) in enumerate(rows):
        y = seats[1] + 90 + idx * 66
        text(draw, (seats[0] + 32, y), name, COLORS["gold"], "small")
        text(draw, (seats[0] + 132, y), pos, COLORS["muted"], "small")
        board_cards(draw, seats[0] + 250, y - 18, cards, 10, 0.58)
        text(draw, (seats[2] - 34, y), stack, COLORS["cyan"], "small", anchor="ra")
    tab_bar(draw, frame, "hand")
    img.save(OUTPUT_DIR / "01-overview.png")


def draw_table_review():
    img = gradient_background()
    draw = ImageDraw.Draw(img)
    add_header(draw, "长方形 9 人复盘桌", "桌面 1-9 编号，对应座位与行动顺序更清楚")
    frame = phone_frame(img, 900)
    left, top, right, bottom = frame
    table_outer = (left + 84, top + 220, right - 84, top + 720)
    table_inner = (left + 178, top + 345, right - 178, top + 610)
    rounded(draw, table_outer, 56, (7, 50, 62), COLORS["gold"], 4)
    rounded(draw, (table_outer[0] + 32, table_outer[1] + 32, table_outer[2] - 32, table_outer[3] - 32), 40, COLORS["panel_2"], COLORS["stroke_soft"], 2)
    rounded(draw, table_inner, 26, COLORS["panel_3"], COLORS["cyan"], 2)
    text(draw, ((table_inner[0] + table_inner[2]) / 2, table_inner[1] + 42), "底池 168 积分", COLORS["gold"], "body", anchor="ma")
    board_cards(draw, table_inner[0] + 44, table_inner[1] + 104, [("A", "♠"), ("K", "♥"), ("Q", "♣"), ("8", "♦"), ("3", "♠")], 12, 0.84)
    text(draw, ((table_inner[0] + table_inner[2]) / 2, table_inner[3] - 56), "胜率 64.8%   赢 58.2%", COLORS["cyan"], "body", anchor="ma")
    chip(draw, (table_outer[0] + table_outer[2]) // 2 - 170, table_outer[1] + 82, "5", COLORS["cyan"])
    chip(draw, (table_outer[0] + table_outer[2]) // 2, table_outer[1] + 66, "6", COLORS["gold"])
    chip(draw, (table_outer[0] + table_outer[2]) // 2 + 170, table_outer[1] + 92, "7", COLORS["gold"])
    chip(draw, table_outer[0] + 72, table_outer[1] + 190, "4", COLORS["gold"])
    chip(draw, table_outer[0] + 72, table_outer[3] - 190, "3", COLORS["cyan"])
    chip(draw, table_outer[2] - 72, table_outer[1] + 190, "8", COLORS["gold"])
    chip(draw, table_outer[2] - 72, table_outer[3] - 190, "9", COLORS["gold"])
    chip(draw, (table_outer[0] + table_outer[2]) // 2, table_outer[3] - 72, "1", COLORS["blue"])
    rounded(draw, (left + 90, top + 770, left + 365, top + 830), 22, (12, 47, 55), COLORS["cyan"], 3)
    text(draw, (left + 124, top + 784), "按座位顺序行动", COLORS["cyan"], "small")
    tab_bar(draw, frame, "review")
    img.save(OUTPUT_DIR / "02-table-review.png")


def draw_action_line():
    img = gradient_background()
    draw = ImageDraw.Draw(img)
    add_header(draw, "行动线直接复盘", "下注、跟注、加注、弃牌、全下按顺序记录")
    frame = phone_frame(img, 900)
    left, top, right, bottom = frame
    panel = (left + 72, top + 185, right - 72, top + 760)
    rounded(draw, panel, 26, COLORS["panel_2"], COLORS["stroke_soft"], 2)
    text(draw, (panel[0] + 36, panel[1] + 44), "行动线", COLORS["white"], "title")
    rows = [
        ("1", "我", "下注 12", COLORS["blue"]),
        ("2", "P2", "跟注 12", COLORS["cyan"]),
        ("3", "P3", "加注 36", COLORS["cyan"]),
        ("4", "我", "跟注 36", COLORS["blue"]),
        ("5", "P2", "弃牌", COLORS["gold"]),
    ]
    for idx, (num, actor, action, color) in enumerate(rows):
        y = panel[1] + 126 + idx * 86
        rounded(draw, (panel[0] + 36, y, panel[2] - 36, y + 66), 18, COLORS["panel_3"], COLORS["stroke_soft"], 2)
        chip(draw, panel[0] + 92, y + 33, num, color)
        text(draw, (panel[0] + 150, y + 18), actor, COLORS["white"], "body")
        text(draw, (panel[2] - 68, y + 18), action, COLORS["gold"], "body", anchor="ra")
    rounded(draw, (panel[0] + 36, panel[3] - 96, panel[2] - 36, panel[3] - 24), 18, COLORS["cyan"])
    text(draw, ((panel[0] + panel[2]) / 2, panel[3] - 76), "键盘确认 · 直接记录行动", COLORS["dark_text"], "body", anchor="ma")
    tab_bar(draw, frame, "review")
    img.save(OUTPUT_DIR / "03-action-line.png")


def draw_showdown():
    img = gradient_background()
    draw = ImageDraw.Draw(img)
    add_header(draw, "摊牌后看胜率", "全下或河牌跟注后自动开牌，结合公共牌计算结果")
    frame = phone_frame(img, 900)
    left, top, right, bottom = frame
    panel = (left + 72, top + 185, right - 72, top + 930)
    rounded(draw, panel, 26, COLORS["panel_2"], COLORS["stroke_soft"], 2)
    text(draw, (panel[0] + 36, panel[1] + 42), "公共牌", COLORS["muted"], "body")
    board_cards(draw, panel[0] + 36, panel[1] + 92, [("A", "♠"), ("K", "♥"), ("Q", "♣"), ("8", "♦"), ("3", "♠")], 14, 0.86)
    text(draw, (panel[0] + 36, panel[1] + 230), "摊牌结果", COLORS["white"], "title")

    result_rows = [
        ("我", [("A", "♠"), ("A", "♥")], "胜率 64.8%", COLORS["cyan"]),
        ("P2", [("K", "♥"), ("8", "♦")], "胜率 24.1%", COLORS["gold"]),
        ("P3", [("Q", "♣"), ("J", "♠")], "胜率 11.1%", COLORS["muted"]),
    ]
    for idx, (name, cards, stat, color) in enumerate(result_rows):
        y = panel[1] + 315 + idx * 112
        rounded(draw, (panel[0] + 36, y, panel[2] - 36, y + 84), 18, COLORS["panel_3"], color, 2)
        text(draw, (panel[0] + 64, y + 25), name, COLORS["white"], "body")
        board_cards(draw, panel[0] + 170, y + 12, cards, 12, 0.66)
        text(draw, (panel[2] - 64, y + 25), stat, color, "body", anchor="ra")

    rounded(draw, (panel[0] + 36, panel[3] - 92, panel[0] + 178, panel[3] - 34), 18, (45, 36, 14), COLORS["gold"], 2)
    text(draw, (panel[0] + 64, panel[3] - 78), "已开牌", COLORS["gold"], "small")
    rounded(draw, (panel[0] + 196, panel[3] - 92, panel[2] - 36, panel[3] - 34), 18, (7, 48, 58), COLORS["cyan"], 2)
    text(draw, (panel[0] + 230, panel[3] - 78), "全下/河牌跟注后自动翻牌", COLORS["cyan"], "small")
    tab_bar(draw, frame, "review")
    img.save(OUTPUT_DIR / "04-showdown-equity.png")


def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    draw_overview()
    draw_table_review()
    draw_action_line()
    draw_showdown()
    print(f"Generated screenshots in {OUTPUT_DIR}")


if __name__ == "__main__":
    main()
