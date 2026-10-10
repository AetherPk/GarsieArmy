import json, os, html
D = os.path.dirname(os.path.abspath(__file__))
screens = json.load(open(os.path.join(D, 'screens.json'), encoding='utf-8'))
_rp = os.path.join(D, 'rects.json')   # only the old screenshot cards used these; the new document doesn't
rects = {r['id']: r for r in json.load(open(_rp, encoding='utf-8'))} if os.path.exists(_rp) else {}
e = html.escape

def screen_card(s):
    r = rects[s['id']]
    marks, items = [], []
    for i, (call, rect) in enumerate(zip(s['calls'], r['rects']), 1):
        _, name, does, trig = call
        if rect:
            L, T = rect['x'] / r['w'] * 100, rect['y'] / r['h'] * 100
            Wd, Ht = rect['w'] / r['w'] * 100, rect['h'] / r['h'] * 100
            marks.append(f'<span class="hot" style="left:{L:.2f}%;top:{T:.2f}%;width:{Wd:.2f}%;height:{Ht:.2f}%"></span>'
                         f'<span class="num" style="left:{L:.2f}%;top:{T:.2f}%">{i}</span>')
        items.append(f'<li><span class="n">{i}</span><div><b>{e(name)}</b><p>{e(does)}</p>'
                     + (f'<span class="trig">→ {e(trig)}</span>' if trig else '') + '</div></li>')
    return f'''<article class="screen" id="s-{s['id']}">
  <figure class="shot" style="aspect-ratio:{r['w']}/{r['h']}"><img src="img/{s['id']}.jpg" alt="Skermskoot: {e(s['title'])}" loading="lazy">{''.join(marks)}</figure>
  <div class="legend"><div class="eyebrow">{e(s['group'])}</div><h3>{e(s['title'])}</h3><ol>{''.join(items)}</ol></div>
</article>'''

groups = [("Leerder", "Wat 'n leerder (of ouer, of alumnus) sien"), ("Almal", "Vir almal"), ("Admin", "Net vir admins")]
screen_html = ''
for g, sub in groups:
    cards = ''.join(screen_card(s) for s in screens if s['group'] == g and s['id'] in rects)
    screen_html += f'<h3 class="band">{e(sub)}</h3><div class="screens">{cards}</div>'

MER = """%%{init: {'theme':'base','themeVariables':{'background':'#011628','primaryColor':'#0a3050','primaryTextColor':'#f3f6f9','primaryBorderColor':'#2d5a7d','lineColor':'#5ab7d6','secondaryColor':'#0a3050','tertiaryColor':'#011628','fontFamily':'Lora, Georgia, serif','fontSize':'15px','edgeLabelBackground':'#011628'},'flowchart':{'curve':'basis','padding':12}}}%%"""
CLS = """
classDef tap fill:#1d84ab,stroke:#5ab7d6,color:#ffffff
classDef db fill:#2a2350,stroke:#9b7fd4,color:#f3f6f9
classDef push fill:#3a2f10,stroke:#e0b64f,color:#fff3d1
classDef inbox fill:#3b1720,stroke:#ff8a80,color:#ffe1dd
classDef screen fill:#0a3050,stroke:#5ab7d6,color:#f3f6f9
classDef admin fill:#123826,stroke:#3fae7a,color:#dff5e9
classDef phone fill:#1b2b38,stroke:#9db3c6,color:#f3f6f9
classDef q fill:#011628,stroke:#9db3c6,color:#f3f6f9
classDef bad fill:#2a1416,stroke:#ff8a80,color:#ffb4ab
classDef ok fill:#123826,stroke:#5fd18a,color:#dff5e9
classDef warn fill:#3a2f10,stroke:#f2b354,color:#ffe4b5
"""
def mer(body):
    return f'<pre class="mermaid">{MER}\n{body.strip()}\n{CLS}</pre>'

FLOWS = [
 ("bespreek", "Bespreek", "Een tik op <b>Bespreek</b> en wat daarna outomaties gebeur.", """
flowchart LR
  A([Tik Bespreek]):::tap --> B[Bespreking gestoor]:::db
  B --> C{Was jy genooi?}:::q
  C -- Ja --> D[Uitnodiging word Aanvaar]:::db
  B --> E[Verskyn in My program]:::screen
  B --> F[Admin: telling en Excel]:::admin
  B --> G[[1 uur voor: herinnering]]:::push
  H([Admin wysig tyd, plek of naam]):::tap --> I[[Verandering]]:::push
  K([Admin skrap]):::tap --> L[[Gekanselleer]]:::push
  I --> J[Inbox]:::inbox
  L --> J
"""),
 ("aanmeld", "Aanmeld: Kaart en QR", "Aanmelding tel net binne die sirkel (plus die GPS se speling, tot 100 m). Die foon kyk eerste, die bediener kyk weer.", """
flowchart TD
  A([Meld aan op Kaart]):::tap --> C{Ligging bekend?}:::q
  B([Skandeer QR]):::tap --> B2{Geldige QR?}:::q
  B2 -- Nee --> X[Geweier]:::bad
  B2 -- Ja --> C
  C -- Nee --> X
  C -- Ja --> D{Binne die sirkel?}:::q
  D -- Nee --> X
  D -- Ja --> E{Internet?}:::q
  E -- Nee --> F[Op die foon gestoor, later gestuur]:::phone
  F --> G
  E -- Ja --> G[Bediener kyk alles weer]:::db
  G --> H{QR ouer as 1 minuut?}:::q
  H -- Ja --> I[Gestoor as verdag]:::warn
  H -- Nee --> J[Aangemeld]:::ok
  J --> K[Excel: Aangemeld]:::admin
  I --> L[Excel: Verdagte aanmeldings]:::admin
"""),
 ("nuut", "Nuwe geleentheid en wie dit hoor", "Die admin kies wie die kennisgewing kry. Net wie die geleentheid mag sien, kry dit.", """
flowchart LR
  A([Skep geleentheid]):::tap --> B[Geleentheid gestoor]:::db
  B --> C[Wie kry 'n kennisgewing?]:::screen
  C --> D1[Volgers van die afdeling]:::screen
  C --> D2[Lede van die subafdeling]:::screen
  C --> D3[Ekstra: grade, groepe, e-posse]:::screen
  D1 --> E{Mag hulle dit sien?}:::q
  D2 --> E
  D3 --> E
  E -- Ja --> F[Inbox: Nuwe geleentheid]:::inbox
  E -- Ja --> G[[Push, as kennisgewings aan is]]:::push
  E -- Nee --> Z[Kry niks]:::bad
"""),
 ("nooi", "Nooi, aanvaar of weier", "'n Uitnodiging gee altyd toegang, ook tot 'n geleentheid wat net op uitnodiging is.", """
flowchart LR
  A([Nooi]):::tap --> B[Kies grade, groepe, e-posse]:::screen
  B --> C[Uitnodigings gestoor]:::db
  C --> D[[Push: Uitnodiging]]:::push
  C --> E[Inbox: wag vir antwoord]:::inbox
  C --> V[Leerder sien die geleentheid]:::screen
  E --> F([Aanvaar]):::tap
  E --> H([Weier]):::tap
  F --> G[Bespreek]:::ok
  H --> I[Bespreking weg]:::bad
  G --> J[Excel: kolom Uitnodiging]:::admin
  I --> J
"""),
 ("groepe", "Groepe en volg", "Afdelings volg almal by verstek. Subafdelings is oop (self aansluit) of privaat (net admins).", """
flowchart LR
  A([Admin: soek iemand of plak e-posse]):::tap --> B[Lid van groep]:::db
  E([Leerder: volg oop groep]):::tap --> B
  A --> C[Inbox: Jy is bygevoeg]:::inbox
  A --> D[[Push]]:::push
  B --> H[Hoor van die groep se geleenthede]:::screen
  F([Leerder: skakel afdeling af]):::tap --> G[Volg nie meer nie]:::db
  G --> I[Geen Nuwe geleentheid van daardie afdeling]:::bad
"""),
 ("aankoms", "Aankoms by 'n geleentheid", "Terwyl die app oop is en ligging toegelaat is, van 'n uur voor die begin tot die einde. 'n Webapp kan nie in die agtergrond volg nie.", """
flowchart LR
  A[App oop, ligging toegelaat]:::phone --> B{Geleentheid nou?}:::q
  B -- Ja --> C{Binne die sirkel?}:::q
  C -- Ja --> D{Al aangemeld?}:::q
  D -- Nee --> E[[Jy mag nou aanmeld]]:::push
  E --> F([Tik op kennisgewing]):::tap
  F --> G[Kaart by die geleentheid]:::screen
"""),
]
flow_html = ''.join(f'''<article class="flow" id="f-{fid}"><h3>{title}</h3><p>{intro}</p><div class="diagram">{mer(body)}</div></article>''' for fid, title, intro, body in FLOWS)

NAV = mer("""
flowchart LR
  T{{Oortjies}}:::q
  T --> K[Kalender]:::screen
  T --> M[Kaart]:::screen
  T --> S[Soek]:::screen
  T --> P[My program + Inbox]:::screen
  T -. admin .-> B[Bestuur]:::admin
  T -. admin .-> SK[Skep]:::admin
  K --> G[Geleentheid]:::screen
  S --> G
  P --> G
  G --> M
  G -. admin .-> N[Nooi]:::admin
  G -. admin .-> Q[QR-kode]:::admin
  G -. admin .-> X[Excel]:::admin
  G -. admin .-> SK
  M --> QR[QR-skandeerder]:::screen
  B --> GR[Groep: lede]:::admin
  B --> VL[Volgers-lys]:::admin
  R([Rat]):::tap --> I[Instellings]:::screen
  I --> V[Wat ek volg]:::screen
  I -. Hoof-admin .-> L[Verander 'n leerder]:::admin
  I -. Hoof-admin .-> LA[Leerder-aansig]:::admin
""")

DEPS = mer("""
flowchart TB
  PROF[Profiel: graad en geslag]:::screen --> WIE[Wie mag kom]:::db
  UIT[Uitnodigings]:::db --> WIE
  WIE --> KAL[Kalender en Soek]:::screen
  WIE --> KEN[Kennisgewings]:::push
  VOLG[Volg en groepe]:::db --> KEN
  GEL[Geleenthede: skep en wysig]:::admin --> KEN
  GEL --> KAL
  KEN --> INB[Inbox]:::inbox
  UIT --> BES[Bespreek]:::db
  BES --> KEN
  BES --> MP[My program]:::screen
  BES --> XL[Excel]:::admin
  AAN[Aanmelding: GPS en QR]:::db --> XL
  SIR[Sirkel en radius]:::admin --> AAN
  SIR --> AK[Aankoms-kennisgewing]:::push
  ADM[Bestuur: admins]:::admin --> GEL
  ADM --> VOLG
""")

MATRIX_COLS = ["Kalender en Soek", "My program", "Inbox", "Kennisgewing", "Excel", "Admin-tellings"]
MATRIX = [
  ("Admin skep 'n geleentheid", [1,0,1,1,0,1]),
  ("Admin wysig tyd, plek of naam", [1,1,1,1,0,0]),
  ("Admin skrap 'n geleentheid", [1,1,1,1,1,1]),
  ("Leerder bespreek", [0,1,0,1,1,1]),
  ("Leerder meld aan", [0,0,0,0,1,1]),
  ("Admin nooi mense", [1,0,1,1,1,1]),
  ("Leerder aanvaar of weier", [0,1,1,0,1,1]),
  ("Admin voeg iemand by 'n groep", [0,0,1,1,0,1]),
  ("Leerder volg of ontvolg", [0,0,1,1,0,1]),
  ("Graad verander (1 Jan of Hoof-admin)", [1,0,0,1,0,0]),
]
matrix_html = '<div class="tablewrap"><table class="matrix"><thead><tr><th>As dit gebeur…</th>' + ''.join(f'<th><span>{e(c)}</span></th>' for c in MATRIX_COLS) + '</tr></thead><tbody>' + \
  ''.join('<tr><th>' + e(r) + '</th>' + ''.join(f'<td>{"<i class=dot-on></i>" if v else "<i class=dot-off></i>"}</td>' for v in vals) + '</tr>' for r, vals in MATRIX) + '</tbody></table></div>'

MODULES = [
  ("Profiel en grade", "c-blue", ["Naam, graad en geslag is gesluit: net 'n Hoof-admin verander dit.", "Elke 31 Desember gaan almal een graad op; Graad 12 word Alumni."], ["Wie mag kom", "Kennisgewings"]),
  ("Geleenthede", "c-green", ["Skep en wysig in Skep; departement-admins net hul eie afdeling.", "Subafdeling, wie mag kom, net op uitnodiging, sirkel en radius."], ["Kalender", "Kennisgewings", "Aanmelding"]),
  ("Bespreek", "c-teal", ["Een tik; tik weer om te kanselleer.", "Aanvaar van 'n uitnodiging bespreek ook."], ["My program", "Herinnering", "Excel"]),
  ("Aanmelding", "c-teal", ["Meld aan op Kaart of skandeer QR: net binne die sirkel.", "Werk offline: gestoor en later gestuur."], ["Excel", "Admin-tellings"]),
  ("Uitnodigings", "c-purple", ["Per graad, groep of e-pos.", "Gee toegang; leerder aanvaar of weier."], ["Inbox", "Bespreek", "Excel"]),
  ("Afdelings, subafdelings, volg", "c-purple", ["Almal volg alle afdelings by verstek.", "Oop groepe: self aansluit. Privaat: net admins."], ["Kennisgewings", "Inbox"]),
  ("Kennisgewings en Inbox", "c-gold", ["Push gaan net na toestelle met kennisgewings aan.", "Die Inbox hou alles, ook as push af is; 'n jaar lank."], ["My program", "Oortjie-getal"]),
  ("Excel", "c-green", ["Dele: aangemeld, bespreek nie aangemeld, genooi, verdag.", "Met kolomme Vooraf bespreek en Uitnodiging."], ["Admins"]),
  ("Bestuur en admins", "c-blue", ["Hoof-admin: afdelings, kleure, admins.", "Elke afdeling-admin: subafdelings en lede."], ["Skep", "Groepe"]),
  ("Privaatheid", "c-red", ["Geleenthede en aanmeldings weg ná 5 jaar; rekeninge ná 5 jaar sonder gebruik.", "Skrap my rekening vee alles uit."], ["Alles"]),
]
mod_html = ''.join(f'''<div class="module {c}"><h4>{e(t)}</h4><ul>{''.join(f"<li>{e(x)}</li>" for x in pts)}</ul><div class="affects"><span>Beïnvloed</span>{''.join(f"<em>{e(a)}</em>" for a in aff)}</div></div>''' for t, c, pts, aff in MODULES)

page = open(os.path.join(D, 'template.html'), encoding='utf-8').read()
page = page.replace('{{SCREENS}}', screen_html).replace('{{FLOWS}}', flow_html).replace('{{NAV}}', NAV) \
           .replace('{{DEPS}}', DEPS).replace('{{MATRIX}}', matrix_html).replace('{{MODULES}}', mod_html)
open(os.path.join(D, 'garsie-vloeikaart.html'), 'w', encoding='utf-8').write(page)
print("built", len(page))
