import re, os
D = os.path.dirname(os.path.abspath(__file__))
t = open(os.path.join(D, 'template.html'), encoding='utf-8').read()
t = re.sub(r'<svg class="crest"[\s\S]*?</svg>', '{{CREST}}', t, count=1)
css = open(os.path.join(D, 'map.css'), encoding='utf-8').read()
t = t.replace('@media (max-width:900px){', css + '\n@media (max-width:900px){', 1)
a = t.index('<section id="rolle">'); b = t.index('<section id="vloei">')
t = t[:a] + open(os.path.join(D, 'sections2.html'), encoding='utf-8').read() + t[b:]
toc_old = t[t.index('<nav class="toc"'):t.index('</nav>') + 6]
t = t.replace(toc_old, '''<nav class="toc" aria-label="Inhoud">
    <a href="#kaart"><b>1</b>Skermkaart</a>
    <a href="#prosesse"><b>2</b>Prosesse</a>
    <a href="#vloei"><b>3</b>Vloei</a>
    <a href="#afdelings"><b>4</b>Funksie-afdelings</a>
    <a href="#rolle"><b>5</b>Wie doen wat</a>
    <a href="#outomaties"><b>6</b>Agter die skerms</a>
  </nav>''')
t = re.sub(r'<p>Elke knoppie in die app[^<]*</p>', '<p>Al die skerms op een zoombare kaart, elke proses stap vir stap, die vloei van die belangrikste aksies, hoe die funksies mekaar beïnvloed, en wie wat in die app kan doen.</p>', t)
# "Wie doen wat" goes last, just before "Agter die skerms"; renumber.
a = t.index('<section id="rolle">'); b = t.index('<section id="kaart"')
rolle = t[a:b]; t = t[:a] + t[b:]
t = t.replace('<section id="outomaties">', rolle + '<section id="outomaties">', 1)
for old, new in [('<span class="no">1</span><h2>Wie doen wat', '<span class="no">5</span><h2>Wie doen wat'),
                 ('<span class="no">2</span><h2>Skermkaart', '<span class="no">1</span><h2>Skermkaart'),
                 ('<span class="no">3</span><h2>Prosesse', '<span class="no">2</span><h2>Prosesse'),
                 ('<span class="no">4</span><h2>Vloei', '<span class="no">3</span><h2>Vloei'),
                 ('<span class="no">5</span><h2>Funksie-afdelings', '<span class="no">4</span><h2>Funksie-afdelings')]:
    assert old in t, old
    t = t.replace(old, new, 1)
t = t.rstrip() + '\n' + open(os.path.join(D, 'map.js'), encoding='utf-8').read() + '\n'
open(os.path.join(D, 'template2.html'), 'w', encoding='utf-8').write(t)
print('template2 ok')
