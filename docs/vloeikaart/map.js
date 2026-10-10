<script>
// Pan and zoom for a big "world" inside a frame: wheel or pinch to zoom,
// drag to pan, double-click to zoom in. Used by the screen map and by each
// process diagram (one shared viewer in the dialog).
function makeZoom(view, world, ww, wh, lvl){
  let k = 1, tx = 0, ty = 0, kMin = .02;
  const apply = () => { world.style.transform = `translate(${tx}px,${ty}px) scale(${k})`; if (lvl) lvl.textContent = Math.round(k * 100) + "%"; };
  const size = () => view.getBoundingClientRect();
  function fit(){ const r = size(); if (!r.width) return; k = Math.min(r.width / ww, r.height / wh) * .95; kMin = k * .6; tx = (r.width - ww * k) / 2; ty = (r.height - wh * k) / 2; apply(); }
  function zoomAt(px, py, f){ const nk = Math.min(6, Math.max(kMin, k * f)); tx = px - (px - tx) * nk / k; ty = py - (py - ty) * nk / k; k = nk; apply(); }
  function show(el){
    const r = size(), x = el.offsetLeft, y = el.offsetTop, w = el.offsetWidth, h = Math.min(el.offsetHeight, 1100);
    k = Math.min(r.width / (w + 120), r.height / (h + 80), 2.2); tx = r.width / 2 - (x + w / 2) * k; ty = 40 - (y - 20) * k; apply();
  }
  view.addEventListener("wheel", ev => { ev.preventDefault(); const r = size(); zoomAt(ev.clientX - r.left, ev.clientY - r.top, Math.exp(-ev.deltaY * (ev.ctrlKey ? .01 : .0018))); }, { passive:false });
  const pts = new Map(); let last = null;
  view.addEventListener("pointerdown", ev => { view.setPointerCapture(ev.pointerId); pts.set(ev.pointerId, { x:ev.clientX, y:ev.clientY }); view.classList.add("drag"); last = null; });
  view.addEventListener("pointermove", ev => {
    if (!pts.has(ev.pointerId)) return;
    const prev = pts.get(ev.pointerId); pts.set(ev.pointerId, { x:ev.clientX, y:ev.clientY });
    if (pts.size === 1){ tx += ev.clientX - prev.x; ty += ev.clientY - prev.y; apply(); }
    else if (pts.size === 2){
      const [a, b] = [...pts.values()], r = size(), d = Math.hypot(a.x - b.x, a.y - b.y), m = { x:(a.x + b.x) / 2 - r.left, y:(a.y + b.y) / 2 - r.top };
      if (last){ tx += m.x - last.m.x; ty += m.y - last.m.y; zoomAt(m.x, m.y, d / last.d); }
      last = { d, m };
    }
  });
  const up = ev => { pts.delete(ev.pointerId); last = null; if (!pts.size) view.classList.remove("drag"); };
  view.addEventListener("pointerup", up); view.addEventListener("pointercancel", up);
  view.addEventListener("dblclick", ev => { const r = size(); zoomAt(ev.clientX - r.left, ev.clientY - r.top, 2); });
  view.addEventListener("keydown", ev => {
    const r = size(), step = 80;
    if (ev.key === "+" || ev.key === "=") zoomAt(r.width / 2, r.height / 2, 1.4);
    else if (ev.key === "-") zoomAt(r.width / 2, r.height / 2, 1 / 1.4);
    else if (ev.key === "0") fit();
    else if (ev.key.startsWith("Arrow")){ tx += ev.key === "ArrowLeft" ? step : ev.key === "ArrowRight" ? -step : 0; ty += ev.key === "ArrowUp" ? step : ev.key === "ArrowDown" ? -step : 0; apply(); }
    else return;
    ev.preventDefault();
  });
  const center = f => { const r = size(); zoomAt(r.width / 2, r.height / 2, f); };
  return { fit, show, zoomAt, zoomIn:() => center(1.5), zoomOut:() => center(1 / 1.5), setSize(w, h){ ww = w; wh = h; } };
}

(() => {
  // The screen map.
  const view = document.getElementById("mapview"), world = document.getElementById("world");
  const z = makeZoom(view, world, {{WW}}, {{WH}}, document.getElementById("z-lvl"));
  document.getElementById("z-fit").onclick = z.fit;
  document.getElementById("z-in").onclick = z.zoomIn;
  document.getElementById("z-out").onclick = z.zoomOut;
  document.getElementById("z-jump").onchange = ev => { const c = document.getElementById("c-" + ev.target.value); if (c) z.show(c); ev.target.value = ""; };
  document.getElementById("z-full").onclick = () => {
    const w = document.querySelector(".mapwrap");
    try { const p = document.fullscreenElement ? document.exitFullscreen() : w.requestFullscreen && w.requestFullscreen(); if (p && p.catch) p.catch(() => {}); } catch (e) {}
  };
  document.addEventListener("fullscreenchange", () => { view.style.height = document.fullscreenElement ? "100vh" : ""; setTimeout(z.fit, 60); });
  window.addEventListener("resize", z.fit);
  window.mapFit = z.fit; window.mapShow = id => z.show(document.getElementById("c-" + id)); window.mapZoom = z.zoomAt;
  z.fit();

  // Processes: one dialog, filled from a <template> per process.
  const dlg = document.getElementById("procdlg"), pview = document.getElementById("pview"), pworld = document.getElementById("pworld");
  const pz = makeZoom(pview, pworld, 1000, 1000, document.getElementById("p-lvl"));
  function openProc(id){
    const t = document.getElementById("pt-" + id); if (!t) return;
    pworld.innerHTML = ""; pworld.appendChild(t.content.cloneNode(true));
    pworld.style.width = t.dataset.w + "px"; pworld.style.height = t.dataset.h + "px";
    document.getElementById("p-title").textContent = t.dataset.title;
    document.getElementById("p-who").textContent = t.dataset.who;
    document.getElementById("p-sum").textContent = t.dataset.sum;
    pz.setSize(+t.dataset.w, +t.dataset.h);
    if (dlg.showModal && !dlg.open) dlg.showModal(); else dlg.setAttribute("open", "");
    requestAnimationFrame(() => { pz.fit(); pview.focus(); });
  }
  document.querySelectorAll("[data-proc]").forEach(b => b.addEventListener("click", () => openProc(b.dataset.proc)));
  document.getElementById("p-close").onclick = () => dlg.close ? dlg.close() : dlg.removeAttribute("open");
  document.getElementById("p-fit").onclick = pz.fit;
  document.getElementById("p-in").onclick = pz.zoomIn;
  document.getElementById("p-out").onclick = pz.zoomOut;
  window.addEventListener("resize", () => { if (dlg.open) pz.fit(); });
  window.openProc = openProc;
})();
</script>
