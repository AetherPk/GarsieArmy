import json, os, html, re
D = os.path.dirname(os.path.abspath(__file__))
e = html.escape

# Reuse the flows, modules, matrix and dependency map from the first document.
src = open(os.path.join(D, 'build.py'), encoding='utf-8').read()
ns = {"__file__": os.path.join(D, "build.py")}
exec(src[:src.index("page = open(")].replace("screens = json.load", "screens = [] or json.load"), ns)
FLOW_HTML, DEPS, MATRIX, MODULES = ns['flow_html'], ns['DEPS'], ns['matrix_html'], ns['mod_html']

cfg = json.load(open(os.path.join(D, 'screens2.json'), encoding='utf-8'))
meas = {m['id']: m for m in json.load(open(os.path.join(D, 'vrects.json'), encoding='utf-8'))}
screens = {s['id']: s for s in cfg['screens']}

# ---------------------------------------------------------------- layout
# Columns per lane; cards stack down a column. A card can ask to start no
# higher than another card (so its arrows stay short).
GRID = [   # (lane, title, [(card, column, row), ...])
  ("Leerder", "Leerder, ouer of alumnus", [("kalender",0,0), ("kaart",1,0), ("soek",1,1), ("qr",2,0), ("geleentheid",2,1),
                                            ("instellings-l",3,0), ("myprogram",3,1), ("volg",4,0)]),
  ("Admin", "Admins", [("kalender-a",0,0), ("bestuur",1,0), ("groep",2,0), ("volgers",2,1), ("skep",3,0), ("admingeleentheid",4,0),
                       ("nooi",5,0), ("qr-admin",5,1), ("excel",6,0), ("instellings",7,0), ("leerder-edit",8,0), ("preview",8,1)]),
]
SW, COLW, GAP, TITLE = 390, 820, 170, 64
LEG_LINE = 23

def legend_height(s):
    h = 30
    for c in s['calls']:
        txt = len(c[2]); trig = len(c[3])
        h += 28 + LEG_LINE * max(1, -(-txt // 40)) + (30 if trig else 0) + 10
    return h
def card_height(cid):
    if cid == "excel": return 640
    return TITLE + meas[cid]['h'] + 24 + legend_height(screens[cid])

cards, lane_tops = {}, []
y0 = 0
for lane, laneTitle, items in GRID:
    lane_tops.append((lane, laneTitle, y0))
    rows = sorted({r for _, _, r in items})
    ytop = y0 + 230
    for r in rows:
        inrow = [(cid, c) for cid, c, rr in items if rr == r]
        rh = max(card_height(cid) for cid, _ in inrow)
        for cid, c in inrow:
            h = card_height(cid)
            cards[cid] = dict(id=cid, x=c * COLW, y=ytop, w=(SW + 190 if cid == "excel" else SW), h=h, sh=h if cid == "excel" else meas[cid]['h'], col=c, row=r, lane=lane, laneTop=y0)
        ytop += rh + GAP
    y0 = ytop + 200
WORLD_W = max(c['x'] + c['w'] for c in cards.values()) + 200
WORLD_H = y0

# ---------------------------------------------------------------- cards
def screen_card(cid):
    c, s, m = cards[cid], screens[cid], meas[cid]
    marks = []
    for i, r in enumerate(m['rects'], 1):
        if not r: continue
        marks.append(f'<span class="hot" style="left:{r["x"]:.1f}px;top:{r["y"]:.1f}px;width:{r["w"]:.1f}px;height:{r["h"]:.1f}px"></span>'
                     f'<span class="num" style="left:{r["x"]:.1f}px;top:{r["y"]:.1f}px">{i}</span>')
    items = ''.join(f'<li><span class="n">{i}</span><div><b>{e(name)}</b><p>{e(does)}</p>' + (f'<span class="trig">→ {e(trig)}</span>' if trig else '') + '</div></li>'
                    for i, (_, name, does, trig) in enumerate(s['calls'], 1))
    return f'''<div class="card" id="c-{cid}" style="left:{c['x']}px;top:{c['y']}px;width:{SW}px">
  <div class="ctitle"><span>{e(s['lane'])}</span>{e(s['title'])}</div>
  <div class="phone" style="height:{m['h']}px"><img src="vec/{cid}.svg" width="{SW}" height="{m['h']}" alt="Skerm: {e(s['title'])}" decoding="async">{''.join(marks)}</div>
  <ol class="leg">{items}</ol>
</div>'''

EXCEL_ROWS = [
  ("Aangemeld (3)", None),
  (None, ["Naam", "Van", "Graad", "Vooraf bespreek", "Uitnodiging", "Aangemeld"]),
  (None, ["Johan", "du Plessis", "Graad 12", "Ja", "Aanvaar", "16 Okt 18:02 · QR"]),
  (None, ["Ruan", "Venter", "Graad 11", "Ja", "Aanvaar", "16 Okt 18:05 · GPS (40 m)"]),
  (None, ["Pieter", "Botha", "Graad 11", "Nee", "", "16 Okt 18:11 · QR"]),
  ("Bespreek, maar nie aangemeld nie (1)", None),
  (None, ["Lize", "Kruger", "Graad 10", "Ja", "", ""]),
  ("Genooi, maar nie bespreek nie (2)", None),
  (None, ["Thabo", "Mokoena", "Graad 11", "Nee", "Geweier", ""]),
  (None, ["Anri", "Smit", "Graad 11", "Nee", "Geen antwoord", ""]),
  ("Verdagte aanmeldings — gaan asseblief na", None),
  (None, ["Kobus", "Nel", "Graad 9", "Nee", "", "QR-kode ouer as 'n minuut"]),
]
def excel_card():
    c = cards["excel"]
    rows = ''.join(f'<tr class="sec"><td colspan="6">{e(t)}</td></tr>' if t else
                   ('<tr class="hd">' if r[0] == "Naam" else '<tr>') + ''.join(f'<td>{e(x)}</td>' for x in r) + '</tr>' for t, r in EXCEL_ROWS)
    return f'''<div class="card excel" id="c-excel" style="left:{c['x']}px;top:{c['y']}px;width:{c['w']}px">
  <div class="ctitle"><span>Admin</span>Excel-bywoning (voorbeeld)</div>
  <div class="sheet"><div class="sbar">Bywoning - Spanete - 2026-10-16.xlsx</div>
    <div class="stitle">Spanete: Eerste span</div><div class="ssum">Bespreek: 3 · Aangemeld: 3 (waarvan 2 vooraf bespreek het) · Genooi: 4 (2 aanvaar, 1 geweier) · Verdag: 1</div>
    <table>{rows}</table></div>
  <p class="note">Die admin laai dit af met die Excel-knoppie. Dit maak oop in Excel, Google Sheets en Numbers.</p>
</div>'''

def anchor_out(cid, r):
    c = cards[cid]
    return (c['x'] + r['x'] + r['w'] / 2, c['y'] + TITLE + r['y'] + r['h'] / 2)

arrows, rings, labels = [], [], []
for cid, s in screens.items():
    for (sel, target, label), r in zip(s['links'], meas[cid]['links']):
        if not r or target not in cards: continue
        sx, sy = anchor_out(cid, r)
        t, src = cards[target], cards[cid]
        dc = t['col'] - src['col']
        if dc >= 2:                      # long way: arc over the top of the lane
            ex, ey = t['x'] - 16, t['y'] + TITLE + 120
            top = src['laneTop'] + 110
            c1, c2 = (sx + 120, top), (ex - 320, top)
        elif dc == 1:
            ex, ey = t['x'] - 16, t['y'] + TITLE + 120
            c1, c2 = (sx + 330, sy), (ex - 260, ey)
        elif dc < 0:
            ex, ey = t['x'] + t['w'] + 16, t['y'] + TITLE + 160
            c1, c2 = (sx - 330, sy), (ex + 260, ey)
        else:
            ex, ey = t['x'] + t['w'] / 2, t['y'] - 16
            c1, c2 = (sx, sy + 200), (ex, ey - 200)
        P = lambda t: [(1-t)**3*a + 3*(1-t)**2*t*b + 3*(1-t)*t*t*c + t**3*d for a, b, c, d in zip((sx, sy), c1, c2, (ex, ey))]
        lx, ly = P(.55)
        arrows.append(f'<path d="M{sx:.0f} {sy:.0f}C{c1[0]:.0f} {c1[1]:.0f} {c2[0]:.0f} {c2[1]:.0f} {ex:.0f} {ey:.0f}" marker-end="url(#head)"/>')
        rings.append(f'<circle cx="{sx:.0f}" cy="{sy:.0f}" r="13"/>')
        labels.append(f'<text x="{lx:.0f}" y="{ly - 12:.0f}" text-anchor="middle">{e(label)}</text>')

lanes_html = ''.join(f'<div class="lane" style="top:{y}px;width:{WORLD_W - 100}px"><b>{e(t)}</b><span>{"Wat gebruikers sien" if n == "Leerder" else "Net vir departement- en Hoof-admins"}</span></div>' for n, t, y in lane_tops)
svgopen = f'<svg class="arrows" width="{WORLD_W}" height="{WORLD_H}" viewBox="0 0 {WORLD_W} {WORLD_H}">'
world = (f'<div id="world" style="width:{WORLD_W}px;height:{WORLD_H}px">{lanes_html}'
         + svgopen + '<defs><marker id="head" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="5" markerHeight="5" orient="auto-start-reverse"><path d="M0 0L10 5L0 10Z" fill="#e0b64f"/></marker></defs><g class="arrow">' + "".join(arrows) + '</g></svg>'
         + ''.join(screen_card(c) if c != "excel" else excel_card() for c in cards)
         + svgopen + '<g class="arrow top">' + "".join(rings) + "".join(labels) + '</g></svg></div>')
jump = ''.join(f'<option value="{cid}">{e(cfg["excel"]["title"] if cid == "excel" else screens[cid]["title"])}</option>' for cid in cards)

import sys
sys.path.insert(0, D)
from whodo import WHO_HTML
from procbuild import PROCLIST, PROCTEMPLATES

page = open(os.path.join(D, 'template2.html'), encoding='utf-8').read()
for k, v in {"{{WORLD}}": world, "{{PROCLIST}}": PROCLIST, "{{PROCTEMPLATES}}": PROCTEMPLATES, "{{JUMP}}": jump, "{{WHO}}": WHO_HTML, "{{FLOWS}}": FLOW_HTML, "{{DEPS}}": DEPS,
             "{{MATRIX}}": MATRIX, "{{MODULES}}": MODULES, "{{WW}}": str(WORLD_W), "{{WH}}": str(WORLD_H)}.items():
    page = page.replace(k, v)
crest = open(os.path.join(D, '..', '..', 'icons', 'crest-reference.svg')).read()   # the traced official crest
inner = crest[crest.index('<defs>'):crest.rindex('</svg>')].replace('id="sh"', 'id="dsh"').replace('url(#sh)', 'url(#dsh)').replace('id="arc"', 'id="darc"').replace('href="#arc"', 'href="#darc"')
page = page.replace("{{CREST}}", f'<svg class="crest" viewBox="0 8 211 222" role="img" aria-label="Wapen van Hoërskool Garsfontein">{inner}</svg>')
open(os.path.join(D, 'garsie-vloeikaart.html'), 'w', encoding='utf-8').write(page)
print("built", len(page) // 1024, "KB; world", WORLD_W, "x", WORLD_H, "; arrows", len(arrows))
