#!/usr/bin/env python3
"""Mocks for the Google Calendar connection (S-16 / S-17 / S-18). Fictional account and calendars only.
Uses the parts in design/build.py (importing it also rewrites the other mocks, unchanged).
Run: python3 design/google_mocks.py
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build as B  # noqa: E402

W, H = 402, 874
ACCOUNT = "mame.sorano@example.com"          # fictional
GCALS = [("mame.sorano@example.com", "#039BE5", True), ("ライブとイベント", "#D50000", True),
         ("家族の予定", "#33B679", True), ("日本の祝日", "#0B8043", False)]   # Google's own palette values (approx.)


def row_group(t, y, rows, c):
    """rows: list of callables(cy) -> svg. Returns (svg, next_y)."""
    p = [B.R(16, y, W - 32, 52 * len(rows), 24, c)]
    for i, fn in enumerate(rows):
        cy = y + 26 + i * 52
        if i:
            p.append(f'<line x1="56" y1="{cy-26}" x2="{W-16}" y2="{cy-26}" stroke="{t["sep"]}" stroke-width="0.5"/>')
        p.append(fn(cy))
    return "".join(p), y + 52 * len(rows)


def g_mark(cx, cy, r=12):
    """Neutral stand-in for an account symbol (not Google's logo)."""
    return (f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="#E8EAED"/>'
            f'<circle cx="{cx}" cy="{cy-3}" r="{r*0.33}" fill="#5F6368"/>'
            f'<path d="M{cx-r*0.6} {cy+r*0.62}a{r*0.6} {r*0.5} 0 0 1 {r*1.2} 0" fill="#5F6368"/>')


def accounts(theme, state="ok"):
    """S-16 設定 → カレンダーのアカウント."""
    t = B.THEMES[theme]
    c = t["cell"]
    b = [B.status_bar(W, t), B.gbtn(t, 38, 84, "back", label="設定に戻る"),
         B.T(20, 148, "カレンダーのアカウント", 28, t["label"], 700),
         B.S(t, 20, 174, "予定を読み込むカレンダーを選びます。", 15)]
    y = 196
    b.append(B.S(t, 32, y + 16, "この iPhone", 13))
    y += 26
    g, y = row_group(t, y, [lambda cy: B.ico("cal", 46, cy, t["accent"]) + B.T(70, cy + 6, "iPhone のカレンダー", 17, t["label"], bg=c)
                            + B.S(t, W - 56, cy + 5, "5 件", 15, "end", bg=c) + B.chevron(W - 44, cy, t["sec"])], c)
    b.append(g)
    b.append(B.S(t, 32, y + 22, "iCloud や、設定アプリで追加したアカウントのカレンダー", 13))
    y += 46
    b.append(B.S(t, 32, y + 16, "Google", 13))
    y += 26
    rows = []
    if state != "empty":
        def acct(cy):
            p = g_mark(46, cy) + B.T(70, cy - 2, ACCOUNT, 17, t["label"], bg=c)
            if state == "expired":
                p += B.T(70, cy + 17, "ログインし直してください", 13, t["red"], bg=c)
                p += B.ico("warn", W - 70, cy, t["red"], 1.8)
            else:
                p += B.S(t, 70, cy + 17, "カレンダー 4 件を表示中", 13, bg=c)
            return p + B.chevron(W - 44, cy, t["sec"])
        rows.append(acct)
    rows.append(lambda cy: B.ico("plus", 46, cy, t["accent_text"]) + B.T(70, cy + 6, "Google アカウントを追加", 17, t["accent_text"], bg=c))
    g, y = row_group(t, y, rows, c)
    b.append(g)
    notes = ["Google カレンダーと直接つなぐと、予定ごとの色も", "そのまま表示できます。予定はこの iPhone と Google の",
             "あいだだけでやりとりし、開発者には送りません。"]
    if state == "expired":
        notes = ["しばらく使わなかったか、Google 側でアクセスを", "取り消したため、予定を読み込めません。押して", "ログインし直すと、元どおりに表示されます。"]
    for i, line in enumerate(notes):
        b.append(B.S(t, 32, y + 22 + i * 18, line, 13))
    b.append(B.tab_bar(W, H, t, active=3))
    return B.svg(W, H, t["bg"], "".join(b))


def connect_intro(theme):
    """S-17 Google につなぐ前の説明 (one button, no close: HIG Privacy)."""
    t = B.THEMES[theme]
    b = [B.status_bar(W, t), B.gbtn(t, 38, 84, "back", label="戻る"), B.ico("cal", W / 2, 236, t["accent"], 2, 3.2)]
    b.append(B.T(W / 2, 336, "Google カレンダーと", 28, t["label"], 700, "middle"))
    b.append(B.T(W / 2, 372, "つなぎます", 28, t["label"], 700, "middle"))
    items = [("見るもの", "カレンダーの一覧、予定、予定ごとの色"),
             ("変えるもの", "このアプリで追加・変更・削除した予定だけ"),
             ("送り先", "この iPhone と Google のあいだだけ。\n開発者には送りません"),
             ("やめるとき", "いつでも「接続を解除」できます")]
    y = 420
    for k, v in items:
        b.append(B.T(40, y, k, 15, t["label"], 600))
        for j, line in enumerate(v.split("\n")):
            b.append(B.S(t, 40, y + 22 + j * 20, line, 15))
        y += 62 + 20 * v.count("\n")
    b.append(B.S(t, W / 2, H - 162, "次の画面で Google にログインし、許可を選びます。", 13, "middle"))
    b.append(B.R(20, H - 130, W - 40, 54, 27, t["accent"]))
    b.append(B.T(W / 2, H - 96, "続ける", 17, "#FFFFFF", 600, "middle", bg=t["accent"]))
    b.append(B.home_ind(W, H, t))
    return B.svg(W, H, t["bg"], "".join(b))


def account_detail(theme, confirm=False):
    """S-18 Google アカウント: which calendars to show, colors, disconnect."""
    t = B.THEMES[theme]
    c = t["cell"]
    b = [B.status_bar(W, t), B.gbtn(t, 38, 84, "back", label="アカウントに戻る"),
         B.T(20, 148, "Google", 28, t["label"], 700), B.S(t, 20, 174, ACCOUNT, 15)]
    y = 196
    b.append(B.S(t, 32, y + 16, "表示するカレンダー", 13))
    y += 26
    rows = []
    for name, col, on in GCALS:
        rows.append(lambda cy, name=name, col=col, on=on: f'<circle cx="46" cy="{cy}" r="10" fill="{col}"/>'
                    + B.T(70, cy + 6, name if len(name) < 20 else name[:18] + "…", 17, t["label"], bg=c) + B.switch(t, W - 84, cy - 15, on))
    g, y = row_group(t, y, rows, c)
    b.append(g)
    y += 22
    b.append(B.S(t, 32, y + 16, "色", 13))
    y += 26
    g, y = row_group(t, y, [lambda cy: B.T(36, cy + 6, "予定ごとの Google の色を使う", 17, t["label"], bg=c) + B.switch(t, W - 84, cy - 15, True)], c)
    b.append(g)
    b.append(B.S(t, 32, y + 22, "オフにすると、カレンダーごとの色で表示します。", 13))
    y += 50
    g, y = row_group(t, y, [lambda cy: B.T(36, cy + 6, "最後に読み込んだ時刻", 17, t["label"], bg=c) + B.S(t, W - 36, cy + 5, "9:38", 15, "end", bg=c),
                            lambda cy: B.T(W / 2, cy + 6, "接続を解除", 17, t["red"], 400, "middle", bg=c)], c)
    b.append(g)
    b.append(B.S(t, 32, y + 22, "設定アプリにも同じアカウントがあるときは、二重に", 13))
    b.append(B.S(t, 32, y + 40, "表示しないように、そちらのカレンダーを隠します。", 13))
    b.append(B.tab_bar(W, H, t, active=3))
    if confirm:
        b.append(B.R(0, 0, W, H, 0, "#000000", f' fill-opacity="{0.25 if theme == "light" else 0.5}"'))
        ax, aw, ay = 41, 320, 300
        sh = t["sheet"]
        b.append(B.R(ax, ay, aw, 214, 32, sh))
        b.append(B.T(W / 2, ay + 44, "接続を解除しますか？", 17, t["label"], 600, "middle", bg=sh))
        for i, line in enumerate(["このアプリから Google の予定が", "見えなくなります。Google カレンダーの", "予定は消えません。"]):
            b.append(B.T(W / 2, ay + 74 + i * 20, line, 13, t["label"], 400, "middle", bg=sh))
        b.append(B.R(ax + 16, ay + 144, (aw - 44) / 2, 50, 25, t["field"]))
        b.append(B.T(ax + 16 + (aw - 44) / 4, ay + 175, "キャンセル", 17, t["label"], 400, "middle", bg=t["field"]))
        b.append(B.R(ax + 28 + (aw - 44) / 2, ay + 144, (aw - 44) / 2, 50, 25, t["field"]))
        b.append(B.T(ax + 28 + 3 * (aw - 44) / 4, ay + 175, "解除", 17, t["red"], 600, "middle", bg=t["field"]))
    return B.svg(W, H, t["bg"], "".join(b))


files = {}
for th in ("light", "dark"):
    files.update({
        f"iphone-S-16-{th}.svg": accounts(th),
        f"iphone-S-16-empty-{th}.svg": accounts(th, "empty"),
        f"iphone-S-16-expired-{th}.svg": accounts(th, "expired"),
        f"iphone-S-17-{th}.svg": connect_intro(th),
        f"iphone-S-18-{th}.svg": account_detail(th),
        f"iphone-S-18-disconnect-{th}.svg": account_detail(th, True),
    })
for name, content in files.items():
    (B.OUT / name).write_text(content, encoding="utf-8")
print(f"wrote {len(files)} Google SVGs")
