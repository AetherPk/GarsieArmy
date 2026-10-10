# "Wie doen wat": per person, what they can do, and what happens then.
# Each item is a chain: ("a", step the person takes) and ("r", what follows).
import html
e = html.escape

ENTITIES = [
 ("besoeker", "Besoeker", "Iemand wat nog nie ingeteken is nie.", [
   ("Registreer", [("a", "Tik e-pos, naam, van, graad en geslag"), ("a", "Merk die privaatheidskennisgewing"), ("a", "Stuur kode"),
                   ("r", "Bediener kyk of die e-pos al bestaan; so ja, sê die app kies Teken in"), ("r", "E-pos met 'n 6-syferkode"),
                   ("a", "Tik die kode"), ("r", "Rekening en profiel geskep; naam, graad en geslag is nou gesluit"),
                   ("r", "Kalender wys net geleenthede vir jou graad en geslag")]),
   ("Teken in", [("a", "Tik e-pos en Stuur kode"), ("r", "E-pos met 'n kode"), ("a", "Tik die kode"), ("r", "Ingeteken; jy bly ingeteken op hierdie toestel")]),
   ("Teken in met Google", [("a", "Gaan voort met Google"), ("r", "Google gee net naam en e-pos"), ("a", "Eerste keer: kies graad en geslag, merk privaatheid"),
                            ("r", "Profiel geskep")]),
 ]),
 ("leerder", "Leerder", "Ook alumni en ouers, behalwe waar anders gesê.", [
   ("Kyk na geleenthede", [("a", "Kies 'n afdeling of subafdeling in die filter"), ("r", "Net daardie geleenthede in Kalender, Soek en My program"),
                           ("a", "Kies Week of Maand"), ("r", "Ander uitleg; die foon onthou dit"),
                           ("r", "Alumni en ouers sien nie geleenthede wat net vir leerders, sekere grade of een geslag is nie, tensy genooi")]),
   ("Soek", [("a", "Tik, of tik op die mikrofoon en praat"), ("r", "Resultate per maand, terwyl jy tik")]),
   ("Bespreek", [("a", "Tik Bespreek op 'n geleentheid"), ("r", "Verskyn in My program"), ("r", "Admin se telling en Excel word bygewerk"),
                 ("r", "Herinnering 'n uur voor"), ("r", "Boodskap as dit verskuif of gekanselleer word"), ("a", "Tik weer"), ("r", "Bespreking gekanselleer")]),
   ("Antwoord 'n uitnodiging", [("r", "Push en 'n uitnodiging in die Inbox"), ("a", "Aanvaar"), ("r", "Jou plek is bespreek"),
                                ("a", "Of Weier"), ("r", "Bespreking weg; die admin sien die antwoord")]),
   ("Meld aan met die Kaart", [("a", "Deel my ligging"), ("r", "Afstand tot die geleentheid"), ("r", "Op die dag binne die sirkel: Jy mag nou aanmeld"),
                               ("a", "Meld aan"), ("r", "Bediener kyk die afstand weer"), ("r", "Aangemeld en in die admin se Excel"),
                               ("r", "Sonder internet: op die foon gestoor en later gestuur")]),
   ("Meld aan met 'n QR-kode", [("a", "Kaart ▸ QR ▸ Begin skandeer"), ("r", "Ligging word gekyk"), ("r", "Binne die sirkel: aangemeld; buite: geweier")]),
   ("Inbox", [("a", "Maak die Inbox oop"), ("r", "Boodskappe gemerk as gelees; die rooi getal verdwyn")]),
   ("Volg", [("a", "Skakel 'n afdeling af"), ("r", "Geen Nuwe geleentheid meer van daardie afdeling nie"),
             ("a", "Volg 'n oop groep"), ("r", "Kry Nuwe geleentheid as die admin daardie groep kies")]),
   ("Kennisgewings", [("a", "Skakel kennisgewings aan"), ("r", "Foon vra Allow; toestel geregistreer"), ("r", "Push vir alles hierbo"),
                      ("a", "Stuur toets"), ("r", "Toetsboodskap op jou eie toestelle")]),
   ("Kalender", [("r", "'n Rooi kolletjie op die rat wys die opsie een keer (geen opspringer nie)"),
                 ("a", "Tik op die rat"), ("r", "Instellings maak oop by Kalender; die kolletjie verdwyn"),
                 ("a", "Skakel aan"), ("r", "Privaat skakel net vir jou"),
                 ("a", "Voeg by Apple- of Google-kalender, of kopieer die skakel vir Outlook"), ("r", "Jou besprekings verskyn in jou foon se kalender"),
                 ("r", "Veranderings en kansellasies kom vanself, maar nie dadelik nie (Apple elke uur, Google elke paar uur)"),
                 ("a", "Skakel af"), ("r", "Skakel werk nie meer nie; die geleenthede verdwyn by die volgende bywerking")]),
   ("Rekening", [("a", "Teken uit"), ("r", "Uit op hierdie toestel"), ("a", "Skrap my rekening en bevestig"), ("r", "Alles van jou uitgevee")]),
 ]),
 ("dept", "Departement-admin", "Vir sy eie afdeling. By ander afdelings is hy net 'n gewone gebruiker, en hy het geen Kaart-oortjie nie.", [
   ("Skep 'n geleentheid", [("a", "Skep ▸ titel, datum, tye, plek"), ("a", "Kies 'n subafdeling"), ("r", "By verstek kry die subafdeling se lede die kennisgewing"),
                            ("a", "Kies wie dit mag sien: grade, geslag, net leerders, net op uitnodiging"), ("r", "Net hulle sien dit in Kalender en Soek"),
                            ("a", "Stel die ligging en radius"), ("r", "Aanmelding tel net binne die sirkel"), ("r", "Leerders kry Jy mag nou aanmeld as hulle in die sirkel kom"),
                            ("a", "Kies wie 'n kennisgewing kry: volgers, subafdeling, grade, groepe, e-posse"), ("r", "Net wie dit mag sien, kry Inbox en push"),
                            ("a", "Skep geleentheid"), ("r", "Foute verskyn langs die velde; reg: gestoor"), ("r", "Kalender spring na die datum")]),
   ("Wysig", [("a", "Wysig ▸ verander ▸ Stoor"), ("r", "Tyd, plek of naam verander: Verandering aan almal wat bespreek het"), ("r", "Ander veranderings: net gestoor")]),
   ("Skrap", [("a", "Skrap en bevestig"), ("r", "Gekanselleer aan almal wat bespreek het"), ("r", "Besprekings, uitnodigings en aanmeldings ook weg")]),
   ("Nooi", [("a", "Nooi ▸ kies grade, groepe of e-posse ▸ Stuur"), ("r", "Genooides sien die geleentheid, ook as dit net op uitnodiging is"),
             ("r", "Push en Inbox; wie reeds genooi is, kry niks weer nie"), ("r", "E-posse wat nie geregistreer is nie, word gelys")]),
   ("By die ingang", [("a", "QR ▸ Lewendig"), ("r", "Kode verander elke 30 sekondes; leerders skandeer dit"),
                      ("a", "Of Om te druk ▸ Druk plakkaat"), ("r", "Vaste kode; net die ligging beskerm dit")]),
   ("Bywoning", [("a", "Excel"), ("r", "Lys in dele: aangemeld, bespreek maar nie aangemeld nie, genooi, verdag")]),
   ("Subafdelings", [("a", "Bestuur ▸ nuwe subafdeling, oop of privaat"), ("r", "Oop: leerders kan dit self volg; privaat: net admins voeg by"),
                     ("a", "Soek iemand op naam en + Voeg by, of plak e-posse"), ("r", "Die persoon kry Jy is bygevoeg in die Inbox en as push"),
                     ("r", "Voortaan kennisgewings van die groep"), ("a", "Haal af of skrap die groep"), ("r", "Geleenthede bly")]),
   ("Volgers", [("a", "Bestuur ▸ Lys"), ("r", "Sien wie die afdeling volg")]),
 ]),
 ("key", "Hoof-admin", "Alles wat 'n departement-admin kan, vir elke afdeling, plus:", [
   ("Afdelings", [("a", "Nuwe afdeling met 'n kleur"), ("r", "Verskyn in die filter en die kalender se kleure"), ("a", "Skrap"), ("r", "Net as dit geen geleenthede of admins het nie")]),
   ("Admins", [("a", "Voeg admin by: e-pos, rol, afdeling"), ("r", "Ná weer inteken: Bestuur- en Skep-oortjies"),
               ("a", "Verwyder"), ("r", "Nie die laaste Hoof-admin nie")]),
   ("Leerder regstel", [("a", "Instellings ▸ Verander 'n leerder ▸ soek e-pos ▸ Stoor"), ("r", "Naam, graad of geslag reggestel"),
                        ("r", "Die leerder sien dadelik die geleenthede vir die nuwe graad of geslag")]),
   ("Leerder-aansig", [("a", "Instellings ▸ Leerder-aansig ▸ kies graad en geslag"), ("r", "Die app lyk soos vir daardie leerder; niks word gestoor nie"),
                       ("a", "Verlaat"), ("r", "Terug na jou eie app")]),
 ]),
]

def chain(steps):
    out = []
    for i, (k, t) in enumerate(steps):
        if i: out.append('<span class="ch-arrow" aria-hidden="true">→</span>')
        out.append(f'<span class="ch {"ch-a" if k == "a" else "ch-r"}">{e(t)}</span>')
    return ''.join(out)

tabs = ''.join(f'<button type="button" class="ent-tab{" on" if i == 0 else ""}" data-ent="{eid}" role="tab" aria-selected="{str(i == 0).lower()}">{e(name)}</button>'
               for i, (eid, name, _, _) in enumerate(ENTITIES))
panels = ''.join(
    f'<div class="ent-panel{" on" if i == 0 else ""}" id="ent-{eid}" role="tabpanel"><h3 class="ent-name">{e(name)}</h3><p class="ent-note">{e(note)}</p>'
    + ''.join(f'<div class="does"><b>{e(title)}</b><div class="chain">{chain(steps)}</div></div>' for title, steps in items) + '</div>'
    for i, (eid, name, note, items) in enumerate(ENTITIES))
WHO_HTML = (f'<div class="ent-key"><span class="ch ch-a">Wat die persoon doen</span><span class="ch ch-r">Wat dan gebeur</span></div>'
            f'<div class="ent-tabs" role="tablist">{tabs}</div>{panels}'
            '<script>document.querySelectorAll(".ent-tab").forEach(b => b.onclick = () => {'
            'document.querySelectorAll(".ent-tab").forEach(x => { x.classList.toggle("on", x === b); x.setAttribute("aria-selected", x === b); });'
            'document.querySelectorAll(".ent-panel").forEach(p => p.classList.toggle("on", p.id === "ent-" + b.dataset.ent)); });</script>')
