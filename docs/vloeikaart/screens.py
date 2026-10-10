# Screens for the flow document: how to set the app up for each screenshot,
# and the buttons to number on it (selector, name, what it does, what it sets off).
import json, os

LEARNER = 'asLearner();'
DEPT = 'asDept();'
KEY = 'asKey();'

SCREENS = [
  dict(id="kalender", group="Leerder", title="Kalender", h=844, setup=LEARNER + 'state.tab="calendar"; state.calView="week"; goToDate(TODAY);', calls=[
    ('#settings-btn', "Rat (Instellings)", "Maak Instellings oop: profiel, kennisgewings, wat jy volg, installeer, teken uit.", ""),
    ('[data-action="cal-today"]', "Vandag", "Spring terug na hierdie week of maand.", ""),
    ('[aria-label="Kalenderaansig"]', "Week / Maand", "Wissel tussen die week-uitleg en die maand-uitleg.", "Onthou op die foon"),
    ('[data-action="cal-jump"]', "Maand-titel", "Kies enige datum om heen te spring.", ""),
    ('[data-action="cal-next"]', "Vorige / volgende", "Een week of maand terug of vorentoe.", ""),
    ('.chips', "Afdeling-filter", "Wys net een afdeling. Die pyltjie langs 'n afdeling is 'n dropdown met sy subafdelings.", "Geld ook in Soek en My program"),
    ('.block', "Geleentheid-blok", "Maak die geleentheid oop.", ""),
    ('.tabbar', "Oortjies", "Kalender, Kaart, Soek, My program. Admins kry Bestuur en Skep voor aan, en geen Kaart nie.", "Rooi getal = ongelees in Inbox"),
  ]),
  dict(id="geleentheid", group="Leerder", title="Geleentheid (leerder)", h=844, setup=LEARNER + 'state.tab="calendar"; state.openEventId=2;', calls=[
    ('[data-action="back"]', "Terug", "Terug na waar jy was.", ""),
    ('.audience-badge', "Kentekens", "Afdeling · subafdeling, vir wie dit is, en of dit net op uitnodiging is.", ""),
    ('[data-action="open-map"]', "Meld aan by die geleentheid", "Gaan na Kaart by hierdie geleentheid.", ""),
    ('[data-action="answer-invite"][data-accept="1"]', "Aanvaar / Weier", "Antwoord op 'n uitnodiging.", "Aanvaar = jou plek word bespreek · admin sien dit in Excel"),
    ('[data-action="toggle-support"]', "Bespreek", "Bespreek jou plek (tik weer om te kanselleer).", "Herinnering 'n uur voor · boodskap as dit verskuif of gekanselleer word"),
  ]),
  dict(id="kaart", group="Leerder", title="Kaart", h=844, setup=LEARNER + 'state.tab="map"; state.mapMode="map"; state.mapEventId=1; geo.status="on"; geo.pos={lat:-25.79735,lng:28.30550,accuracy:12};', wait=2500, calls=[
    ('[data-action="map-map"]', "Kaart / QR", "Wissel tussen die kaart en die QR-skandeerder.", ""),
    ('[data-action="locate-me"]', "My ligging", "Wys waar jy is.", "Vra eers toestemming vir ligging"),
    ('#map-event-select', "Kies geleentheid", "Watter geleentheid se sirkel jy wil sien.", ""),
    ('[data-action="checkin"]', "Meld aan", "Werk net binne die sirkel.", "checkin() kyk weer die afstand · offline: gestoor en later gestuur"),
  ]),
  dict(id="qr", group="Leerder", title="Kaart ▸ QR", h=844, setup=LEARNER + 'state.tab="map"; state.mapMode="qr"; state.scan={status:"idle",message:""};', calls=[
    ('[data-action="start-scan"]', "Begin skandeer", "Maak die kamera oop om die admin se QR-kode te skandeer.", "Kyk jou ligging: net binne die sirkel tel dit"),
  ]),
  dict(id="soek", group="Leerder", title="Soek", h=844, setup=LEARNER + 'state.tab="search"; state.query="";', calls=[
    ('#searchbox', "Soekveld", "Soek op naam, plek, afdeling of datum (bv. \"12 Okt\").", ""),
    ('#mic-btn', "Mikrofoon", "Praat in plaas van tik.", "Net in Chrome, Edge en Safari"),
    ('.chip-caret', "Subafdeling-dropdown", "Kies die hele afdeling of net een subafdeling.", ""),
    ('#results', "Resultate", "Per maand gegroepeer; tik om oop te maak.", ""),
  ]),
  dict(id="myprogram", group="Leerder", title="My program", h=900, setup=LEARNER + 'state.tab="mine"; state.inboxOpen=true;', calls=[
    ('#inbox > summary', "Inbox", "Dropdown met uitnodigings en boodskappe. Oopmaak = gelees.", "Die rooi getal op die oortjie verdwyn"),
    ('.inbox-item [data-accept="1"]', "Aanvaar / Weier / Meer", "Antwoord dadelik op 'n uitnodiging.", ""),
    ('.inbox-item[data-event]', "Boodskap", "Nuwe geleentheid, verandering, kansellasie of \"bygevoeg by groep\". Tik om oop te maak.", ""),
    ('.mine-grid [data-event]', "Jou besprekings", "Alles wat jy bespreek het, per maand.", ""),
  ]),
  dict(id="instellings", group="Almal", title="Instellings", h=1180, setup=KEY + 'state.settingsOpen=true; state.settingsPage=null;', calls=[
    ('#push-card', "Kennisgewings", "Skakel kennisgewings op hierdie toestel aan of af; stuur 'n toets.", "Sonder dit kom boodskappe net in die Inbox"),
    ('[data-page="follow"]', "Wat ek volg", "Afdelings en oop groepe aan- of afskakel.", ""),
    ('[data-action="install-help"]', "Sit op tuisskerm", "Wys hoe om die app op jou foon se tuisskerm te sit.", "Nodig vir kennisgewings op iPhone"),
    ('[data-page="learner"]', "Verander 'n leerder (Hoof-admin)", "Naam, graad of geslag van 'n leerder regstel.", ""),
    ('[data-page="preview"]', "Leerder-aansig (Hoof-admin)", "Sien die app soos 'n leerder; niks word gestoor nie.", ""),
    ('[data-action="delete-account"]', "Skrap my rekening", "Vee alles van jou uit.", "Kan nie ongedaan gemaak word nie"),
  ]),
  dict(id="volg", group="Leerder", title="Wat ek volg", h=760, setup=LEARNER + 'state.settingsOpen=true; state.settingsPage="follow";', calls=[
    ('[data-action="toggle-follow-dept"]', "Volg afdeling", "Almal volg al die afdelings van die begin af.", "Bepaal of jy \"Nuwe geleentheid\" kry"),
    ('.pill', "Lid (privaat groep)", "'n Admin het jou bygevoeg; net 'n admin kan jou afhaal.", ""),
    ('[data-action="toggle-group"]', "Volg oop groep", "Sluit aan by of verlaat 'n oop subafdeling.", ""),
  ]),
  dict(id="skep1", group="Admin", title="Skep (bo)", h=1100, setup=DEPT + 'state.tab="create"; state.editingId=null;', wait=1500, calls=[
    ('[name="title"]', "Titel", "Naam van die geleentheid.", ""),
    ('#group-select', "Subafdeling", "Opsioneel: bv. Rugby. Bepaal wie by verstek die kennisgewing kry.", ""),
    ('#pick-map', "Aanmeldligging", "Soek 'n adres of sleep die speld.", ""),
    ('[name="radius"]', "Radius", "Hoe groot die aanmeld-sirkel is (25–1000 m).", "Meld aan en QR tel net binne die sirkel"),
  ]),
  dict(id="skep2", group="Admin", title="Skep (onder)", h=1450, setup=DEPT + 'state.tab="create"; state.editingId=null;', scroll='[name="inviteOnly"]', open='.notify-box', calls=[
    ('[name="inviteOnly"]', "Net op uitnodiging", "Net wie genooi is, sien die geleentheid.", ""),
    ('[name="learnersOnly"]', "Wie mag kom?", "Net leerders, sekere grade, net seuns of meisies.", "Bepaal wie dit in die kalender sien"),
    ('.notify-box > summary', "Wie kry 'n kennisgewing?", "Volgers, die subafdeling, en ekstra grade, groepe of e-posse.", "announce_event() → Inbox + push"),
    ('[data-form="event"] [type="submit"]', "Skep geleentheid", "Stoor en stuur die kennisgewings.", ""),
  ]),
  dict(id="admingeleentheid", group="Admin", title="Geleentheid (admin)", h=844, setup=DEPT + 'state.tab="calendar"; state.openEventId=2;', calls=[
    ('[data-action="invite-open"]', "Nooi", "Nooi mense na hierdie geleentheid.", ""),
    ('[data-action="edit-event"]', "Wysig", "Verander die geleentheid.", "As tyd, plek of naam verander: boodskap aan wie bespreek het"),
    ('[data-action="show-qr"]', "QR", "Wys die lewende QR-kode by die ingang, of druk 'n plakkaat.", ""),
    ('[data-action="export"]', "Excel", "Laai die bywoningslys af.", "In dele: aangemeld, bespreek, genooi, verdag"),
  ]),
  dict(id="nooi", group="Admin", title="Nooi mense", h=844, setup=DEPT + 'state.tab="calendar"; state.openEventId=2; state.inviteEventId=2; state.inviteResult="";', calls=[
    ('[name="grades"]', "Grade (+ geslag)", "Nooi hele grade, eventueel net seuns of meisies.", ""),
    ('#groups-box', "Subafdelings en groepe", "Nooi almal in 'n groep (🔒 = privaat).", ""),
    ('[name="emails"]', "E-posadresse", "Plak 'n lys; die app sê wie nie geregistreer is nie.", ""),
    ('[data-form="invite"] [type="submit"]', "Stuur uitnodigings", "Nuwe genooides kry 'n push en sien dit in hul Inbox.", "Reeds genooi = geen tweede boodskap"),
  ]),
  dict(id="bestuur", group="Admin", title="Bestuur", h=1500, setup=KEY + 'state.tab="manage"; state.manageGroupId=null;', calls=[
    ('#manage-dept', "Departement (Hoof-admin)", "Kies watter afdeling se subafdelings jy bestuur.", ""),
    ('[data-action="show-followers"]', "Lys (volgers)", "Wie die hele afdeling volg.", ""),
    ('[data-action="open-group"]', "Bestuur (groep)", "Maak 'n subafdeling oop: lede, oop/privaat, byvoeg.", ""),
    ('[data-form="new-group"]', "Nuwe subafdeling", "Skep 'n oop of privaat subafdeling.", ""),
    ('[data-form="dept"]', "Departemente (Hoof-admin)", "Nuwe afdeling met 'n kleur.", ""),
    ('[data-form="admin"]', "Admins (Hoof-admin)", "Gee iemand admin-regte vir 'n afdeling of alles.", "Geld sodra hulle weer inteken"),
  ]),
  dict(id="groep", group="Admin", title="Bestuur ▸ groep", h=1250, setup=DEPT + 'state.tab="manage"; state.manageGroupId="g2"; state.memberList={key:"g2", rows:MEMBERS};', type=('#person-search', 'pie'), calls=[
    ('[data-form="edit-group"]', "Naam en oop/privaat", "Hernoem; kies of leerders self kan aansluit.", ""),
    ('#person-search', "Soek iemand", "Tik 'n naam, van of e-pos; kies uit die dropdown.", "Die persoon kry \"Jy is bygevoeg\" in die Inbox"),
    ('[data-form="add-members"]', "Plak e-posse", "Voeg baie mense op een slag by.", ""),
    ('[data-action="remove-member"]', "Haal af", "Haal iemand uit die groep.", ""),
    ('[data-action="delete-group"]', "Skrap subafdeling", "Die groep verdwyn; geleenthede bly.", ""),
  ]),
]
json.dump(SCREENS, open(os.path.join(os.path.dirname(__file__), 'screens.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
print(len(SCREENS), "screens")
