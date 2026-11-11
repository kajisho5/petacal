#!/usr/bin/env python3
"""Mocks for the fictional calendar app 「ペタカレ（仮称）」. All names, places and events are fictional.
Colors are approximate values from hig-design-skill references/hig-specs.md (the app uses system colors).
Symbols are simple line stand-ins for SF Symbols. Run: python3 design/build.py
"""
from pathlib import Path
from xml.sax.saxutils import escape

OUT = Path(__file__).resolve().parent / "mocks"
OUT.mkdir(exist_ok=True)
FONT = "-apple-system, 'SF Pro Text', 'Hiragino Sans', 'Noto Sans JP', 'Noto Sans CJK JP', sans-serif"

THEMES = {
    "light": dict(bg="#F2F2F7", cell="#FFFFFF", label="#000000", sec="#3C3C43", sec_op=0.8,
                  sep="#C6C6C8", accent="#0088FF", accent_text="#0066CC", glass="#FFFFFF", glass_op=0.82,
                  glass_stroke="#D1D1D6", side="#F2F2F7", desk="#C9D3DF", win="#FFFFFF", bar="#F6F6F6",
                  sheet="#FFFFFF", field="#F2F2F7", kb="#D1D3D9", red="#D70015",
                  plus="#18702F", minus="#C4001A", ph=["#B9D4F2", "#F2D3B9", "#CDE8C4", "#E3C9EE"], warn="#8A5200",
                  cal={"仕事": "#0088FF", "プライベート": "#34C759", "家族": "#FF9500"}),
    "dark": dict(bg="#000000", cell="#1C1C1E", label="#FFFFFF", sec="#EBEBF5", sec_op=0.6,
                 sep="#38383A", accent="#0091FF", accent_text="#5CB8FF", glass="#2C2C2E", glass_op=0.82,
                 glass_stroke="#48484A", side="#1C1C1E", desk="#1F2633", win="#1E1E1E", bar="#2A2A2A",
                 sheet="#1C1C1E", field="#2C2C2E", kb="#2C2C2E", red="#FF6961",
                 plus="#30D158", minus="#FF6961", ph=["#274A70", "#6B4A2E", "#2F5A36", "#55386A"], warn="#FFB340",
                 cal={"仕事": "#0091FF", "プライベート": "#30D158", "家族": "#FF9F0A"}),
}

# Fictional sample data. November 2026 starts on a Sunday and has 30 days.
TODAY = 11
EVENTS = [("10:00", "11:00", "週次ミーティング", "仕事", "オンライン"),
          ("13:30", "14:30", "そらまめ商店 打ち合わせ", "仕事", "みどり台ビル 3階"),
          ("rec", "", "FX（午前の取引）", "収支・FX", 5400)]
# Records (fictional): day -> (title, kind, amount, has_photo)
RECORDS = {3: ("ソラマメーズ 新譜を購入", "推し活", -3300, True), 7: ("競馬（第5レース）", "収支・競馬", 3200, True),
           8: ("競艇（午後）", "収支・競艇", -2000, False), 11: ("FX（午前の取引）", "収支・FX", 5400, False),
           14: ("ライブ「まめまき2026」チケット", "推し活", -8800, True)}
WD = {3: "火", 7: "土", 8: "日", 11: "水", 14: "土"}


def yen(n, unit=True):
    return ("+" if n > 0 else "−") + f"{abs(n):,}" + ("円" if unit else "")
MONTH = {5: [("請求書しめ切り", "仕事")], 9: [("企画レビュー", "仕事")],
         11: [("週次ミーティング", "仕事"), ("そらまめ商店", "仕事")],
         14: [("家族で買い出し", "家族")], 18: [("打ち合わせ", "仕事")], 20: [("資料提出", "仕事")],
         25: [("懇親会", "プライベート")], 28: [("大掃除", "家族")]}
QUOTA = "AI取り込み 残り 3 回（無料版は月 5 回）"
PASTED = ["来週の打ち合わせ、18日(水)15時からで", "お願いします。場所は会議室Bです。", "25日の懇親会は19時スタートです！"]
FOUND = [("打ち合わせ", "11月18日（水） 15:00〜16:00", "会議室B", "仕事"),
         ("懇親会", "11月25日（水） 19:00〜21:00", "場所の記載なし", "プライベート")]
SLOTS = ["11/17（火） 10:00〜11:00", "11/18（水） 13:00〜14:00", "11/20（金） 16:00〜17:00"]


def T(x, y, s, size, fill, weight=400, anchor="start", op=None, bg=None, extra=""):
    o = f' opacity="{op}"' if op is not None else ""
    b = f' data-bg="{bg}"' if bg else ""
    return (f'<text x="{x:g}" y="{y:g}" font-family="{FONT}" font-size="{size}" font-weight="{weight}" '
            f'fill="{fill}" text-anchor="{anchor}"{o}{b}{extra}>{escape(s)}</text>')


def S(t, x, y, s, size, anchor="start", bg=None, extra=""):
    """Secondary text."""
    return T(x, y, s, size, t["sec"], 400, anchor, op=t["sec_op"], bg=bg, extra=extra)


def mix(fg, bg, a):
    f = [int(fg[i:i + 2], 16) for i in (1, 3, 5)]
    g = [int(bg[i:i + 2], 16) for i in (1, 3, 5)]
    return "#" + "".join(f"{round(x * a + y * (1 - a)):02X}" for x, y in zip(f, g))


def svg(w, h, bg, body):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}" '
            f'data-bg="{bg}"><rect width="100%" height="100%" fill="{bg}"/>{body}</svg>\n')


def R(x, y, w, h, rx, fill, extra=""):
    return f'<rect x="{x:g}" y="{y:g}" width="{w:g}" height="{h:g}" rx="{rx}" fill="{fill}"{extra}/>'


# ---------- symbols (line stand-ins for SF Symbols) ----------
def ico(kind, cx, cy, c, sw=2.0, s=1.0):
    g = (f'<g transform="translate({cx:g},{cy:g}) scale({s})" fill="none" stroke="{c}" stroke-width="{sw}" '
         f'stroke-linecap="round" stroke-linejoin="round">')
    p = {
        "plus": '<path d="M-8 0h16M0 -8v16"/>',
        "xmark": '<path d="M-7 -7l14 14M7 -7l-14 14"/>',
        "check": '<path d="M-8 1l5 6l11 -13"/>',
        "back": '<path d="M4 -10l-10 10 10 10"/>',
        "search": '<circle cx="-2" cy="-2" r="7"/><path d="M3 3l5 5"/>',
        "sidebar": '<rect x="-11" y="-10" width="22" height="20" rx="3"/><path d="M-3 -10v20"/>',
        "cal": '<rect x="-10" y="-9" width="20" height="18" rx="3"/><path d="M-10 -3h20M-5 -12v5M5 -12v5"/>',
        # calendar.badge.clock: propose dates
        "slots": '<rect x="-11" y="-9" width="18" height="17" rx="3"/><path d="M-11 -3h18M-6 -12v5M2 -12v5"/>'
                 '<circle cx="7" cy="7" r="5.5"/><path d="M7 4.5v3l2 1"/>',
        # tray.and.arrow.down: capture inbox
        "tray": '<path d="M-10 2l3-9h14l3 9v6h-20zM-10 2h6l1 3h6l1-3h6M0 -12v7M-3 -8l3 3 3-3"/>',
        "gear": '<circle r="4"/><circle r="9" stroke-dasharray="4 3"/>',
        "paste": '<rect x="-8" y="-9" width="16" height="19" rx="3"/><rect x="-4" y="-12" width="8" height="5" rx="2"/>',
        "camera": '<rect x="-11" y="-7" width="22" height="16" rx="4"/><circle cy="1" r="4.5"/><path d="M-4 -7l2-3h4l2 3"/>',
        "mic": '<rect x="-4" y="-11" width="8" height="14" rx="4"/><path d="M-8 0a8 8 0 0 0 16 0M0 8v4"/>',
        "copy": '<rect x="-9" y="-10" width="13" height="15" rx="3"/><path d="M-4 9h10a3 3 0 0 0 3-3v-11"/>',
        "share": '<path d="M-8 -1v9h16v-9M0 4v-15M-4 -7l4-4 4 4"/>',
        "note": '<rect x="-9" y="-10" width="18" height="20" rx="3"/><path d="M-5 -4h10M-5 0h10M-5 4h6"/>',
        "chart": '<path d="M-9 9v-7M-3 9v-15M3 9v-10M9 9v-18"/>',
        "lock": '<rect x="-8" y="-2" width="16" height="12" rx="3"/><path d="M-5 -2v-4a5 5 0 0 1 10 0v4"/>',
        "photo": '<rect x="-11" y="-9" width="22" height="18" rx="3"/><path d="M-11 5l6-6 5 5 3-3 8 7"/><circle cx="5" cy="-4" r="1.6"/>',
        "warn": '<path d="M0 -10l10 18h-20zM0 -3v6M0 6v.5"/>',
        "chev": '<path d="M-3 -6l6 6-6 6"/>',
        "spark": '<path d="M-3 -10l2.5 7.5 7.5 2.5-7.5 2.5-2.5 7.5-2.5-7.5-7.5-2.5 7.5-2.5zM8 -10v5M5.5 -7.5h5"/>',
    }[kind]
    return g + p + "</g>"


def ico_fill(kind, cx, cy, c, cut):
    """Filled stand-ins for tab bar symbols (.fill variants)."""
    if kind == "cal":
        return R(cx - 10, cy - 9, 20, 18, 3, c) + R(cx - 10, cy - 4, 20, 1.5, 0, cut)
    if kind == "tray":
        return (f'<path d="M{cx-10} {cy+2}l3-9h14l3 9v7h-20z" fill="{c}"/>'
                f'<path d="M{cx-10} {cy+2}h6l1 3h6l1-3h6" fill="none" stroke="{cut}" stroke-width="1.5"/>')
    if kind == "note":
        return (R(cx - 9, cy - 10, 18, 20, 3, c) + R(cx - 5, cy - 5, 10, 1.5, 0, cut) + R(cx - 5, cy - 1, 10, 1.5, 0, cut)
                + R(cx - 5, cy + 3, 6, 1.5, 0, cut))
    if kind == "chart":
        return R(cx - 10, cy + 1, 5, 9, 1.5, c) + R(cx - 2.5, cy - 6, 5, 16, 1.5, c) + R(cx + 5, cy - 10, 5, 20, 1.5, c)
    return f'<circle cx="{cx}" cy="{cy}" r="9" fill="{c}"/><circle cx="{cx}" cy="{cy}" r="3.5" fill="{cut}"/>'


def gbtn(t, cx, cy, kind, col=None, fill=None, label=""):
    """Round Liquid Glass bar button, 44pt."""
    f = fill or t["glass"]
    op = 1 if fill else t["glass_op"]
    st = "" if fill else f' stroke="{t["glass_stroke"]}"'
    return (f'<g aria-label="{label}"><circle cx="{cx:g}" cy="{cy:g}" r="22" fill="{f}" fill-opacity="{op}"{st}/>'
            + ico(kind, cx, cy, col or t["label"], 2.2) + "</g>")


def status_bar(w, t):
    return (T(54, 37, "9:41", 17, t["label"], 600, "middle")
            + f'<rect x="{w-62}" y="25" width="26" height="13" rx="4" fill="none" stroke="{t["label"]}" '
              f'stroke-opacity="0.4"/>' + R(w - 60, 27, 20, 9, 2, t["label"]))


def home_ind(w, h, t):
    return R(w / 2 - 70, h - 13, 140, 5, 2.5, t["label"])


TABS = [("cal", "カレンダー"), ("note", "記録"), ("chart", "集計"), ("gear", "設定")]


def tab_bar(w, h, t, active=0):
    bh = 62
    bw = w - 2 * 21 - bh - 10
    x, y = 21, h - 34 - bh
    p = [R(x, y, bw, bh, 31, t["glass"], f' fill-opacity="{t["glass_op"]}" stroke="{t["glass_stroke"]}"')]
    for i, (sym, lab) in enumerate(TABS):
        cx = x + bw * (i + 0.5) / 4
        on = i == active
        col = t["accent_text"] if on else t["label"]
        tabbg = mix(t["accent"], t["glass"], 0.12) if on else t["glass"]
        if on:
            p.append(R(cx - 34, y + 5, 68, bh - 10, 26, tabbg))
        p.append(ico_fill(sym, cx, y + 22, col, tabbg))
        p.append(T(cx, y + 50, lab, 11, col, 600, "middle", bg=tabbg))
    cx = w - 21 - bh / 2
    p.append(f'<circle cx="{cx}" cy="{y+bh/2}" r="{bh/2}" fill="{t["glass"]}" fill-opacity="{t["glass_op"]}" '
             f'stroke="{t["glass_stroke"]}"/>' + ico("search", cx, y + bh / 2, t["label"]))
    return "".join(p) + home_ind(w, h, t)


def side_column(w, h, t, y0=0, camera=True):
    """iPhone Duo: bars move to the trailing edge (approximation; Apple has not published positions)."""
    cx = w - 26
    p = []
    if camera:
        p.append(f'<circle cx="{cx}" cy="34" r="16" fill="#000"/>')
        p.append(T(cx, 78, "9:41", 13, t["label"], 600, "middle"))
        by = 112
    else:
        p.append(T(cx, 34, "9:41", 13, t["label"], 600, "middle"))
        by = 80
    p.append(gbtn(t, cx, by, "plus", "#FFFFFF", fill=t["accent"], label="予定を追加"))
    p.append(gbtn(t, cx, by + 54, "slots", label="候補日をつくる"))
    th = 4 * 56 + 12
    ty = h - 24 - 54 - th
    p.append(f'<circle cx="{cx}" cy="{h-46}" r="22" fill="{t["glass"]}" fill-opacity="{t["glass_op"]}" '
             f'stroke="{t["glass_stroke"]}"/>' + ico("search", cx, h - 46, t["label"]))
    p.append(R(cx - 24, ty, 48, th, 24, t["glass"], f' fill-opacity="{t["glass_op"]}" stroke="{t["glass_stroke"]}"'))
    for k, (sym, _) in enumerate(TABS):
        cy = ty + 6 + 56 * k + 28
        on = k == 0
        tb = mix(t["accent"], t["glass"], 0.12) if on else t["glass"]
        if on:
            p.append(R(cx - 20, cy - 24, 40, 48, 20, tb))
        p.append(ico_fill(sym, cx, cy, t["accent_text"] if on else t["label"], tb))
    return "".join(p)


# ---------- calendar parts ----------
def thumb(t, x, y, sz, k=0, r=8):
    """Photo placeholder (no real image): tinted tile with a simple landscape line."""
    c = t["ph"][k % 4]
    return (R(x, y, sz, sz, r, c) + f'<path d="M{x+sz*.12:g} {y+sz*.78:g}l{sz*.26:g} {-sz*.3:g} {sz*.2:g} {sz*.2:g} '
            f'{sz*.14:g} {-sz*.12:g} {sz*.18:g} {sz*.22:g}" fill="none" stroke="{t["label"]}" stroke-opacity="0.45" '
            f'stroke-width="1.6" stroke-linejoin="round"/><circle cx="{x+sz*.72:g}" cy="{y+sz*.3:g}" r="{sz*.07:g}" '
            f'fill="{t["label"]}" fill-opacity="0.45"/>')


def amt(t, x, y, n, size, anchor="end", bg=None, weight=600, unit=True):
    return T(x, y, yen(n, unit), size, t["plus"] if n > 0 else t["minus"], weight, anchor, bg=bg)


def month_dots(t, x, y, cw, rh, bg, num=17, events=True, fold_ok=False, amounts=True):
    """Compact month grid. Circle dots = 予定, small square = 記録, and the day's amount as text (with a sign)."""
    fo = ' data-fold-ok="1"' if fold_ok else ""
    p = [f"<g{fo}>"]
    for i, d in enumerate("日月火水木金土"):
        p.append(S(t, x + cw * (i + .5), y - 10, d, 13, "middle", bg=bg))
    for d in range(1, 31):
        col, row = (d - 1) % 7, (d - 1) // 7
        cx, cy = x + cw * (col + .5), y + rh * row + 20
        r = 16
        if d == TODAY:
            p.append(f'<circle cx="{cx:g}" cy="{cy:g}" r="{r:g}" fill="{t["accent"]}"/>')
            p.append(T(cx, cy + num * .36, str(d), num, "#FFFFFF", 600, "middle", bg=t["accent"]))
        else:
            p.append(T(cx, cy + num * .36, str(d), num, t["label"], 400, "middle", bg=bg))
        if not events:
            continue
        marks = [("c", t["cal"][c]) for _, c in MONTH.get(d, [])][:2]
        if d in RECORDS:
            marks.append(("s", t["sec"]))
        for k, (kind, col_) in enumerate(marks):
            mx = cx + (k - (len(marks) - 1) / 2) * 8
            if kind == "c":
                p.append(f'<circle cx="{mx:g}" cy="{cy + r + 6:g}" r="2.5" fill="{col_}"/>')
            else:
                p.append(R(mx - 2.5, cy + r + 3.5, 5, 5, 1, col_))
        if amounts and d in RECORDS and rh >= 56:
            p.append(amt(t, cx, cy + r + 21, RECORDS[d][2], 11, "middle", bg=bg, unit=False))
    p.append("</g>")
    return "".join(p)


def month_chips(t, x, y, cw, rh, bg, num=15, cs=12, maxn=2, chars=6):
    """Large month grid with event chips (iPad / Mac)."""
    p = []
    for i, d in enumerate("日月火水木金土"):
        p.append(S(t, x + cw * i + 10, y - 10, d, max(cs, 11), bg=bg))
    for r in range(6):
        p.append(R(x, y + rh * r, cw * 7, 0.5, 0, t["sep"]))
    for c in range(1, 7):
        p.append(R(x + cw * c, y, 0.5, rh * 5, 0, t["sep"]))
    ch = cs + 8
    for d in range(1, 31):
        col, row = (d - 1) % 7, (d - 1) // 7
        cx, cy = x + cw * col, y + rh * row
        if d == TODAY:
            p.append(f'<circle cx="{cx+18:g}" cy="{cy+18:g}" r="12" fill="{t["accent"]}"/>')
            p.append(T(cx + 18, cy + 18 + num * .36, str(d), num, "#FFFFFF", 700, "middle", bg=t["accent"]))
        else:
            p.append(T(cx + 18, cy + 18 + num * .36, str(d), num, t["label"], 400, "middle", bg=bg))
        ev = list(MONTH.get(d, []))
        if d in RECORDS:
            ev.append((yen(RECORDS[d][2], False), None))
        for k, (title, c) in enumerate(ev[:maxn]):
            if c is None:  # record chip: square marker + signed amount
                yy = cy + 36 + k * (ch + 3)
                cb = mix(t["sec"], bg, 0.10)
                p.append(R(cx + 4, yy, cw - 8, ch, 5, cb))
                p.append(R(cx + 9, yy + ch / 2 - 3, 6, 6, 1.5, t["sec"]))
                p.append(amt(t, cx + 20, yy + ch - 5.5, RECORDS[d][2], cs, "start", bg=cb, unit=False))
                continue
            cb = mix(t["cal"][c], bg, 0.22)
            yy = cy + 36 + k * (ch + 3)
            p.append(R(cx + 4, yy, cw - 8, ch, 5, cb))
            p.append(R(cx + 4, yy, 3, ch, 1.5, t["cal"][c]))
            s = title if len(title) <= chars else title[:chars - 1] + "…"
            p.append(T(cx + 12, yy + ch - 5.5, s, cs, t["label"], 400, bg=cb))
        if len(ev) > maxn:
            p.append(S(t, cx + 8, cy + 36 + maxn * (ch + 3) + cs, f"ほか{len(ev)-maxn}件", max(cs - 1, 11) if cs > 11 else cs, bg=bg))
    return "".join(p)


def agenda(t, x, y, w, bg, events=EVENTS, rowh=68, chars=14, fold_ok=False):
    fo = ' data-fold-ok="1"' if fold_ok else ""
    p = [f"<g{fo}>", R(x, y, w, len(events) * rowh, 24, bg)]
    for i, (st, en, title, cal, place) in enumerate(events):
        cy = y + i * rowh
        if st == "rec":  # record row: square marker, title, kind, signed amount
            p.append(R(x + 18, cy + rowh / 2 - 20, 40, 40, 10, mix(t["sec"], bg, 0.12)))
            p.append(ico("note", x + 38, cy + rowh / 2, t["label"], 1.6, .8))
            p.append(R(x + 72, cy + 14, 4, rowh - 28, 1, t["sec"]))
            s2 = title if len(title) <= chars - 5 else title[:chars - 6] + "…"
            p.append(T(x + 88, cy + 30, s2, 17, t["label"], 400, bg=bg))
            p.append(S(t, x + 88, cy + 50, cal, 13, bg=bg))
            p.append(amt(t, x + w - 18, cy + 38, place, 17, bg=bg))
            continue
        p.append(T(x + 18, cy + 30, st, 15, t["label"], 600, bg=bg))
        p.append(S(t, x + 18, cy + 50, en, 13, bg=bg))
        p.append(R(x + 72, cy + 14, 4, rowh - 28, 2, t["cal"][cal]))
        s = title if len(title) <= chars else title[:chars - 1] + "…"
        p.append(T(x + 88, cy + 30, s, 17, t["label"], 400, bg=bg))
        p.append(S(t, x + 88, cy + 50, f"{cal}・{place}", 13, bg=bg))
        if i < len(events) - 1:
            p.append(R(x + 88, cy + rowh - .5, w - 104, .5, 0, t["sep"]))
    p.append("</g>")
    return "".join(p)


# ---------- iPhone ----------
def iphone_top(t, w, title="2026年11月", sub="今月の収支 +6,600円・推し活 12,100円"):
    b = [status_bar(w, t)]
    b.append(R(16, 62, 68, 44, 22, t["glass"], f' fill-opacity="{t["glass_op"]}" stroke="{t["glass_stroke"]}"'))
    b.append(T(50, 90, "今日", 17, t["label"], 400, "middle", bg=t["glass"]))
    b.append(gbtn(t, w - 92, 84, "slots", label="候補日をつくる"))
    b.append(gbtn(t, w - 38, 84, "plus", "#FFFFFF", fill=t["accent"], label="追加"))
    b.append(T(20, 150, title, 34, t["label"], 700))
    if sub:
        b.append(S(t, 20, 178, sub, 15))
    return b


def iphone_main(theme, empty=False):
    t = THEMES[theme]
    w, h = 402, 874
    b = iphone_top(t, w)
    b.append(month_dots(t, 16, 220, (w - 32) / 7, 58, t["bg"], events=not empty))
    b.append(T(20, 540, "11月11日（水）・今日", 20, t["label"], 600))
    if empty:
        b.append(R(16, 554, w - 32, 204, 24, t["cell"]))
        b.append(ico("cal", w / 2, 590, t["sec"], 2, 1.3))
        b.append(T(w / 2, 632, "この日はまだ何もありません", 20, t["label"], 600, "middle", bg=t["cell"]))
        b.append(S(t, w / 2, 656, "予定を取り込むか、今日の記録を残せます。", 15, "middle", bg=t["cell"]))
        b.append(R(w / 2 - 100, 680, 200, 50, 25, t["accent"]))
        b.append(T(w / 2, 712, "記録を追加", 17, "#FFFFFF", 600, "middle", bg=t["accent"]))
    else:
        b.append(agenda(t, 16, 554, w - 32, t["cell"]))
    b.append(tab_bar(w, h, t))
    return svg(w, h, t["bg"], "".join(b))


def iphone_ax5(theme):
    """Largest text size (AX5): the month grid folds to a week strip and the list leads. Bars keep their size."""
    t = THEMES[theme]
    w, h = 402, 874
    b = iphone_top(t, w, title="", sub="")
    b.append(T(20, 176, "11月", 60, t["label"], 700))
    # week strip: only the dates (numbers stay readable, the names move to VoiceOver labels)
    for i, d in enumerate(range(8, 15)):
        cx = 16 + (w - 32) / 7 * (i + .5)
        if d == TODAY:
            b.append(f'<circle cx="{cx:g}" cy="222" r="24" fill="{t["accent"]}"/>')
            b.append(T(cx, 232, str(d), 28, "#FFFFFF", 700, "middle", bg=t["accent"]))
        else:
            b.append(T(cx, 232, str(d), 28, t["label"], 400, "middle"))
    b.append(R(16, 262, w - 32, 496, 26, t["cell"]))
    y = 322
    for text, size, kind in [("10:00", 49, "sec"), ("週次ミー", 53, "label"), ("ティング", 53, "label"),
                             ("仕事", 49, "sec"), ("13:30", 49, "sec"), ("そらまめ", 53, "label"), ("商店 打…", 53, "label")]:
        if kind == "sec":
            b.append(S(t, 36, y, text, size, bg=t["cell"]))
        else:
            b.append(T(36, y, text, size, t["label"], 400, bg=t["cell"]))
        y += 68
    b.append(tab_bar(w, h, t))
    return svg(w, h, t["bg"], "".join(b))


def sheet_base(t, theme, w, h, title, lead="xmark", done=True):
    sy = 56
    b = [status_bar(w, t), R(0, 0, w, h, 0, "#000000", f' fill-opacity="{0.25 if theme == "light" else 0.5}"'),
         f'<path d="M0 {sy+38}a38 38 0 0 1 38 -38h{w-76}a38 38 0 0 1 38 38v{h-sy-38}h-{w}z" fill="{t["sheet"]}"/>']
    b.append(gbtn(t, 46, sy + 48, lead, fill=t["field"], label="キャンセル" if lead == "xmark" else "戻る"))
    b.append(T(w / 2, sy + 54, title, 17, t["label"], 600, "middle", bg=t["sheet"]))
    if done is not None:
        if done:
            b.append(gbtn(t, w - 46, sy + 48, "check", "#FFFFFF", fill=t["accent"], label="追加"))
        else:  # disabled
            b.append(f'<g aria-label="追加（無効）" opacity="0.4">' + gbtn(t, w - 46, sy + 48, "check", fill=t["field"]) + "</g>")
    return b, sy


def pasted_box(t, w, y, dim=False):
    b = [R(24, y, w - 48, 112, 16, t["field"])]
    for i, line in enumerate(PASTED):
        b.append(T(40, y + 34 + i * 26, line, 17, t["label"], 400, bg=t["field"],
                   op=None if not dim else None))
    return b


def iphone_capture(theme, state):
    """S-03 取り込み: a two-step full-height sheet. keyboard = step 1 (input), loading, result = step 2,
    error, limit (free quota used up)."""
    t = THEMES[theme]
    w, h = 402, 874
    sh, fd = t["sheet"], t["field"]
    if state == "result":
        b, sy = sheet_base(t, theme, w, h, "2件見つかりました", lead="back", done=True)
        b.append(S(t, 24, sy + 104, "追加する予定を選び、内容を確かめてください。", 15, bg=sh))
        y = sy + 122
        for i, (title, when, place, cal) in enumerate(FOUND):
            cy = y + i * 132
            b.append(R(24, cy, w - 48, 120, 20, fd))
            b.append(f'<g aria-label="選択中"><circle cx="50" cy="{cy+34}" r="13" fill="{t["accent"]}"/>'
                     + ico("check", 50, cy + 34, "#FFFFFF", 2.4, .7) + "</g>")
            b.append(T(76, cy + 40, title, 20, t["label"], 600, bg=fd))
            b.append(T(76, cy + 68, when, 15, t["label"], 400, bg=fd))
            b.append(S(t, 76, cy + 92, place, 15, bg=fd))
            b.append(f'<circle cx="{w - 40 - len(cal) * 13 - 10}" cy="{cy+35}" r="5" fill="{t["cal"][cal]}"/>')
            b.append(S(t, w - 40, cy + 40, cal, 13, "end", bg=fd))
            b.append(T(w - 40, cy + 100, "編集", 15, t["accent_text"], 400, "end", bg=fd))
        y2 = y + 2 * 132 + 14
        b.append(S(t, 24, y2 + 4, "元の文章", 13, bg=sh))
        b.append(R(24, y2 + 14, w - 48, 96, 16, fd))
        for i, line in enumerate(PASTED):
            b.append(S(t, 40, y2 + 42 + i * 24, line, 15, bg=fd))
        b.append(S(t, 24, y2 + 138, "AIが読み取った結果です。日時にまちがいが", 13, bg=sh))
        b.append(S(t, 24, y2 + 156, "ないか確かめてから追加してください。", 13, bg=sh))
        b.append(S(t, 24, y2 + 188, "処理はこのiPhoneの中だけで行われます。", 13, bg=sh))
    else:
        b, sy = sheet_base(t, theme, w, h, "予定を取り込む", done=False if state in ("keyboard", "loading") else None)
        if state in ("keyboard", "loading", "error"):
            b += pasted_box(t, w, sy + 92)
        if state == "keyboard":
            b.append(R(322, sy + 160, 2, 22, 0, t["accent"]))
            for i, (k, lab) in enumerate([("paste", "ペースト"), ("camera", "写真"), ("copy", "ファイル")]):
                x = 24 + i * 120
                b.append(R(x, sy + 218, 112, 44, 22, fd))
                b.append(ico(k, x + 26, sy + 240, t["label"], 1.8, .8))
                b.append(T(x + 44, sy + 246, lab, 15, t["label"], 400, bg=fd))
            ky = h - 300
            b.append(S(t, w / 2, ky - 80, QUOTA, 13, "middle", bg=sh))
            b.append(R(24, ky - 66, w - 48, 50, 25, t["accent"]))
            b.append(T(w / 2, ky - 34, "予定をさがす", 17, "#FFFFFF", 600, "middle", bg=t["accent"]))
            b.append(R(0, ky, w, 300, 0, t["kb"]))
            b.append(T(w / 2, ky + 150, "（システムのキーボード）", 15, t["label"], 400, "middle", bg=t["kb"]))
            return svg(w, h, t["bg"], "".join(b))
        if state == "loading":
            cx, cy = w / 2, sy + 290
            b.append(f'<g aria-label="処理中"><circle cx="{cx}" cy="{cy}" r="16" fill="none" stroke="{t["sep"]}" stroke-width="4"/>'
                     f'<path d="M{cx} {cy-16}a16 16 0 0 1 16 16" fill="none" stroke="{t["accent"]}" stroke-width="4" stroke-linecap="round"/></g>')
            b.append(T(w / 2, cy + 56, "予定をさがしています…", 20, t["label"], 600, "middle", bg=sh))
            b.append(S(t, w / 2, cy + 84, "このiPhoneの中で処理しています。", 15, "middle", bg=sh))
            b.append(S(t, w / 2, cy + 106, "左上の × でいつでも中止できます。", 15, "middle", bg=sh))
        if state == "error":
            y = sy + 250
            b.append(T(24, y, "予定が見つかりませんでした", 22, t["label"], 700, bg=sh))
            b.append(T(24, y + 34, "日付や時刻が書かれた文章を貼り直すか、", 17, t["label"], 400, bg=sh))
            b.append(T(24, y + 60, "写真を選び直してください。", 17, t["label"], 400, bg=sh))
            b.append(S(t, 24, y + 92, "今回は無料分の回数を使っていません。", 15, bg=sh))
            b.append(R(24, y + 122, w - 48, 50, 25, t["accent"]))
            b.append(T(w / 2, y + 154, "文章を直す", 17, "#FFFFFF", 600, "middle", bg=t["accent"]))
            b.append(R(24, y + 184, w - 48, 50, 25, fd))
            b.append(T(w / 2, y + 216, "手入力で追加", 17, t["label"], 400, "middle", bg=fd))
        if state == "limit":
            y = sy + 150
            b.append(T(24, y, "今月の無料分を使い切りました", 22, t["label"], 700, bg=sh))
            b.append(T(24, y + 36, "AI取り込みは、無料版では月5回までです。", 17, t["label"], 400, bg=sh))
            b.append(T(24, y + 62, "12月1日にまた5回使えます。", 17, t["label"], 400, bg=sh))
            b.append(T(24, y + 88, "手入力での追加は、これまでどおり使えます。", 17, t["label"], 400, bg=sh))
            b.append(R(24, y + 116, w - 48, 138, 20, fd))
            b.append(T(44, y + 152, "ペタカレ Pro", 20, t["label"], 700, bg=fd))
            b.append(T(44, y + 182, "AI取り込みが回数の制限なしで使えます", 15, t["label"], 400, bg=fd))
            b.append(T(44, y + 206, "集計・予算・まとめ画像も使えます", 15, t["label"], 400, bg=fd))
            b.append(S(t, 44, y + 234, "年額 ¥4,800・月額 ¥500・買い切り ¥9,800", 15, bg=fd))
            b.append(R(24, y + 276, w - 48, 54, 27, t["accent"]))
            b.append(T(w / 2, y + 310, "Proの内容を見る", 17, "#FFFFFF", 600, "middle", bg=t["accent"]))
            b.append(R(24, y + 342, w - 48, 50, 25, fd))
            b.append(T(w / 2, y + 374, "手入力で追加", 17, t["label"], 400, "middle", bg=fd))
    b.append(home_ind(w, h, t))
    return svg(w, h, t["bg"], "".join(b))


def iphone_slots(theme):
    """S-04 候補日メーカー (Pro): free time -> a message to paste into mail or chat."""
    t = THEMES[theme]
    w, h = 402, 874
    c = t["cell"]
    b = [status_bar(w, t), gbtn(t, 38, 84, "back", label="戻る"), gbtn(t, w - 38, 84, "share", label="共有")]
    b.append(T(20, 148, "候補日をつくる", 28, t["label"], 700))
    b.append(R(16, 166, w - 32, 132, 24, c))
    for i, (k, v) in enumerate([("期間", "来週（11/16〜11/20）"), ("長さ", "1時間"), ("時間帯", "10:00〜18:00")]):
        cy = 166 + i * 44
        b.append(T(36, cy + 28, k, 17, t["label"], 400, bg=c))
        b.append(S(t, w - 36, cy + 28, v, 17, "end", bg=c))
        if i < 2:
            b.append(R(36, cy + 43.5, w - 52, .5, 0, t["sep"]))
    b.append(S(t, 32, 326, "空いている時間（3件を選択中）", 13))
    b.append(R(16, 336, w - 32, 132, 24, c))
    for i, s in enumerate(SLOTS):
        cy = 336 + i * 44
        b.append(f'<g aria-label="選択中"><circle cx="46" cy="{cy+22}" r="11" fill="{t["accent"]}"/>'
                 + ico("check", 46, cy + 22, "#FFFFFF", 2.4, .6) + "</g>")
        b.append(T(68, cy + 28, s, 17, t["label"], 400, bg=c))
        if i < 2:
            b.append(R(68, cy + 43.5, w - 84, .5, 0, t["sep"]))
    b.append(S(t, 32, 496, "送る文面", 13))
    b.append(R(16, 506, w - 32, 176, 24, c))
    for i, line in enumerate(["以下の日程はいかがでしょうか。", "・" + SLOTS[0], "・" + SLOTS[1], "・" + SLOTS[2],
                              "ご都合をお知らせください。"]):
        b.append(T(36, 540 + i * 30, line, 17, t["label"], 400, bg=c))
    b.append(R(16, 696, w - 32, 54, 27, t["accent"]))
    b.append(ico("copy", w / 2 - 62, 723, "#FFFFFF", 2, .85))
    b.append(T(w / 2 + 8, 729, "文面をコピー", 17, "#FFFFFF", 600, "middle", bg=t["accent"]))
    b.append(tab_bar(w, h, t))
    return svg(w, h, t["bg"], "".join(b))


def iphone_permission(theme):
    t = THEMES[theme]
    w, h = 402, 874
    b = [status_bar(w, t), ico("cal", w / 2, 300, t["accent"], 2, 3.2)]
    b.append(T(w / 2, 400, "カレンダーの予定を", 28, t["label"], 700, "middle"))
    b.append(T(w / 2, 436, "表示します", 28, t["label"], 700, "middle"))
    for i, line in enumerate(["iPhoneに登録済みのカレンダー（iCloud、", "Googleなど）の予定を読み込み、", "このアプリから追加・変更します。"]):
        b.append(T(w / 2, 482 + i * 26, line, 17, t["label"], 400, "middle"))
    b.append(S(t, w / 2, 578, "予定の内容がこのiPhoneの外に", 15, "middle"))
    b.append(S(t, w / 2, 600, "送られることはありません。", 15, "middle"))
    b.append(R(20, h - 130, w - 40, 54, 27, t["accent"]))
    b.append(T(w / 2, h - 96, "続ける", 17, "#FFFFFF", 600, "middle", bg=t["accent"]))
    b.append(home_ind(w, h, t))
    return svg(w, h, t["bg"], "".join(b))


def iphone_paywall(theme):
    """S-07: name, period, price, trial length and the price after it, restore, terms, privacy."""
    t = THEMES[theme]
    w, h = 402, 874
    sh, fd = t["sheet"], t["field"]
    b, sy = sheet_base(t, theme, w, h, "", done=None)
    b.append(T(24, 176, "ペタカレ Pro", 34, t["label"], 700, bg=sh))
    b.append(T(24, 210, "予定も記録も、制限なしで残せます。", 17, t["label"], 400, bg=sh))
    feats = [("spark", "AI取り込みが回数の制限なし", "無料版は月5回まで"),
             ("chart", "集計と予算", "種目別の収支、推し活の予算と使いすぎのお知らせ"),
             ("photo", "写真を1件に10枚まで・まとめ画像", "無料版は1件に1枚"),
             ("slots", "候補日メーカー", "空き時間から日程調整の文面をつくる")]
    for i, (k, a, s) in enumerate(feats):
        cy = 232 + i * 56
        b.append(ico(k, 44, cy + 24, t["accent"], 2, 1.0))
        b.append(T(76, cy + 22, a, 17, t["label"], 600, bg=sh))
        b.append(S(t, 76, cy + 42, s, 13, bg=sh))
    y = 468
    plans = [("年額プラン", "¥4,800／年", "最初の1週間無料・2か月分お得", True),
             ("月額プラン", "¥500／月", "最初の1週間無料", False),
             ("買い切り", "¥9,800", "1回の支払いでずっと使えます（お試しなし）", False)]
    for i, (name, price, sub, on) in enumerate(plans):
        cy = y + i * 62
        st = f' stroke="{t["accent"]}" stroke-width="2"' if on else ""
        b.append(R(20, cy, w - 40, 56, 18, fd, st))
        if on:
            b.append(f'<g aria-label="選択中"><circle cx="46" cy="{cy+28}" r="11" fill="{t["accent"]}"/>'
                     + ico("check", 46, cy + 28, "#FFFFFF", 2.4, .6) + "</g>")
        else:
            b.append(f'<circle cx="46" cy="{cy+28}" r="10" fill="none" stroke="{t["sec"]}" stroke-opacity="0.6" stroke-width="1.5"/>')
        b.append(T(68, cy + 24, name, 17, t["label"], 600, bg=fd))
        b.append(S(t, 68, cy + 44, sub, 13, bg=fd))
        b.append(T(w - 36, cy + 24, price, 17, t["label"], 600, "end", bg=fd))
    b.append(S(t, w - 36, y + 3 * 62 + 12, "価格はすべて税込", 11, "end", bg=sh))
    by = y + 3 * 62 + 24
    b.append(R(20, by, w - 40, 54, 27, t["accent"]))
    b.append(T(w / 2, by + 34, "1週間無料で始める", 17, "#FFFFFF", 600, "middle", bg=t["accent"]))
    b.append(S(t, w / 2, by + 74, "無料期間が終わると ¥4,800／年で自動更新されます。", 11, "middle", bg=sh))
    b.append(S(t, w / 2, by + 90, "解約は「設定」→ 名前 →「サブスクリプション」からいつでも。", 11, "middle", bg=sh))
    b.append(T(w / 2, by + 124, "購入を復元", 17, t["accent_text"], 400, "middle", bg=sh))
    b.append(T(w / 2, by + 156, "利用規約 ・ プライバシーポリシー", 15, t["accent_text"], 400, "middle", bg=sh))
    b.append(home_ind(w, h, t))
    return svg(w, h, t["bg"], "".join(b))


# ---------- iPhone Duo ----------
def duo_outer(theme):
    t = THEMES[theme]
    w, h = 466, 678
    cw = w - 52
    b = [side_column(w, h, t)]
    b.append(T(20, 60, "2026年11月", 28, t["label"], 700))
    b.append(S(t, 20, 84, "今月の収支 +6,600円・推し活 12,100円", 13))
    b.append(month_dots(t, 16, 122, (cw - 28) / 7, 46, t["bg"], amounts=False))
    b.append(T(20, 382, "11月11日（水）・今日", 17, t["label"], 600))
    b.append(agenda(t, 16, 396, cw - 28, t["cell"], rowh=66, chars=15))
    return svg(w, h, t["bg"], "".join(b))


def duo_inner_landscape(theme, folded=False):
    t = THEMES[theme]
    w, h = 951, 669
    side, band = 52, 13
    if folded:
        lw, dx = w / 2 - band - 16, w / 2 + band
    else:
        lw = 330
        dx = 16 + lw + 16
    dw = w - side - dx - 8
    c = t["cell"]
    b = [side_column(w, h, t, camera=False)]
    b.append(R(8, 8, lw + 16, h - 16, 28, c))
    b.append(ico("sidebar", 37, 36, t["label"]))
    b.append(T(24, 96, "2026年11月", 28, t["label"], 700, bg=c))
    b.append(month_dots(t, 16, 142, lw / 7, 84, c))
    b.append(S(t, 24, h - 34, "今月の収支 +6,600円・推し活 12,100円", 13, bg=c))
    b.append(T(dx + 8, 96, "11月11日（水）・今日", 28 if not folded else 22, t["label"], 700))
    b.append(agenda(t, dx, 118, dw, c, rowh=72, chars=18 if not folded else 17))
    y = 118 + 3 * 72 + 40
    b.append(T(dx + 8, y, "11月12日（木）", 17, t["label"], 600))
    b.append(R(dx, y + 14, dw, 64, 24, c))
    b.append(S(t, dx + 18, y + 52, "予定はありません", 15, bg=c))
    return svg(w, h, t["bg"], "".join(b))


# ---------- iPad ----------
def ipad_tabbar(t, w):
    """Floating tab bar at the top centre: sidebar toggle, text-only tabs, search (as in the HIG figure)."""
    bw, x, y = 500, w / 2 - 250, 20
    p = [R(x, y, bw, 44, 22, t["glass"], f' fill-opacity="{t["glass_op"]}" stroke="{t["glass_stroke"]}"'),
         ico("sidebar", x + 28, y + 22, t["label"], 1.8, .85)]
    for i, (_, lab) in enumerate(TABS):
        cx = x + 112 + i * 98
        on = i == 0
        tb = mix(t["accent"], t["glass"], 0.12) if on else t["glass"]
        if on:
            p.append(R(cx - 46, y + 5, 92, 34, 17, tb))
        p.append(T(cx, y + 28, lab, 15, t["accent_text"] if on else t["label"], 600 if on else 400, "middle", bg=tb))
    p.append(ico("search", x + bw - 26, y + 22, t["label"], 1.8, .85))
    return "".join(p)


def ipad(theme):
    t = THEMES[theme]
    w, h = 1376, 1032
    b = [T(32, 34, "9:41", 15, t["label"], 600), T(86, 34, "11月11日（水）", 15, t["label"], 600), ipad_tabbar(t, w)]
    b.append(gbtn(t, w - 50, 42, "plus", "#FFFFFF", fill=t["accent"], label="予定を追加"))
    b.append(gbtn(t, w - 104, 42, "slots", label="候補日をつくる"))
    b.append(T(32, 126, "2026年11月", 34, t["label"], 700))
    b.append(S(t, 232, 126, "今月の収支 +6,600円・推し活 12,100円", 15))
    gx, gw = 32, 868
    b.append(R(gx, 150, gw, 852, 24, t["cell"]))
    b.append(month_chips(t, gx + 14, 192, (gw - 28) / 7, 158, t["cell"], num=15, cs=13, maxn=3, chars=7))
    ax = gx + gw + 24
    aw = w - ax - 32
    b.append(T(ax + 4, 176, "11月11日（水）・今日", 22, t["label"], 700))
    b.append(agenda(t, ax, 192, aw, t["cell"], rowh=72, chars=19))
    y = 192 + 3 * 72 + 44
    b.append(T(ax + 4, y, "11月12日（木）", 17, t["label"], 600))
    b.append(R(ax, y + 14, aw, 64, 24, t["cell"]))
    b.append(S(t, ax + 18, y + 52, "予定はありません", 15, bg=t["cell"]))
    return svg(w, h, t["bg"], "".join(b))


def ipad_narrow(theme):
    """Narrow iPad window: window controls lead the toolbar; the grid goes compact and the list sits below."""
    t = THEMES[theme]
    w, h = 600, 1032
    b = [T(24, 34, "9:41", 15, t["label"], 600)]
    for k, cc in enumerate(("#FF5F57", "#FEBC2E", "#28C840")):
        b.append(f'<circle cx="{30 + k * 20}" cy="80" r="6" fill="{cc}"/>')
    b.append(gbtn(t, 120, 80, "sidebar", label="サイドバー"))
    b.append(gbtn(t, w - 44, 80, "plus", "#FFFFFF", fill=t["accent"], label="予定を追加"))
    b.append(gbtn(t, w - 98, 80, "slots", label="候補日をつくる"))
    b.append(gbtn(t, w - 152, 80, "search", label="検索"))
    b.append(T(24, 150, "2026年11月", 34, t["label"], 700))
    b.append(S(t, 24, 178, "今月の収支 +6,600円・推し活 12,100円", 15))
    b.append(month_dots(t, 20, 224, (w - 40) / 7, 62, t["bg"]))
    b.append(T(24, 572, "11月11日（水）・今日", 20, t["label"], 600))
    b.append(agenda(t, 20, 588, w - 40, t["cell"], chars=26))
    return svg(w, h, t["bg"], "".join(b))


# ---------- Mac ----------
def mac(theme):
    t = THEMES[theme]
    w, h = 1440, 900
    b = [R(0, 0, w, 26, 0, t["bar"], ' fill-opacity="0.9"')]
    x = 20
    for i, m in enumerate(["ペタカレ", "ファイル", "編集", "表示", "ウインドウ", "ヘルプ"]):
        b.append(T(x, 18, m, 13, t["label"], 700 if i == 0 else 400, bg=t["bar"]))
        x += len(m) * 13 + 22
    b.append(T(w - 20, 18, "11月11日(水) 9:41", 13, t["label"], 400, "end", bg=t["bar"]))
    wx, wy, ww, wh = 110, 70, 1220, 780
    win, sd = t["win"], t["side"]
    b.append(R(wx, wy, ww, wh, 16, win, f' stroke="{t["glass_stroke"]}"'))
    sw = 220
    b.append(R(wx + 8, wy + 8, sw, wh - 16, 12, sd))
    for i, cc in enumerate(("#FF5F57", "#FEBC2E", "#28C840")):
        b.append(f'<circle cx="{wx+28+i*20}" cy="{wy+28}" r="6" fill="{cc}"/>')
    for i, (sym, lab) in enumerate(TABS[:3]):
        y = wy + 60 + i * 32
        on = i == 0
        rb = mix(t["accent"], sd, 0.16) if on else sd
        if on:
            b.append(R(wx + 16, y, sw - 16, 28, 6, rb))
        b.append(ico(sym, wx + 34, y + 14, t["accent_text"] if on else t["label"], 1.5, .7))
        b.append(T(wx + 52, y + 19, lab, 13, t["label"], 600 if on else 400, bg=rb))
    b.append(S(t, wx + 24, wy + 182, "表示するカレンダー", 11, bg=sd))
    for i, cal in enumerate(["仕事", "プライベート", "家族"]):
        y = wy + 194 + i * 28
        b.append(R(wx + 26, y + 6, 14, 14, 4, t["cal"][cal]))
        b.append(ico("check", wx + 33, y + 13, "#FFFFFF", 2.4, .45))
        b.append(T(wx + 52, y + 18, cal, 13, t["label"], 400, bg=sd))
    b.append(S(t, wx + 24, wy + wh - 28, "AI取り込み 残り 3 回", 11, bg=sd))
    # unified title bar + toolbar
    lx = wx + sw + 28
    b.append(T(lx, wy + 26, "2026年11月", 13, t["label"], 700, bg=win))
    b.append(S(t, lx, wy + 42, "今月の収支 +6,600円・推し活 12,100円", 11, bg=win))
    rx = wx + ww - 16
    b.append(R(rx - 180, wy + 14, 180, 28, 8, t["bar"]) + ico("search", rx - 164, wy + 28, t["sec"], 1.6, .7))
    b.append(S(t, rx - 150, wy + 32, "検索", 13, bg=t["bar"]))
    b.append(R(rx - 220, wy + 14, 28, 28, 6, t["accent"]) + ico("plus", rx - 206, wy + 28, "#FFFFFF", 2, .75))
    b.append(R(rx - 256, wy + 14, 28, 28, 6, t["bar"]) + ico("slots", rx - 242, wy + 28, t["label"], 1.6, .7))
    b.append(R(rx - 330, wy + 14, 62, 28, 6, t["bar"]))
    b.append(T(rx - 299, wy + 33, "今日", 13, t["label"], 400, "middle", bg=t["bar"]))
    b.append(R(lx - 12, wy + 54, ww - sw - 24, .5, 0, t["sep"]))
    iw = 270  # inspector: selected day
    gw = ww - sw - 28 - iw - 24
    b.append(month_chips(t, lx, wy + 92, gw / 7, 132, win, num=13, cs=11, maxn=3, chars=7))
    ix = lx + gw + 16
    b.append(R(ix - 8, wy + 54, .5, wh - 62, 0, t["sep"]))
    b.append(T(ix + 8, wy + 86, "11月11日（水）・今日", 15, t["label"], 700, bg=win))
    for i, (st, en, title, cal, place) in enumerate(EVENTS):
        y = wy + 104 + i * 58
        if st == "rec":
            b.append(R(ix + 8, y + 6, 3, 40, 1, t["sec"]))
            b.append(T(ix + 20, y + 20, title, 13, t["label"], 600, bg=win))
            b.append(S(t, ix + 20, y + 37, "記録・" + cal, 11, bg=win))
            b.append(amt(t, ix + iw - 28, y + 28, place, 13, bg=win))
            continue
        b.append(R(ix + 8, y + 6, 3, 40, 1.5, t["cal"][cal]))
        b.append(T(ix + 20, y + 20, title, 13, t["label"], 600, bg=win))
        b.append(S(t, ix + 20, y + 37, f"{st}〜{en}・{place}", 11, bg=win))
    return svg(w, h, t["desk"], "".join(b))


# ---------- records (S-09〜S-14) ----------
def seg(t, x, y, w, labels, active, bg):
    """Segmented control (text only, equal widths)."""
    p = [R(x, y, w, 36, 18, bg)]
    sw = w / len(labels)
    for i, lab in enumerate(labels):
        on = i == active
        cb = t["cell"] if on else bg
        if on:
            p.append(R(x + sw * i + 3, y + 3, sw - 6, 30, 15, cb, f' stroke="{t["glass_stroke"]}"'))
        p.append(T(x + sw * (i + .5), y + 23, lab, 15, t["label"], 600 if on else 400, "middle", bg=cb))
    return "".join(p)


def switch(t, x, y, on=True):
    c = t["cal"]["プライベート"] if on else t["sep"]
    return (f'<g aria-label="{"オン" if on else "オフ"}">' + R(x, y, 51, 31, 15.5, c)
            + f'<circle cx="{x + (35.5 if on else 15.5)}" cy="{y+15.5}" r="13.5" fill="#FFFFFF"/></g>')


def rec_row(t, b, x, cy, w, d, bg, chars=10, k=0):
    title, kind, n, photo = RECORDS[d]
    if photo:
        b.append(thumb(t, x + 14, cy + 12, 44, k))
    else:
        b.append(R(x + 14, cy + 12, 44, 44, 10, mix(t["sec"], bg, 0.12)) + ico("note", x + 36, cy + 34, t["label"], 1.6, .8))
    s2 = title if len(title) <= chars else title[:chars - 1] + "…"
    b.append(T(x + 72, cy + 30, s2, 17, t["label"], 400, bg=bg))
    b.append(S(t, x + 72, cy + 50, kind, 13, bg=bg))
    b.append(amt(t, x + w - 34, cy + 38, n, 17, bg=bg))
    b.append(ico("chev", x + w - 18, cy + 34, t["sec"], 2, .8))


def iphone_records(theme, state="list"):
    """S-10 記録タブ: list by day / empty / locked."""
    t = THEMES[theme]
    w, h = 402, 874
    b = [status_bar(w, t), gbtn(t, w - 38, 84, "plus", "#FFFFFF", fill=t["accent"], label="記録を追加"),
         T(20, 150, "記録", 34, t["label"], 700)]
    if state == "list":
        b.append(seg(t, 16, 168, w - 32, ["すべて", "収支", "推し活"], 0, mix(t["sec"], t["bg"], 0.10)))
        y = 232
        for k, d in enumerate([11, 8, 7, 3]):
            b.append(S(t, 32, y, f"11月{d}日（{WD[d]}）" + ("・今日" if d == TODAY else ""), 13))
            b.append(R(16, y + 10, w - 32, 68, 22, t["cell"]))
            rec_row(t, b, 16, y + 10, w - 32, d, t["cell"], k=k)
            y += 108
    elif state == "empty":
        b.append(ico("note", w / 2, 340, t["sec"], 2, 1.8))
        b.append(T(w / 2, 402, "まだ記録がありません", 22, t["label"], 700, "middle"))
        b.append(S(t, w / 2, 432, "写真・金額・メモを、その日に残せます。", 15, "middle"))
        b.append(R(w / 2 - 90, 462, 180, 50, 25, t["accent"]))
        b.append(T(w / 2, 494, "記録を追加", 17, "#FFFFFF", 600, "middle", bg=t["accent"]))
    else:  # locked
        b.append(ico("lock", w / 2, 340, t["sec"], 2, 2.0))
        b.append(T(w / 2, 410, "記録はロックされています", 22, t["label"], 700, "middle"))
        b.append(S(t, w / 2, 440, "Face ID か Touch ID で開きます。", 15, "middle"))
        b.append(S(t, w / 2, 462, "予定はロック中も見られます。", 15, "middle"))
        b.append(R(w / 2 - 90, 492, 180, 50, 25, t["accent"]))
        b.append(T(w / 2, 524, "ロックを解除", 17, "#FFFFFF", 600, "middle", bg=t["accent"]))
    b.append(tab_bar(w, h, t, active=1))
    return svg(w, h, t["bg"], "".join(b))


def iphone_record_add(theme):
    """S-09 記録を追加 (number keyboard shown: nothing is covered)."""
    t = THEMES[theme]
    w, h = 402, 874
    sh, fd = t["sheet"], t["field"]
    b, sy = sheet_base(t, theme, w, h, "記録を追加", done=True)
    b.append(seg(t, 24, sy + 86, w - 48, ["収支", "推し活", "自由"], 0, fd))
    y = sy + 136
    b.append(R(24, y, w - 48, 192, 16, fd))
    rows = [("日付", "11月11日（水）"), ("種目", "FX"), ("金額", ""), ("メモ", "午前の取引")]
    for i, (k, v) in enumerate(rows):
        cy = y + i * 48
        b.append(T(40, cy + 30, k, 17, t["label"], 400, bg=fd))
        if k == "金額":
            b.append(R(w - 236, cy + 8, 84, 32, 16, sh))
            b.append(R(w - 233, cy + 11, 39, 26, 13, t["plus"]))
            b.append(T(w - 213.5, cy + 30, "+", 17, "#FFFFFF" if theme == "light" else "#000000", 700, "middle", bg=t["plus"]))
            b.append(T(w - 172.5, cy + 30, "−", 17, t["label"], 400, "middle", bg=sh))
            b.append(T(w - 62, cy + 30, "5,400", 17, t["label"], 600, "end", bg=fd))
            b.append(R(w - 60, cy + 13, 2, 22, 0, t["accent"]))
            b.append(S(t, w - 40, cy + 30, "円", 17, "end", bg=fd))
        else:
            b.append(S(t, w - 40, cy + 30, v, 17, "end", bg=fd))
        if i < 3:
            b.append(R(40, cy + 47.5, w - 80, .5, 0, t["sep"]))
    py = y + 206
    b.append(thumb(t, 24, py, 64, 0, 12))
    b.append(R(98, py, 64, 64, 12, fd) + ico("plus", 130, py + 24, t["label"], 2, .8))
    b.append(T(130, py + 54, "写真", 11, t["label"], 400, "middle", bg=fd))
    b.append(S(t, 176, py + 28, "写真から金額と日付を読み取ります", 13, bg=sh))
    b.append(S(t, 176, py + 46, "無料版は1件に1枚まで", 13, bg=sh))
    ky = h - 300
    b.append(R(0, ky, w, 300, 0, t["kb"]))
    b.append(T(w / 2, ky + 150, "（システムの数字キーボード）", 15, t["label"], 400, "middle", bg=t["kb"]))
    return svg(w, h, t["bg"], "".join(b))


def iphone_stats(theme):
    """S-11 集計 (Pro): month total, by kind, 推し活 budget, summary image."""
    t = THEMES[theme]
    w, h = 402, 874
    c = t["cell"]
    b = [status_bar(w, t)]
    b.append(R(w - 132, 62, 116, 44, 22, t["glass"], f' fill-opacity="{t["glass_op"]}" stroke="{t["glass_stroke"]}"'))
    b.append(T(w - 82, 90, "2026年11月", 15, t["label"], 400, "middle", bg=t["glass"]))
    b.append(f'<path d="M{w-36} 81l5 5 5-5" fill="none" stroke="{t["label"]}" stroke-width="2" stroke-linecap="round"/>')
    b.append(T(20, 150, "集計", 34, t["label"], 700))
    b.append(R(16, 170, w - 32, 106, 24, c))
    b.append(S(t, 36, 200, "収支（FX・競馬・競艇）", 15, bg=c))
    b.append(amt(t, 36, 244, 6600, 34, "start", bg=c, weight=700))
    b.append(S(t, w - 36, 244, "プラス2件・マイナス1件", 13, "end", bg=c))
    b.append(R(16, 288, w - 32, 144, 24, c))
    for i, (k, n) in enumerate([("FX", 5400), ("競馬", 3200), ("競艇", -2000)]):
        cy = 288 + i * 48
        b.append(T(36, cy + 30, k, 17, t["label"], 400, bg=c))
        bw = abs(n) / 5400 * 120
        b.append(R(100, cy + 18, bw, 12, 4, t["plus"] if n > 0 else t["minus"]))
        b.append(amt(t, w - 36, cy + 30, n, 17, bg=c))
        if i < 2:
            b.append(R(36, cy + 47.5, w - 52, .5, 0, t["sep"]))
    b.append(R(16, 444, w - 32, 128, 24, c))
    b.append(S(t, 36, 474, "推し活の予算", 15, bg=c))
    b.append(T(36, 506, "12,100円", 22, t["label"], 700, bg=c))
    b.append(S(t, 142, 506, "／ 15,000円", 15, bg=c))
    b.append(R(36, 520, w - 72, 10, 5, t["sep"]))
    b.append(R(36, 520, (w - 72) * 0.81, 10, 5, t["warn"]))
    b.append(ico("warn", 46, 551, t["warn"], 1.8, .7))
    b.append(T(62, 556, "予算の81%を使いました（残り2,900円）", 13, t["warn"], 600, bg=c))
    b.append(R(16, 590, w - 32, 54, 27, t["accent"]))
    b.append(T(w / 2, 624, "まとめ画像をつくる", 17, "#FFFFFF", 600, "middle", bg=t["accent"]))
    b.append(S(t, w / 2, 668, "記録に入力した金額の合計です。", 13, "middle"))
    b.append(tab_bar(w, h, t, active=2))
    return svg(w, h, t["bg"], "".join(b))


def iphone_summary(theme):
    """S-12 月のまとめ画像: preview + what to show + save."""
    t = THEMES[theme]
    w, h = 402, 874
    c = t["cell"]
    b = [status_bar(w, t), gbtn(t, 38, 84, "back", label="戻る"), gbtn(t, w - 38, 84, "share", label="共有")]
    b.append(T(20, 148, "まとめ画像", 28, t["label"], 700))
    ix, iy, iw, ih = 61, 166, 280, 350
    cb = "#1F2A44"
    b.append(R(ix, iy, iw, ih, 20, cb))
    b.append(T(ix + 24, iy + 44, "2026年11月", 15, "#C9D4EA", 600, bg=cb))
    b.append(T(ix + 24, iy + 76, "今月の収支", 13, "#C9D4EA", 400, bg=cb))
    b.append(T(ix + 24, iy + 120, "+6,600円", 34, "#FFFFFF", 700, bg=cb))
    for i, (k, v) in enumerate([("FX", "+5,400"), ("競馬", "+3,200"), ("競艇", "−2,000")]):
        yy = iy + 162 + i * 30
        b.append(T(ix + 24, yy, k, 15, "#FFFFFF", 400, bg=cb))
        b.append(T(ix + iw - 24, yy, v, 15, "#FFFFFF", 600, "end", bg=cb))
    b.append(R(ix + 24, iy + 242, iw - 48, .5, 0, "#5B6B8F"))
    b.append(T(ix + 24, iy + 274, "推し活", 15, "#FFFFFF", 400, bg=cb))
    b.append(T(ix + iw - 24, iy + 274, "12,100円・2件", 15, "#FFFFFF", 600, "end", bg=cb))
    b.append(T(ix + iw - 24, iy + 326, "ペタカレ", 11, "#C9D4EA", 600, "end", bg=cb))
    b.append(R(16, 532, w - 32, 96, 24, c))
    for i, (k, on) in enumerate([("金額を表示", True), ("推し活を含める", True)]):
        cy = 532 + i * 48
        b.append(T(36, cy + 30, k, 17, t["label"], 400, bg=c))
        b.append(switch(t, w - 87, cy + 8.5, on))
        if i == 0:
            b.append(R(36, cy + 47.5, w - 52, .5, 0, t["sep"]))
    b.append(S(t, 32, 650, "金額を隠すと、プラス・マイナスの件数だけになります。", 13))
    b.append(R(16, 672, w - 32, 54, 27, t["accent"]))
    b.append(T(w / 2, 706, "画像を保存", 17, "#FFFFFF", 600, "middle", bg=t["accent"]))
    b.append(tab_bar(w, h, t, active=2))
    return svg(w, h, t["bg"], "".join(b))


def iphone_share(theme):
    """S-13 共有シートから受け取ったとき（LINE などの「他のアプリ」から）."""
    t = THEMES[theme]
    w, h = 402, 874
    sh, fd = t["sheet"], t["field"]
    b, sy = sheet_base(t, theme, w, h, "ペタカレに送る", done=None)
    b.append(S(t, 24, sy + 104, "受け取った内容", 13, bg=sh))
    b.append(R(24, sy + 114, w - 48, 112, 16, fd))
    b.append(thumb(t, 36, sy + 126, 88, 1, 10))
    for i, line in enumerate(["18日(水)15時からで", "お願いします。場所は", "会議室Bです。"]):
        b.append(T(138, sy + 152 + i * 26, line, 17, t["label"], 400, bg=fd))
    y = sy + 250
    b.append(R(24, y, w - 48, 160, 20, fd))
    for i, (k, a, s2) in enumerate([("cal", "予定にする", "日付と時刻を読み取ってカレンダーに追加"),
                                    ("note", "記録にする", "写真とメモを今日の記録として保存")]):
        cy = y + i * 80
        b.append(R(40, cy + 18, 44, 44, 12, mix(t["accent"], fd, 0.16)) + ico(k, 62, cy + 40, t["accent_text"], 1.8, .9))
        b.append(T(100, cy + 36, a, 17, t["label"], 600, bg=fd))
        b.append(S(t, 100, cy + 58, s2, 13, bg=fd))
        b.append(ico("chev", w - 44, cy + 40, t["sec"], 2, .8))
        if i == 0:
            b.append(R(100, cy + 79.5, w - 140, .5, 0, t["sep"]))
    b.append(S(t, 24, y + 188, "「予定にする」はAI取り込みを1回使います。", 13, bg=sh))
    b.append(S(t, 24, y + 208, "今月の残り3回（無料版は月5回）。", 13, bg=sh))
    b.append(S(t, 24, y + 228, "「記録にする」は回数に数えません。", 13, bg=sh))
    b.append(home_ind(w, h, t))
    return svg(w, h, t["bg"], "".join(b))


def iphone_bulk(theme):
    """S-14 写真をまとめて追加: photos are grouped by the day they were taken."""
    t = THEMES[theme]
    w, h = 402, 874
    sh, fd = t["sheet"], t["field"]
    b, sy = sheet_base(t, theme, w, h, "写真をまとめて追加", lead="back", done=True)
    b.append(T(24, sy + 112, "6枚を3日分の記録にします", 22, t["label"], 700, bg=sh))
    b.append(S(t, 24, sy + 138, "撮った日ごとに分けました。日付は直せます。", 15, bg=sh))
    y = sy + 158
    for g, (d, n) in enumerate([(7, 2), (8, 1), (11, 3)]):
        cy = y + g * 126
        b.append(R(24, cy, w - 48, 114, 20, fd))
        b.append(T(40, cy + 30, f"11月{d}日（{WD[d]}）", 17, t["label"], 600, bg=fd))
        b.append(S(t, w - 40, cy + 30, f"{n}枚", 15, "end", bg=fd))
        for k in range(n):
            b.append(thumb(t, 40 + k * 66, cy + 44, 58, g + k, 10))
    y2 = y + 3 * 126 + 6
    b.append(R(24, y2, w - 48, 48, 16, fd))
    b.append(T(40, y2 + 30, "記録の型", 17, t["label"], 400, bg=fd))
    b.append(S(t, w - 40, y2 + 30, "自由", 17, "end", bg=fd))
    b.append(S(t, 24, y2 + 76, "撮影日が分からない写真は、今日の記録に入ります。", 13, bg=sh))
    b.append(home_ind(w, h, t))
    return svg(w, h, t["bg"], "".join(b))


# ---------- month with event bars (iPhone S-01, second look) ----------
# Fictional events: (first day, last day, title, calendar). Multi-day events draw as one bar across days.
SPANS = [(3, 3, "文化の日", "祝日"), (4, 6, "展示会の設営と本番", "仕事"), (9, 10, "出張（みなと市）", "仕事"),
         (11, 11, "週次ミーティング", "仕事"), (11, 11, "そらまめ商店", "仕事"), (14, 14, "家族で買い出し", "家族"),
         (18, 18, "打ち合わせ", "仕事"), (19, 21, "ソラマメーズ遠征", "プライベート"), (20, 20, "資料提出", "仕事"),
         (25, 25, "懇親会", "プライベート"), (27, 29, "実家へ帰省", "家族"), (28, 28, "大掃除", "家族")]


def cal_color(t, cal):
    return t["red"] if cal == "祝日" else t["cal"][cal]


def month_bars(t, x, y, cw, rh, bg, lanes=3, lane_h=21, num=15):
    """Month grid that fills the screen: day number, up to `lanes` event bars, then the day's amount.
    Bars carry the title (never colour alone); a bar that continues from the previous week has no cap."""
    p = []
    for i, d in enumerate("日月火水木金土"):
        p.append(S(t, x + cw * (i + .5), y - 8, d, 12, "middle", bg=bg))
    for r in range(6):
        p.append(R(x, y + rh * r, cw * 7, 0.5, 0, t["sep"]))
    for d in range(1, 31):
        col, row = (d - 1) % 7, (d - 1) // 7
        cx, cy = x + cw * col + cw / 2, y + rh * row + 14
        if d == TODAY:
            p.append(f'<circle cx="{cx:g}" cy="{cy:g}" r="11" fill="{t["accent"]}"/>')
            p.append(T(cx, cy + 5, str(d), 13, "#FFFFFF", 700, "middle", bg=t["accent"]))
        else:
            p.append(T(cx, cy + 5, str(d), 13, t["label"], 400, "middle", bg=bg))
    for row in range(5):
        first, last = row * 7 + 1, min(row * 7 + 7, 30)
        segs = sorted([(max(a, first), min(b, last), title, cal, a >= first, b <= last)
                       for a, b, title, cal in SPANS if a <= last and b >= first],
                      key=lambda g: (g[0], -(g[1] - g[0])))
        used = []      # per lane: last occupied day
        hidden = {}    # day -> events that did not fit
        for a, b, title, cal, starts, ends in segs:
            lane = next((i for i, end in enumerate(used) if end < a), None)
            if lane is None:
                lane = len(used)
                used.append(0)
            used[lane] = b
            if lane >= lanes:
                for d in range(a, b + 1):
                    hidden[d] = hidden.get(d, 0) + 1
                continue
            c = cal_color(t, cal)
            bx = x + ((a - 1) % 7) * cw + (2 if starts else 0)
            bw = (b - a + 1) * cw - (2 if starts else 0) - (2 if ends else 0)
            by = y + rh * row + 28 + lane * lane_h
            cb = mix(c, bg, 0.24)
            p.append(R(bx, by, bw, lane_h - 3, t.get("bar_rx", 5), cb))
            if starts:
                p.append(R(bx, by, 3, lane_h - 3, 1.5, c))
            chars = max(1, int((bw - 8) / (11.0 if a == b else 11.6)))
            if len(title) <= chars:
                label = title
            elif a == b:
                label = title[:chars]          # one-day bars are narrow: fill the width, no ellipsis
            else:
                label = title[:max(1, chars - 1)] + "…"
            p.append(T(bx + 6, by + 13, label, 11, t["label"], 400, bg=cb))
        for d in range(first, last + 1):
            dx = x + ((d - 1) % 7) * cw
            ly = y + rh * row + 28 + lanes * lane_h
            if d in RECORDS:
                p.append(R(dx + 5, ly + 5, 5, 5, 1, t["sec"]))
                p.append(amt(t, dx + cw - 4, ly + 12, RECORDS[d][2], 11, "end", bg=bg, unit=False))
            elif d in hidden:
                p.append(S(t, dx + cw / 2, ly + 12, f"ほか{hidden[d]}件", 11, "middle", bg=bg))
    return "".join(p)


def part_sheet(t, theme, w, h, top, dim=0.18):
    """A resizable (medium) sheet: grabber at the top, content below."""
    return [R(0, 0, w, h, 0, "#000000", f' fill-opacity="{dim if theme == "light" else dim * 2}"'),
            f'<path d="M0 {top+38}a38 38 0 0 1 38 -38h{w-76}a38 38 0 0 1 38 38v{h-top-38}h-{w}z" fill="{t["sheet"]}"/>',
            R(w / 2 - 18, top + 8, 36, 5, 2.5, t["sec"], ' fill-opacity="0.4"')]


def cal_header(t, w, title, active):
    """Top of the calendar tab: 今日, 候補日, ＋, the title, this month's totals and the 日/週/月 switch."""
    b = iphone_top(t, w, title=title, sub="")
    b.append(S(t, w - 20, 134, "収支 +6,600円", 13, "end"))
    b.append(S(t, w - 20, 152, "推し活 12,100円", 13, "end"))
    b.append(seg(t, 16, 164, w - 32, ["日", "週", "月"], active, mix(t["sec"], t["bg"], 0.10)))
    return b


def timeline(t, x, y, w, hours, hh, bg):
    """Hour lines with labels in a 36pt gutter."""
    p = []
    for i, hour in enumerate(hours):
        yy = y + i * hh
        p.append(S(t, x + 30, yy + 4, f"{hour}:00", 11, "end", bg=bg))
        p.append(R(x + 36, yy, w - 36, 0.5, 0, t["sep"]))
    return "".join(p)


def block(t, x, y, w, h, title, cal, bg, sub=None, size=11):
    c = cal_color(t, cal)
    cb = mix(c, bg, 0.26)
    p = [R(x, y, w, h, 6, cb), R(x, y, 3, h, 1.5, c)]
    chars = max(1, int((w - 10) / (size + 0.6)))
    lines = [title[i:i + chars] for i in range(0, len(title), chars)][:max(1, int((h - 4) / (size + 4)))]
    for i, line in enumerate(lines):
        p.append(T(x + 7, y + size + 4 + i * (size + 4), line, size, t["label"], 600 if size > 11 else 400, bg=cb))
    if sub and h >= (size + 4) * (len(lines) + 1) + 4:
        p.append(S(t, x + 7, y + size + 4 + len(lines) * (size + 4), sub, 13, bg=cb))
    return "".join(p)


def iphone_week(theme):
    """S-01 週: seven days with all-day bars, each day's amount, and timed blocks."""
    t = THEMES[theme]
    w, h = 402, 874
    bg = t["bg"]
    b = cal_header(t, w, "2026年11月", 1)
    gx, cw = 44, (w - 44 - 8) / 7
    for i, d in enumerate(range(8, 15)):
        cx = gx + cw * (i + .5)
        b.append(S(t, cx, 222, "日月火水木金土"[i], 12, "middle"))
        if d == TODAY:
            b.append(f'<circle cx="{cx:g}" cy="242" r="13" fill="{t["accent"]}"/>')
            b.append(T(cx, 248, str(d), 17, "#FFFFFF", 600, "middle", bg=t["accent"]))
        else:
            b.append(T(cx, 248, str(d), 17, t["label"], 400, "middle"))
        if d in RECORDS:
            b.append(amt(t, cx, 272, RECORDS[d][2], 11, "middle", bg=bg, unit=False))
    b.append(S(t, 38, 296, "終日", 11, "end"))
    b.append(block(t, gx + cw + 2, 282, cw * 2 - 4, 20, "出張（みなと市）", "仕事", bg))
    b.append(block(t, gx + cw * 6 + 2, 282, cw - 4, 20, "家族で買い出し", "家族", bg))
    y0, hh = 322, 44
    b.append(timeline(t, 8, y0, w - 16, range(9, 20), hh, bg))
    for c in range(1, 7):
        b.append(R(gx + cw * c, y0, 0.5, hh * 10, 0, t["sep"]))
    def at(col, start, end, title, cal):
        return block(t, gx + cw * col + 2, y0 + (start - 9) * hh + 1, cw - 4, (end - start) * hh - 2, title, cal, bg)
    b.append(at(3, 10, 11, "週次ミーティング", "仕事"))
    b.append(at(3, 13.5, 14.5, "そらまめ商店 打ち合わせ", "仕事"))
    b.append(at(4, 15, 16.5, "企画レビュー", "仕事"))
    b.append(at(5, 11, 12, "面談", "仕事"))
    b.append(at(2, 16, 18, "移動", "仕事"))
    # now line at 9:41
    ny = y0 + (9 + 41 / 60 - 9) * hh
    b.append(R(gx + cw * 3, ny - 1, cw, 2, 1, t["red"]) + f'<circle cx="{gx + cw * 3:g}" cy="{ny:g}" r="4" fill="{t["red"]}"/>')
    b.append(tab_bar(w, h, t))
    return svg(w, h, t["bg"], "".join(b))


def iphone_dayview(theme):
    """S-01 日: one day. Records on top, then the timeline."""
    t = THEMES[theme]
    w, h = 402, 874
    bg = t["bg"]
    b = cal_header(t, w, "11月11日（水）", 0)
    b.append(S(t, 24, 228, "記録", 13))
    b.append(R(16, 236, w - 32, 68, 22, t["cell"]))
    rec_row(t, b, 16, 236, w - 32, 11, t["cell"])
    y0, hh = 330, 44
    b.append(timeline(t, 8, y0, w - 16, range(9, 20), hh, bg))
    def at(start, end, title, cal, sub):
        return block(t, 48, y0 + (start - 9) * hh + 1, w - 48 - 16, (end - start) * hh - 2, title, cal, bg, sub, 15)
    b.append(at(10, 11, "週次ミーティング", "仕事", "オンライン"))
    b.append(at(13.5, 14.5, "そらまめ商店 打ち合わせ", "仕事", "みどり台ビル 3階"))
    ny = y0 + (41 / 60) * hh
    b.append(R(44, ny - 1, w - 60, 2, 1, t["red"]) + f'<circle cx="44" cy="{ny:g}" r="4" fill="{t["red"]}"/>')
    b.append(tab_bar(w, h, t))
    return svg(w, h, t["bg"], "".join(b))


def iphone_month(theme, state="month"):
    """S-01 月 with event bars. state: month / day (the day's sheet) / event (S-02 as a sheet)."""
    t = THEMES[theme]
    w, h = 402, 874
    b = cal_header(t, w, "2026年11月", 2)
    b.append(month_bars(t, 8, 228, (w - 16) / 7, 108, t["bg"]))
    if state == "month":
        b.append(tab_bar(w, h, t))
        return svg(w, h, t["bg"], "".join(b))
    sh, fd = t["sheet"], t["field"]
    if state == "day":
        top = 468
        b += part_sheet(t, theme, w, h, top)
        b.append(T(24, top + 56, "11月11日（水）・今日", 20, t["label"], 600, bg=sh))
        b.append(gbtn(t, w - 46, top + 48, "plus", "#FFFFFF", fill=t["accent"], label="この日に追加"))
        b.append(agenda(t, 16, top + 84, w - 32, fd))
        b.append(S(t, 24, top + 316, "予定をタップすると内容が開きます。", 13, bg=sh))
    else:
        top = 520
        b += part_sheet(t, theme, w, h, top)
        c = t["cal"]["プライベート"]
        b.append(f'<circle cx="34" cy="{top+56}" r="7" fill="{c}"/>')
        b.append(T(52, top + 64, "ソラマメーズ遠征", 22, t["label"], 700, bg=sh))
        b.append(T(52, top + 96, "11月19日（木）〜 11月21日（土）", 17, t["label"], 400, bg=sh))
        b.append(S(t, 52, top + 122, "終日・プライベート", 15, bg=sh))
        b.append(R(52, top + 144, w - 76, .5, 0, t["sep"]))
        b.append(ico("cal", 34, top + 174, t["sec"], 1.8, .8))
        b.append(T(52, top + 180, "前日の 9:00 に通知", 17, t["label"], 400, bg=sh))
        b.append(ico("note", 34, top + 218, t["sec"], 1.8, .8))
        b.append(T(52, top + 224, "この期間の記録 2件", 17, t["label"], 400, bg=sh))
        b.append(ico("chev", w - 34, top + 218, t["sec"], 2, .8))
        b.append(R(24, top + 262, (w - 60) / 2, 50, 25, fd))
        b.append(T(24 + (w - 60) / 4, top + 294, "編集", 17, t["label"], 400, "middle", bg=fd))
        b.append(R(36 + (w - 60) / 2, top + 262, (w - 60) / 2, 50, 25, fd))
        b.append(T(36 + (w - 60) * 3 / 4, top + 294, "予定を削除", 17, t["red"], 400, "middle", bg=fd))
    b.append(home_ind(w, h, t))
    return svg(w, h, t["bg"], "".join(b))


# ---------- month display patterns (設定 → カレンダーの表示) ----------
PHOTO_DAYS = {3: 0, 7: 1, 14: 2, 19: 3, 20: 0, 21: 1, 25: 2}


def month_cells(t, x, y, cw, rh, bg, kind):
    """Month grid for the 金額 and 写真 patterns: day number, small marks for events, then the main item."""
    p = []
    for i, d in enumerate("日月火水木金土"):
        p.append(S(t, x + cw * (i + .5), y - 8, d, 12, "middle", bg=bg))
    for r in range(6):
        p.append(R(x, y + rh * r, cw * 7, 0.5, 0, t["sep"]))
    busy = {}
    for a, b_, _, cal in SPANS:
        for d in range(a, b_ + 1):
            busy.setdefault(d, []).append(cal)
    for d in range(1, 31):
        col, row = (d - 1) % 7, (d - 1) // 7
        cx, cy = x + cw * col + cw / 2, y + rh * row + 14
        if d == TODAY:
            p.append(f'<circle cx="{cx:g}" cy="{cy:g}" r="11" fill="{t["accent"]}"/>')
            p.append(T(cx, cy + 5, str(d), 13, "#FFFFFF", 700, "middle", bg=t["accent"]))
        else:
            p.append(T(cx, cy + 5, str(d), 13, t["label"], 400, "middle", bg=bg))
        cals = busy.get(d, [])[:3]
        for k, cal in enumerate(cals):
            p.append(f'<circle cx="{cx + (k - (len(cals) - 1) / 2) * 8:g}" cy="{cy + 18:g}" r="2.5" fill="{cal_color(t, cal)}"/>')
        top = y + rh * row + 40
        if kind == "amount" and d in RECORDS:
            n = RECORDS[d][2]
            cb = mix(t["plus"] if n > 0 else t["minus"], bg, 0.12)
            p.append(R(x + cw * col + 3, top, cw - 6, 44, 10, cb))
            p.append(T(cx, top + 19, "+" if n > 0 else "−", 13, t["plus"] if n > 0 else t["minus"], 700, "middle", bg=cb))
            p.append(T(cx, top + 36, f"{abs(n):,}", 13, t["label"], 600, "middle", bg=cb))
        if kind == "photo":
            if d in PHOTO_DAYS:
                p.append(thumb(t, x + cw * col + 4, top - 4, cw - 8, PHOTO_DAYS[d], 8))
            if d in RECORDS and d not in PHOTO_DAYS:
                p.append(amt(t, cx, top + 20, RECORDS[d][2], 11, "middle", bg=bg, unit=False))
    return "".join(p)


def iphone_pattern(theme, kind):
    """S-01 月 in the other display patterns: dots (点と一覧), amount (金額), photo (写真)."""
    t = THEMES[theme]
    w, h = 402, 874
    b = cal_header(t, w, "2026年11月", 2)
    if kind == "dots":
        b.append(month_dots(t, 16, 230, (w - 32) / 7, 59, t["bg"]))
        b.append(T(20, 546, "11月11日（水）・今日", 20, t["label"], 600))
        b.append(agenda(t, 16, 558, w - 32, t["cell"]))
    else:
        b.append(month_cells(t, 8, 228, (w - 16) / 7, 108, t["bg"], kind))
    b.append(tab_bar(w, h, t))
    return svg(w, h, t["bg"], "".join(b))


def mini(t, x, y, w, h, kind, bg):
    """Small schematic of a pattern for the picker (shapes only, no text)."""
    p = [R(x, y, w, h, 12, bg)]
    cw, rh = (w - 16) / 7, (h - 16) / 3
    for r in range(3):
        for c in range(7):
            cx, cy = x + 8 + cw * (c + .5), y + 8 + rh * r + 7
            p.append(f'<circle cx="{cx:g}" cy="{cy:g}" r="2" fill="{t["sec"]}" fill-opacity="0.5"/>')
            mark = (r * 7 + c) % 4
            yy = y + 8 + rh * r + 13
            if kind == "bars" and mark in (0, 1):
                p.append(R(x + 8 + cw * c + 1, yy, cw * (2 if mark == 0 and c < 6 else 1) - 2, 5, 2, list(t["cal"].values())[(r + c) % 3]))
            if kind == "dots" and mark != 2:
                p.append(f'<circle cx="{cx:g}" cy="{yy + 3:g}" r="2" fill="{list(t["cal"].values())[(r + c) % 3]}"/>')
            if kind == "amount" and mark in (0, 3):
                p.append(R(x + 8 + cw * c + 2, yy, cw - 4, rh - 18, 3, t["plus"] if mark == 0 else t["minus"], ' fill-opacity="0.55"'))
            if kind == "photo" and mark in (1, 3):
                p.append(R(x + 8 + cw * c + 2, yy, cw - 4, rh - 18, 3, t["ph"][(r + c) % 4]))
    return "".join(p)


def iphone_pattern_picker(theme):
    """S-05 設定 → カレンダーの表示: choose how the month looks."""
    t = THEMES[theme]
    w, h = 402, 874
    c = t["cell"]
    b = [status_bar(w, t), gbtn(t, 38, 84, "back", label="設定に戻る"), T(20, 148, "カレンダーの表示", 28, t["label"], 700),
         S(t, 20, 174, "月の画面の見え方を選べます。いつでも変えられます。", 15)]
    opts = [("bars", "帯（標準）", "予定の題名が見える", False, True), ("dots", "点と一覧", "月は小さく、下に一覧", False, False),
            ("amount", "金額", "その日の収支を大きく", True, False), ("photo", "写真", "記録の写真を並べる", True, False)]
    tw, th = (w - 48) / 2, 236
    for i, (kind, name, sub, pro, on) in enumerate(opts):
        x, y = 16 + (i % 2) * (tw + 16), 196 + (i // 2) * (th + 16)
        st = f' stroke="{t["accent"]}" stroke-width="2"' if on else ""
        b.append(R(x, y, tw, th, 24, c, st))
        b.append(mini(t, x + 12, y + 12, tw - 24, 132, kind, t["field"] if theme == "light" else "#2C2C2E"))
        b.append(T(x + 16, y + 172, name, 17, t["label"], 600, bg=c))
        b.append(S(t, x + 16, y + 194, sub, 13, bg=c))
        if on:
            b.append(f'<g aria-label="選択中"><circle cx="{x + tw - 26}" cy="{y + 212}" r="11" fill="{t["accent"]}"/>'
                     + ico("check", x + tw - 26, y + 212, "#FFFFFF", 2.4, .6) + "</g>")
        else:
            b.append(f'<circle cx="{x + tw - 26}" cy="{y + 212}" r="10" fill="none" stroke="{t["sec"]}" stroke-opacity="0.6" stroke-width="1.5"/>')
        if pro:
            b.append(R(x + 16, y + 202, 40, 20, 10, t["accent"]))
            b.append(T(x + 36, y + 216, "Pro", 12, "#FFFFFF", 700, "middle", bg=t["accent"]))
    b.append(S(t, 20, 722, "「日」「週」の画面は、どのパターンでも同じです。", 13))
    b.append(tab_bar(w, h, t, active=3))
    return svg(w, h, t["bg"], "".join(b))


# ---------- look themes (設定 → 見た目) ----------
# Each look has its own light and dark values (the app still follows the system appearance).
LOOKS = {
    "stylish": {
        "light": dict(bg="#F4F5F7", cell="#FFFFFF", accent="#1F2A44", accent_text="#1F2A44", glass="#FFFFFF",
                      field="#ECEEF2", red="#B3261E", bar_rx=2,
                      cal={"仕事": "#3D5A80", "プライベート": "#5B8E7D", "家族": "#B08968"}),
        "dark": dict(bg="#0B1020", cell="#151B2E", sheet="#151B2E", field="#1E2640", accent="#4C7DF0",
                     accent_text="#9DB8FF", glass="#1E2640", glass_stroke="#2F3A5C", sep="#2A3352", red="#FF8A80", bar_rx=2,
                     cal={"仕事": "#6C9BFF", "プライベート": "#5FD0A5", "家族": "#E8B36B"}),
    },
    "cute": {
        "light": dict(bg="#FFF6F3", cell="#FFFFFF", accent="#E8588A", accent_text="#B4235A", glass="#FFFFFF",
                      field="#FBE9E4", glass_stroke="#F3D5CD", sep="#EBCFC8", bar_rx=9,
                      cal={"仕事": "#5BA8E6", "プライベート": "#F08CB0", "家族": "#F2B34A"}),
        "dark": dict(bg="#201418", cell="#2C1C22", sheet="#2C1C22", field="#3A262E", accent="#E8588A",
                     accent_text="#FF9CBD", glass="#3A262E", glass_stroke="#55404A", sep="#4A353D", bar_rx=9,
                     cal={"仕事": "#6CB6F0", "プライベート": "#FF9CBD", "家族": "#F5C063"}),
    },
}
ROUNDED = "'SF Pro Rounded', 'Hiragino Maru Gothic ProN', 'Noto Sans JP', 'Noto Sans CJK JP', sans-serif"


def with_look(look, theme, fn):
    """Render fn() with a look applied on top of the standard light/dark values."""
    global FONT
    saved, saved_font = dict(THEMES[theme]), FONT
    THEMES[theme].update(LOOKS[look][theme])
    if look == "cute":
        FONT = ROUNDED     # rounded system font (the PNG preview falls back to the regular face)
    try:
        return fn()
    finally:
        THEMES[theme].clear()
        THEMES[theme].update(saved)
        FONT = saved_font


def iphone_look_picker(theme):
    """S-05 設定 → 見た目: choose the look."""
    t = THEMES[theme]
    w, h = 402, 874
    c = t["cell"]
    b = [status_bar(w, t), gbtn(t, 38, 84, "back", label="設定に戻る"), T(20, 148, "見た目", 28, t["label"], 700),
         S(t, 20, 174, "色と形の雰囲気を選べます。", 15)]
    rows = [("標準", "iPhone の標準に合わせた見た目", None, True), ("スタイリッシュ", "落ち着いた色、角ばった形", "stylish", False),
            ("かわいい", "やわらかい色、丸い形と丸い文字", "cute", False)]
    for i, (name, sub, look, on) in enumerate(rows):
        y = 196 + i * 128
        st = f' stroke="{t["accent"]}" stroke-width="2"' if on else ""
        b.append(R(16, y, w - 32, 116, 24, c, st))
        vals = dict(THEMES[theme], **(LOOKS[look][theme] if look else {}))
        sw = [vals["bg"], vals["accent"]] + list(vals["cal"].values())
        b.append(R(32, y + 16, 150, 84, 14, vals["bg"], f' stroke="{t["sep"]}"'))
        rx = vals.get("bar_rx", 5)
        for k, col in enumerate(sw[2:]):
            b.append(R(44, y + 30 + k * 20, [96, 70, 120][k], 14, rx, mix(col, vals["bg"], 0.35)))
            b.append(R(44, y + 30 + k * 20, 3, 14, 1.5, col))
        b.append(f'<circle cx="160" cy="{y+82}" r="9" fill="{vals["accent"]}"/>')
        b.append(T(200, y + 44, name, 17, t["label"], 600, bg=c))
        b.append(S(t, 200, y + 66, sub[:13], 13, bg=c))
        b.append(S(t, 200, y + 84, sub[13:], 13, bg=c))
        if on:
            b.append(f'<g aria-label="選択中"><circle cx="{w-44}" cy="{y+40}" r="11" fill="{t["accent"]}"/>'
                     + ico("check", w - 44, y + 40, "#FFFFFF", 2.4, .6) + "</g>")
        else:
            b.append(f'<circle cx="{w-44}" cy="{y+40}" r="10" fill="none" stroke="{t["sec"]}" stroke-opacity="0.6" stroke-width="1.5"/>')
            b.append(R(w - 76, y + 80, 40, 20, 10, t["accent"]))
            b.append(T(w - 56, y + 94, "Pro", 12, "#FFFFFF", 700, "middle", bg=t["accent"]))
    b.append(S(t, 20, 600, "どの見た目も、iPhone のライト／ダークの設定に合わせて", 13))
    b.append(S(t, 20, 618, "明るい色と暗い色が切り替わります。", 13))
    b.append(tab_bar(w, h, t, active=3))
    return svg(w, h, t["bg"], "".join(b))


files = {}
for th in ("light", "dark"):
    files.update({
        f"iphone-S-01-{th}.svg": iphone_month(th),
        f"iphone-S-01-day-{th}.svg": iphone_month(th, "day"),
        f"iphone-S-02-{th}.svg": iphone_month(th, "event"),
        f"iphone-S-01-week-{th}.svg": iphone_week(th),
        f"iphone-S-01-dots-{th}.svg": iphone_pattern(th, "dots"),
        f"iphone-S-01-amount-{th}.svg": iphone_pattern(th, "amount"),
        f"iphone-S-01-photo-{th}.svg": iphone_pattern(th, "photo"),
        f"iphone-S-05-patterns-{th}.svg": iphone_pattern_picker(th),
        f"iphone-S-05-looks-{th}.svg": iphone_look_picker(th),
        f"iphone-S-01-look-stylish-{th}.svg": with_look("stylish", th, lambda: iphone_month(th)),
        f"iphone-S-01-look-cute-{th}.svg": with_look("cute", th, lambda: iphone_month(th)),
        f"iphone-S-01-day-look-stylish-{th}.svg": with_look("stylish", th, lambda: iphone_month(th, "day")),
        f"iphone-S-01-day-look-cute-{th}.svg": with_look("cute", th, lambda: iphone_month(th, "day")),
        f"iphone-S-01-dayview-{th}.svg": iphone_dayview(th),
        f"iphone-S-01-empty-{th}.svg": iphone_main(th, empty=True),
        f"iphone-S-01-ax5-{th}.svg": iphone_ax5(th),
        f"iphone-S-03-{th}.svg": iphone_capture(th, "result"),
        f"iphone-S-03-keyboard-{th}.svg": iphone_capture(th, "keyboard"),
        f"iphone-S-03-loading-{th}.svg": iphone_capture(th, "loading"),
        f"iphone-S-03-error-{th}.svg": iphone_capture(th, "error"),
        f"iphone-S-03-limit-{th}.svg": iphone_capture(th, "limit"),
        f"iphone-S-04-{th}.svg": iphone_slots(th),
        f"iphone-S-06-permission-{th}.svg": iphone_permission(th),
        f"iphone-S-07-{th}.svg": iphone_paywall(th),
        f"iphone-S-09-keyboard-{th}.svg": iphone_record_add(th),
        f"iphone-S-10-{th}.svg": iphone_records(th),
        f"iphone-S-10-empty-{th}.svg": iphone_records(th, "empty"),
        f"iphone-S-10-locked-{th}.svg": iphone_records(th, "locked"),
        f"iphone-S-11-{th}.svg": iphone_stats(th),
        f"iphone-S-12-{th}.svg": iphone_summary(th),
        f"iphone-S-13-{th}.svg": iphone_share(th),
        f"iphone-S-14-{th}.svg": iphone_bulk(th),
        f"iphone-duo-outer-S-01-{th}.svg": duo_outer(th),
        f"iphone-duo-inner-landscape-S-01-{th}.svg": duo_inner_landscape(th),
        f"iphone-duo-inner-landscape-S-01-folded-{th}.svg": duo_inner_landscape(th, True),
        f"ipad-landscape-S-01-{th}.svg": ipad(th),
        f"ipad-narrow-S-01-{th}.svg": ipad_narrow(th),
        f"mac-S-01-{th}.svg": mac(th),
    })
for name, content in files.items():
    (OUT / name).write_text(content, encoding="utf-8")
print(f"wrote {len(files)} SVGs to {OUT}")
