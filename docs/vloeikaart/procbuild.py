# Builds the process list (cards) and one <template> per process with its
# small zoomable diagram: real screens (vector), marked buttons, boxes, arrows.
import json, os, html, math
D = os.path.dirname(os.path.abspath(__file__))
e = html.escape
data = json.load(open(os.path.join(D, 'procs.json'), encoding='utf-8'))
rects = {r['id']: r for r in json.load(open(os.path.join(D, 'prects.json'), encoding='utf-8'))}
KIND = {"db": "Bediener", "push": "Kennisgewing (push)", "inbox": "Inbox", "ext": "Buite die app", "phone": "Op die foon",
        "ok": "Uitslag", "admin": "Admin", "bad": "Geweier", "q": "Besluit"}
PCOL, SW, BW, CAP = 600, 390, 340, 56

def node_size(n):
    if n['kind'] == 'screen':
        h = rects[n['shot']]['h']
        leg = 16 + sum(30 + 22 * math.ceil(len(lbl) / 38) for _, lbl in n['marks']) if n['marks'] else 0
        return SW, CAP + h + leg
    lines = math.ceil(len(n['title']) / 22) * 1.3 + (math.ceil(len(n['text']) / 30) if n['text'] else 0)
    return BW, 90 + 28 * lines

def build(p):
    nodes = {n['n']: dict(n) for n in p['nodes']}
    rows = sorted({n['row'] for n in nodes.values()})
    tops, y = {}, 40
    for r in rows:
        tops[r] = y
        y += max(node_size(n)[1] + (150 if n['kind'] != 'screen' else 0) for n in nodes.values() if n['row'] == r) + 140
    H = y
    W = max(n['col'] for n in nodes.values()) * PCOL + SW + 120
    parts, arrows, rings, labels = [], [], [], []
    for i, n in enumerate(p['nodes']):
        nd = nodes[n['n']]
        w, h = node_size(nd)
        nd['x'] = 60 + nd['col'] * PCOL + (SW - w) / 2 if nd['kind'] != 'screen' else 60 + nd['col'] * PCOL
        nd['y'] = tops[nd['row']] + (CAP + 150 if nd['kind'] != 'screen' else 0)
        nd['w'], nd['h'] = w, h
        step = f'<em>{i + 1}</em>'
        if nd['kind'] == 'screen':
            r = rects[nd['shot']]
            marks, legs = [], []
            for j, (sel, lbl) in enumerate(nd['marks'], 1):
                rr = r['rects'].get(sel)
                if rr:
                    marks.append(f'<span class="hot" style="left:{rr["x"]:.1f}px;top:{rr["y"]:.1f}px;width:{rr["w"]:.1f}px;height:{rr["h"]:.1f}px"></span>'
                                 f'<span class="num" style="left:{rr["x"]:.1f}px;top:{rr["y"]:.1f}px">{j}</span>')
                legs.append(f'<li><span class="n">{j}</span><div><b>{e(lbl)}</b></div></li>')
            parts.append(f'<div class="pnode" style="left:{nd["x"]:.0f}px;top:{nd["y"]:.0f}px;width:{SW}px"><div class="pcap">{step}{e(nd["cap"])}</div>'
                         f'<div class="phone" style="height:{r["h"]}px"><img src="vec/{nd["shot"]}.svg" width="{SW}" height="{r["h"]}" alt="{e(nd["cap"])}">{"".join(marks)}</div>'
                         + (f'<ol class="leg">{"".join(legs)}</ol>' if legs else '') + '</div>')
        else:
            parts.append(f'<div class="pnode" style="left:{nd["x"]:.0f}px;top:{nd["y"]:.0f}px"><div class="pbox k-{nd["kind"]}"><div class="kind">{step} {e(KIND.get(nd["kind"], ""))}</div>'
                         f'<b>{e(nd["title"])}</b>' + (f'<p>{e(nd["text"])}</p>' if nd["text"] else '') + '</div></div>')
    def box_of(nd):
        if nd['kind'] == 'screen':
            return nd['x'], nd['y'] + CAP, SW, rects[nd['shot']]['h']
        return nd['x'], nd['y'], nd['w'], nd['h']
    for a, mark, b, label in p['edges']:
        s, t = nodes[a], nodes[b]
        sx0, sy0, sw0, sh0 = box_of(s); tx0, ty0, tw0, th0 = box_of(t)
        start = None
        if mark is not None and (s['kind'] != 'screen' or mark >= len(s['marks'])): mark = None
        if mark is not None and s['kind'] == 'screen':
            sel = s['marks'][mark][0]; rr = rects[s['shot']]['rects'].get(sel)
            if rr: start = (sx0 + rr['x'] + rr['w'] / 2, sy0 + rr['y'] + rr['h'] / 2)
        dc, dr = t['col'] - s['col'], t['row'] - s['row']
        if dc > 0:
            if not start: start = (sx0 + sw0 + 6, sy0 + min(sh0 / 2, 220))
            end = (tx0 - 14, ty0 + min(th0 / 2, 220))
            c1, c2 = (start[0] + 200, start[1]), (end[0] - 200, end[1])
        elif dc < 0:
            if not start: start = (sx0 - 6, sy0 + min(sh0 / 2, 220))
            end = (tx0 + tw0 + 14, ty0 + min(th0 / 2, 220))
            c1, c2 = (start[0] - 200, start[1]), (end[0] + 200, end[1])
        else:
            if not start: start = (sx0 + sw0 / 2, sy0 + sh0 + 6)
            end = (tx0 + tw0 / 2, ty0 - 14)
            c1, c2 = (start[0], start[1] + 160), (end[0], end[1] - 160)
        P = lambda u: [(1 - u) ** 3 * q0 + 3 * (1 - u) ** 2 * u * q1 + 3 * (1 - u) * u * u * q2 + u ** 3 * q3 for q0, q1, q2, q3 in zip(start, c1, c2, end)]
        lx, ly = P(.5)
        arrows.append(f'<path d="M{start[0]:.0f} {start[1]:.0f}C{c1[0]:.0f} {c1[1]:.0f} {c2[0]:.0f} {c2[1]:.0f} {end[0]:.0f} {end[1]:.0f}" marker-end="url(#phead-{p["id"]})"/>')
        if mark is not None: rings.append(f'<circle cx="{start[0]:.0f}" cy="{start[1]:.0f}" r="13"/>')
        if label: labels.append(f'<text x="{lx:.0f}" y="{ly - 12:.0f}" text-anchor="middle">{e(label)}</text>')
    svg = f'<svg class="arrows" width="{W}" height="{H}" viewBox="0 0 {W} {H}">'
    world = (svg + f'<defs><marker id="phead-{p["id"]}" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="5" markerHeight="5" orient="auto-start-reverse"><path d="M0 0L10 5L0 10Z" fill="#e0b64f"/></marker></defs><g class="arrow">'
             + ''.join(arrows) + '</g></svg>' + ''.join(parts) + svg + '<g class="arrow top">' + ''.join(rings) + ''.join(labels) + '</g></svg>')
    tpl = (f'<template id="pt-{p["id"]}" data-w="{W}" data-h="{H}" data-title="{e(p["title"])}" data-who="{e(p["who"])}" data-sum="{e(p["summary"])}">'
           + world + '</template>')
    card = (f'<button type="button" class="proc" data-proc="{p["id"]}"><span class="who">{e(p["who"])}</span><b>{e(p["title"])}</b>'
            f'<p>{e(p["summary"])}</p><span class="steps">{len(p["nodes"])} stappe · tik om oop te maak</span></button>')
    return card, tpl

built = [build(p) for p in data['procs']]
PROCLIST = ''.join(c for c, _ in built)
PROCTEMPLATES = ''.join(t for _, t in built)
