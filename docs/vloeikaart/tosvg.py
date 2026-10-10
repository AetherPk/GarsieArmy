# Turn the captured PDFs (vec/*.pdf) into compact vector SVGs for the document.
import pymupdf, json, re, os
D = os.path.dirname(os.path.abspath(__file__))
for jf in ['vrects.json', 'prects.json']:
    for s in json.load(open(os.path.join(D, jf))):
        p = pymupdf.open(os.path.join(D, 'vec', s['id'] + '.pdf'))[0]
        svg = p.get_svg_image(text_as_path=True)
        svg = re.sub(r'<svg([^>]*?) width="[^"]*" height="[^"]*"', lambda m: f'<svg{m.group(1)} width="{s["w"]}" height="{s["h"]}"', svg, count=1)
        svg = re.sub(r'(\d+\.\d)\d+', r'\1', svg)
        svg = re.sub(r'\s{2,}', ' ', svg)
        open(os.path.join(D, 'vec', s['id'] + '.svg'), 'w', encoding='utf-8').write(svg)
print('svgs done')
