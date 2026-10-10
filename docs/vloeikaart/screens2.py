# The zoomable screen map: every screen once, placed on a big canvas, with the
# numbered buttons explained and arrows from a button to the screen it opens.
import json, os
base = {s['id']: s for s in json.load(open(os.path.join(os.path.dirname(__file__), 'screens.json'), encoding='utf-8'))}

L, D, K = 'asLearner();', 'asDept();', 'asKey();'
COL = 760          # distance between columns (screen 390 wide + legend room)
ROW_A, ROW_B = 0, 4200   # learner lane, admin lane

def S(id, lane, title, x, y, setup, calls, links=(), **kw):
    return dict(id=id, lane=lane, title=title, x=x, y=y, setup=setup, calls=calls, links=list(links), **kw)

def calls_of(id): return [list(c) for c in base[id]['calls']]

SCREENS = [
  # ---------------------------------------------------------------- learner lane
  S("kalender", "Leerder", "Kalender", 0, ROW_A, L + 'state.tab="calendar"; state.calView="week"; goToDate(TODAY);', calls_of("kalender"),
    [('.block', 'geleentheid', 'Tik op geleentheid'), ('.tabbar [data-tab="map"]', 'kaart', 'Kaart'),
     ('.tabbar [data-tab="search"]', 'soek', 'Soek'), ('.tabbar [data-tab="mine"]', 'myprogram', 'My program'),
     ('#settings-btn', 'instellings-l', 'Rat')]),
  S("kaart", "Leerder", "Kaart", COL, ROW_A, base["kaart"]["setup"], calls_of("kaart"),
    [('[data-action="map-qr"]', 'qr', 'QR')], wait=2500),
  S("qr", "Leerder", "Kaart ▸ QR-skandeerder", COL * 2, ROW_A, base["qr"]["setup"], calls_of("qr"),
    [('[data-action="map-map"]', 'kaart', 'Kaart')]),
  S("soek", "Leerder", "Soek", COL, ROW_A + 1150, base["soek"]["setup"].replace('state.query="";', 'state.query="";'), calls_of("soek"),
    [('#results [data-event]', 'geleentheid', 'Tik op resultaat')]),
  S("myprogram", "Leerder", "My program + Inbox", COL, ROW_A + 2300, base["myprogram"]["setup"], calls_of("myprogram"),
    [('.mine-grid [data-event]', 'geleentheid', 'Tik op bespreking'), ('.inbox-item[data-event]', 'geleentheid', 'Tik op boodskap')]),
  S("geleentheid", "Leerder", "Geleentheid (leerder)", COL * 2, ROW_A + 1150, base["geleentheid"]["setup"], calls_of("geleentheid"),
    [('[data-action="open-map"]', 'kaart', 'Meld aan by die geleentheid')]),
  S("instellings-l", "Leerder", "Instellings (leerder)", COL * 3, ROW_A, L + 'state.settingsOpen=true; state.settingsPage=null;',
    [c for c in calls_of("instellings") if 'learner' not in c[0] and 'preview' not in c[0]],
    [('[data-page="follow"]', 'volg', 'Wat ek volg')], full=True),
  S("volg", "Leerder", "Wat ek volg", COL * 4, ROW_A, base["volg"]["setup"], calls_of("volg")),

  # ---------------------------------------------------------------- admin lane
  S("kalender-a", "Admin", "Kalender (admin)", 0, ROW_B, D + 'state.tab="calendar"; state.calView="week"; goToDate(TODAY);', [
      ['.tabbar [data-tab="manage"]', "Bestuur", "Subafdelings, lede en volgers. Hoof-admin ook afdelings en admins.", ""],
      ['.tabbar [data-tab="create"]', "Skep", "Nuwe geleentheid, en al jou geleenthede met Wysig, QR, Excel en Skrap.", ""],
      ['[data-action="new-event"]', "+", "Kortpad na Skep.", ""],
      ['.block', "Geleentheid", "Maak die geleentheid oop, met die admin-kaart onderaan.", ""],
      ['.tabbar', "Oortjies (admin)", "Bestuur en Skep voor aan; geen Kaart nie (admins meld nie aan nie).", ""]],
    [('.tabbar [data-tab="manage"]', 'bestuur', 'Bestuur'), ('.tabbar [data-tab="create"]', 'skep', 'Skep'),
     ('.block', 'admingeleentheid', 'Tik op geleentheid'), ('#settings-btn', 'instellings', 'Rat')]),
  S("bestuur", "Admin", "Bestuur", COL, ROW_B, base["bestuur"]["setup"], calls_of("bestuur"),
    [('[data-action="open-group"]', 'groep', 'Bestuur (groep)'), ('[data-action="show-followers"]', 'volgers', 'Lys')], full=True),
  S("groep", "Admin", "Bestuur ▸ groep", COL * 2, ROW_B, base["groep"]["setup"], calls_of("groep"), full=True, type=base["groep"]["type"]),
  S("volgers", "Admin", "Bestuur ▸ volgers", COL * 2, ROW_B + 1500, D + 'state.tab="manage"; state.manageFollowers="d1"; state.memberList={key:"dept:d1", rows:MEMBERS};', [
      ['h2', "Getal volgers", "Almal volg outomaties; leerders kan dit in Instellings afskakel.", ""],
      ['.card', "Lys", "Naam, graad en e-pos van elke volger. Net admins sien dit.", ""]], full=True),
  S("skep", "Admin", "Skep", COL * 3, ROW_B, D + 'state.tab="create"; state.editingId=null;',
    calls_of("skep1") + calls_of("skep2") + [['[data-action="export"]', "Lys van jou geleenthede", "Wysig, QR, Excel en Skrap per geleentheid.", ""]],
    [], full=True, wait=1500, open='.notify-box'),
  S("admingeleentheid", "Admin", "Geleentheid (admin)", COL * 4, ROW_B, base["admingeleentheid"]["setup"], calls_of("admingeleentheid"),
    [('[data-action="invite-open"]', 'nooi', 'Nooi'), ('[data-action="show-qr"]', 'qr-admin', 'QR'),
     ('[data-action="export"]', 'excel', 'Excel'), ('[data-action="edit-event"]', 'skep', 'Wysig')]),
  S("nooi", "Admin", "Nooi mense", COL * 5, ROW_B, base["nooi"]["setup"], calls_of("nooi")),
  S("qr-admin", "Admin", "QR-kode by die ingang", COL * 5, ROW_B + 1150, D + 'state.tab="calendar"; state.qrEventId=1; state.qrMode="live";', [
      ['#qr-box', "Lewendige QR-kode", "Verander elke 30 sekondes; leerders skandeer dit by die ingang.", "Aanmelding tel net binne die sirkel"],
      ['[data-action="qr-mode-print"]', "Lewendig / Om te druk", "Druk 'n plakkaat met 'n vaste kode.", "Die vaste kode word net deur die ligging beskerm"]], wait=1500),
  S("instellings", "Admin", "Instellings (Hoof-admin)", COL * 6, ROW_B, base["instellings"]["setup"], calls_of("instellings"),
    [('[data-page="learner"]', 'leerder-edit', "Verander 'n leerder"), ('[data-page="preview"]', 'preview', 'Leerder-aansig')], full=True),
  S("leerder-edit", "Admin", "Verander 'n leerder", COL * 7, ROW_B, K + 'state.settingsOpen=true; state.settingsPage="learner"; state.learnerEdit={ email:"jan.smit@voorbeeld.co.za", name:"Jan", surname:"Smit", grade:"Graad 11", gender:"Seun" };', [
      ['[data-form="find-learner"]', "Soek op e-pos", "Vind die leerder.", ""],
      ['[data-form="edit-learner"]', "Naam, graad, geslag", "Regstel en stoor; net 'n Hoof-admin mag dit.", "Leerders kan dit nie self verander nie"]], full=True),
  S("preview", "Admin", "Leerder-aansig", COL * 7, ROW_B + 1300, K + 'state.settingsOpen=true; state.settingsPage="preview";', [
      ['[data-form="start-preview"]', "Kies graad en geslag", "Sien die app soos daardie leerder; niks word gestoor nie.", "Goue strook bo met Verlaat"]]),
]
# The Excel export, drawn as its own (HTML) node in the map.
EXCEL = dict(id="excel", lane="Admin", title="Excel-bywoning", x=COL * 5, y=ROW_B + 2300)

json.dump({"screens": SCREENS, "excel": EXCEL}, open(os.path.join(os.path.dirname(__file__), 'screens2.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
print(len(SCREENS), "screens")
