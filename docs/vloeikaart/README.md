# Garsie Army Vloeikaart

The flow document for the app: the zoomable screen map, the processes, the
flows, the function sections, "Wie doen wat" and "Agter die skerms".

- Online (private): https://claude.ai/artifact/9ZU8YcLKWCJ6kjk3R3AZhV
- PDF and single-file HTML: OneDrive → random → Garsie army
  ("Garsie Army Vloeikaart.pdf" / ".html")

Keep it up to date whenever the app changes: re-capture the screens that
changed, adjust the texts, rebuild, republish, and replace the OneDrive files.

## What is where

| File | What it holds |
|---|---|
| `screens.py` | Numbered buttons and texts per screen (first document; still the source for the map's callouts) |
| `screens2.py` | The screen map: which screens, their setup, arrows between them, placement |
| `procs.py` | The processes: steps, screens, boxes and arrows per process |
| `whodo.py` | "Wie doen wat": per person, what they do and what happens then |
| `build.py` | Flows, function sections and the "as dit gebeur" table (reused by `build2.py`) |
| `build2.py` | Builds `garsie-vloeikaart.html` (layout of the map, cards, arrows) |
| `procbuild.py` | Builds the process cards and each process's small diagram |
| `template.html`, `sections2.html`, `map.css`, `map.js`, `mk_template2.py` | Page template, styles and the pan/zoom code |
| `vcapture2.mjs`, `pcapture.mjs` | Open the real app in headless Edge with sample data (no account, no server writes) and print each screen to a vector PDF |
| `tosvg.py` | PDF → compact SVG (the screens stay sharp at any zoom) |
| `standalone2.py`, `pdf.mjs` | Single-file HTML (screens embedded) and the PDF |

The crest comes from `../../icons/crest-reference.svg` (the traced official crest).

## Rebuild

```bash
# 1. Serve the app (from the repo root) on port 8765
python -m http.server 8765
# 2. In docs/vloeikaart
python screens.py && python screens2.py && python procs.py
node vcapture2.mjs && node pcapture.mjs
python tosvg.py
python mk_template2.py && python build2.py
# 3. Single file + PDF (serve docs/vloeikaart on port 8766)
python standalone2.py
python -m http.server 8766
node pdf.mjs
```

Then republish `garsie-vloeikaart.html` with the `vec/*.svg` files to the
artifact link above, and copy `vloeikaart.pdf` and `standalone.html` to
OneDrive. Generated files are in `.gitignore`.
