# One self-contained HTML file (screens embedded) for OneDrive, with print
# rules: the screen map gets its own page and stays vector in the PDF.
import re, os, urllib.parse
D = os.path.dirname(os.path.abspath(__file__))
s = open(os.path.join(D, 'garsie-vloeikaart.html'), encoding='utf-8').read()

def svg_uri(m):
    data = open(os.path.join(D, 'vec', m.group(1) + '.svg'), encoding='utf-8').read()
    return 'src="data:image/svg+xml;charset=utf-8,' + urllib.parse.quote(data, safe=" /=:;,.-_()'") + '"'
s = re.sub(r'src="vec/([a-z0-9-]+)\.svg"', svg_uri, s)

m = re.search(r'id="world" style="width:(\d+)px;height:(\d+)px', s)
ww, wh = int(m.group(1)), int(m.group(2))
k = 1140 / ww
mh = int(wh * k) + 20
extra = f"""<style>
@page {{ size:A4; margin:0 }}
@page mappage {{ size:1400px {mh + 260}px; margin:0 }}
@media print {{
  html,body{{background:#011628;-webkit-print-color-adjust:exact;print-color-adjust:exact}}
  .wrap{{padding-block:24px}}
  .flow,.module,.tick,tr{{break-inside:avoid}}
  nav.toc,.mapbar{{display:none}}
  .mapsection{{page:mappage;break-before:page;break-after:page}}
  #mapview{{height:{mh}px;border:none;background:#000f1c}}
  #world{{transform:none !important;zoom:{k:.5f};margin-top:10px}}
  .card,#world,.lane{{break-inside:auto}}
}}
</style>
<style>
#printprocs{{display:none}}
@page procpage {{ size:1400px 1700px; margin:0 }}
@media print {{
  #prosesse .procs,#procdlg{{display:none !important}}
  #printprocs{{display:block}}
  .pp{{page:procpage;break-before:page;padding:30px 20px 0}}
  .pp h3{{font-size:30px;margin:4px 0}} .pp p{{color:var(--muted);margin:0 0 16px}}
  .pp .pw{{position:relative}}
}}
</style>
<script>
addEventListener("DOMContentLoaded", () => {{
  const box = document.createElement("div"); box.id = "printprocs";
  document.querySelectorAll("template[id^=pt-]").forEach(t => {{
    const w = +t.dataset.w, h = +t.dataset.h, z = Math.min(1120 / w, 1450 / h);
    const pp = document.createElement("div"); pp.className = "pp";
    pp.innerHTML = `<div class="eyebrow">${{t.dataset.who}}</div><h3>Proses: ${{t.dataset.title}}</h3><p>${{t.dataset.sum}}</p>`;
    const pw = document.createElement("div"); pw.className = "pw"; pw.style.cssText = `width:${{w}}px;height:${{h}}px;zoom:${{z}}`;
    pw.appendChild(t.content.cloneNode(true)); pp.appendChild(pw); box.appendChild(pp);
  }});
  document.getElementById("prosesse").appendChild(box);
}});
</script>
<script src="https://cdn.jsdelivr.net/npm/mermaid@10.9.1/dist/mermaid.min.js"></script>
<script>mermaid.initialize({{ startOnLoad:true }});</script>"""
head = '<!doctype html>\n<html lang="af"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">\n'
out = head + s.replace('</style>', '</style>' + extra, 1) + '\n</html>'
open(os.path.join(D, 'standalone.html'), 'w', encoding='utf-8').write(out)
print('standalone', len(out) // 1024, 'KB; print map height', mh)
