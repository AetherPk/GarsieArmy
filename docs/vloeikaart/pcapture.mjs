// Screenshots of the real app (sample data, no account, no server writes)
// plus where each numbered button is, for the flow document.
import { spawn } from "node:child_process";
import { mkdtempSync, writeFileSync, readFileSync, mkdirSync } from "node:fs";
import { tmpdir } from "node:os"; import { join, dirname } from "node:path"; import { fileURLToPath } from "node:url";
const here = dirname(fileURLToPath(import.meta.url));
const SCREENS = JSON.parse(readFileSync(join(here, "procs.json"), "utf8")).shots;
mkdirSync(join(here, "vec"), { recursive: true });
const W = 390;
const proc = spawn("C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe", ["--headless=new", "--remote-debugging-port=9364", `--user-data-dir=${mkdtempSync(join(tmpdir(), "doc-"))}`, "about:blank"], { stdio: "ignore" });
const sleep = ms => new Promise(r => setTimeout(r, ms)); await sleep(5000);
const page = (await (await fetch("http://127.0.0.1:9364/json")).json()).find(t => t.type === "page");
const ws = new WebSocket(page.webSocketDebuggerUrl); let id = 0; const pend = new Map(); const ex = [];
ws.onmessage = m => { const d = JSON.parse(m.data); if (d.id && pend.has(d.id)) { pend.get(d.id)(d); pend.delete(d.id); } if (d.method === "Runtime.exceptionThrown") ex.push(d.params.exceptionDetails.exception?.description); };
await new Promise(r => ws.onopen = r);
const send = (method, params = {}) => new Promise(res => { const i = ++id; pend.set(i, res); ws.send(JSON.stringify({ id: i, method, params })); });
const ev = async e => { const r = await send("Runtime.evaluate", { expression: e, returnByValue: true, awaitPromise: true }); if (r.result.exceptionDetails) throw new Error(r.result.exceptionDetails.exception?.description || r.result.exceptionDetails.text); return r.result.result?.value; };
await send("Runtime.enable"); await send("Page.enable");
await send("Emulation.setTouchEmulationEnabled", { enabled: true, maxTouchPoints: 5 });
await send("Emulation.setDeviceMetricsOverride", { width: W, height: 844, deviceScaleFactor: 2, mobile: true });
await send("Page.navigate", { url: "http://localhost:8765/garsie-army-prototype.html" });
await sleep(4000);

await ev(`(() => {
  const ok = d => Promise.resolve({ data:d, error:null });
  const chain = () => { const c = { select(){return c}, eq(){return c}, order(){return c}, limit(){return c}, range(){ return ok([]); }, insert(){return c}, update(){return c}, delete(){return c}, single(){return c}, maybeSingle(){return c}, then(f){ return ok(null).then(f); } }; return c; };
  Object.assign(sb, { from: chain, rpc: (name) => { const c = chain(); if (name === "qr_tokens"){ const w = currentWindow(); c.then = f => ok(Array.from({length:12}, (_, i) => ({ win:w + i - 1, token:"2." + (w + i - 1) + ".voorbeeld" }))).then(f); return c; }
      c.then = f => ok(name === "admin_search_people" ? [
      { user_id:"p1", name:"Pieter", surname:"Botha", grade:"Graad 11", gender:"Seun", email:"pieter.botha@voorbeeld.co.za" },
      { user_id:"p2", name:"Pieta", surname:"Smit", grade:"Graad 9", gender:"Meisie", email:"pieta.smit@voorbeeld.co.za" }] : null).then(f); return c; } });
  window.MEMBERS = [
    { user_id:"p1", name:"Pieter", surname:"Botha", grade:"Graad 11", gender:"Seun", email:"pieter.botha@voorbeeld.co.za" },
    { user_id:"m2", name:"Johan", surname:"du Plessis", grade:"Graad 12", gender:"Seun", email:"johan.dp@voorbeeld.co.za" },
    { user_id:"m3", name:"Ruan", surname:"Venter", grade:"Graad 11", gender:"Seun", email:"ruan.v@voorbeeld.co.za" }];
  const loc = { lat:-25.7972578, lng:28.305468, radius:250, address:"Hoërskool Garsfontein" };
  const ev = (id, title, dept, group, date, start, end, venue, extra = {}) => ({ id, title, department:dept, group, date, start, end, venue, description:"", ticketUrl:null, location:loc, audience:{ grades:[], gender:"all", learnersOnly:false }, inviteOnly:false, ...extra });
  DEPARTMENTS = [{ id:"d1", name:"Sport", colour:"#3fae7a" }, { id:"d2", name:"Kultuur", colour:"#9b7fd4" }, { id:"d3", name:"Akademie", colour:"#c9a23f" }];
  GROUPS = [{ id:"g1", department:"d1", name:"Rugby", open:true }, { id:"g2", department:"d1", name:"Eerste span", open:false }, { id:"g4", department:"d1", name:"Netbal", open:true },
            { id:"g3", department:"d2", name:"Koor", open:true }, { id:"g5", department:"d3", name:"Wiskunde-olimpiade", open:true }];
  window.ALL_EVENTS = [
    ev(1, "Rugby: Garsies teen Affies", "d1", "g1", "2026-10-10", "14:00", "16:00", "Hoofveld"),
    ev(2, "Spanete: Eerste span", "d1", "g2", "2026-10-16", "18:00", "20:00", "Saal", { inviteOnly:true }),
    ev(3, "Koorkonsert", "d2", "g3", "2026-10-08", "18:30", "20:30", "Saal"),
    ev(4, "Wiskunde-olimpiade", "d3", "g5", "2026-10-07", "09:00", "11:00", "Mediasentrum", { audience:{ grades:["Graad 10","Graad 11"], gender:"all", learnersOnly:true } }),
    ev(5, "Netbal: Garsies teen Menlo", "d1", "g4", "2026-10-09", "15:00", "16:30", "Netbalbane"),
    ev(6, "Revue-oudisies", "d2", null, "2026-10-21", "14:00", "17:00", "Teater"),
    ev(7, "Prysuitdeling", "d3", null, "2026-10-29", "18:00", "20:00", "Saal")];
  state.loading = false; state.session = { user:{ id:"u1" } }; state.needsProfile = false; state.needsConsent = false;
  state.push = { status:"off", busy:false }; state.pushOffered = true; state.installOffered = true;
  window.asLearner = () => {
    localStorage.setItem("garsie.calSeen", JSON.stringify("u1"));
    state.user = { id:"u1", email:"jan.smit@voorbeeld.co.za", name:"Jan", surname:"Smit", grade:"Graad 11", gender:"Seun", role:"user", department:null };
    EVENTS = ALL_EVENTS; INVITES = { 2:"pending" }; state.supported = new Set([1, 3]);
    INBOX = [{ id:3, eventId:null, kind:"group", title:"Jy is bygevoeg by Eerste span", body:"Sport · Jy hoor nou van geleenthede vir hierdie groep.", at:"2026-10-09T17:40:00", read:false },
             { id:1, eventId:6, kind:"new", title:"Nuwe geleentheid: Revue-oudisies", body:"Wo 21 Okt om 14:00 · Teater", at:"2026-10-09T08:15:00", read:false },
             { id:2, eventId:null, kind:"cancelled", title:"Gekanselleer: Hokkie teen Waterkloof", body:"Die geleentheid op Vr 9 Okt om 14:00 gaan nie meer voort nie.", at:"2026-10-08T12:00:00", read:true }];
    state.myGroups = new Set(["g2", "g1"]); state.unfollowed = new Set(["d3"]);
    Object.assign(state, { settingsOpen:false, settingsPage:null, openEventId:null, inviteEventId:null, manageGroupId:null, filter:"Alles" });
  };
  const admin = (role, dept) => {
    localStorage.setItem("garsie.calSeen", JSON.stringify("a1"));
    state.user = { id:"a1", email:"admin@garsies.co.za", name:"Anna", surname:"Admin", grade:"Alumni", gender:"", role, department:dept };
    EVENTS = ALL_EVENTS; INVITES = {}; INBOX = []; state.supported = new Set(); state.myGroups = new Set(); state.unfollowed = new Set();
    STATS = { 1:{ supporters:142, checkedIn:118, suspicious:2, invited:0, accepted:0, declined:0 }, 2:{ supporters:19, checkedIn:0, suspicious:0, invited:24, accepted:19, declined:3 } };
    GROUP_STATS = { "dept:d1":1840, g1:212, g2:24, g4:96, "dept:d2":1795, g3:58, "dept:d3":1810, g5:41 };
    ADMINS = [{ email:"admin@garsies.co.za", role:"key", department:null }, { email:"sport@garsies.co.za", role:"dept", department:"d1" }, { email:"kultuur@garsies.co.za", role:"dept", department:"d2" }];
    Object.assign(state, { settingsOpen:false, settingsPage:null, openEventId:null, inviteEventId:null, manageGroupId:null, filter:"Alles" });
  };
  window.asDept = () => admin("dept", "d1");
  window.asKey = () => admin("key", null);
  return "ready";
})()`);


const out = [];
const measure = sels => ev(`(() => ${JSON.stringify(sels)}.map(sel => {
    let el = document.querySelector(sel);
    if (!el) return null;
    if (el.tagName === "INPUT" && (el.type === "checkbox" || el.type === "radio")) el = el.name === "grades" ? el.closest(".check-row") : el.closest("label");
    const r = el.getBoundingClientRect();
    if (r.width === 0 || r.bottom < 0 || r.top > innerHeight) return null;
    return { x:Math.max(0, r.left), y:Math.max(0, r.top), w:r.width, h:r.height };
  }))()`);
const prep = async (s, h) => {
  await send("Emulation.setDeviceMetricsOverride", { width: W, height: h, deviceScaleFactor: 2, mobile: true });
  await ev(`(() => { if (!document.getElementById("pdf-fix")) document.head.insertAdjacentHTML("beforeend", "<style id=pdf-fix>[style*=repeating-linear-gradient]{background:none !important}</style>"); document.querySelectorAll("#install-help,#push-ask,#delete-account").forEach(n => n.remove()); if (state.preview) endPreview();
    state.loading = false; state.fatal = null; state.needsProfile = false; state.needsConsent = false; state.session = { user:{ id:"u1" } };
    state.auth = { mode:"signin", step:"details", draft:{} }; state.push = { status:"off", busy:false }; geo.status = "idle"; geo.pos = null; CHECKINS = {};
    ${s.setup} render(); ${s.post || ""} return 1; })()`);
  await sleep(s.wait || 700);
  if (false) await ev(`(() => { const d = document.querySelector(${JSON.stringify(s.open)}); if (d) d.open = true; return 1; })()`);
  if (s.type) { await ev(`(() => { const i = document.querySelector(${JSON.stringify(s.type[0])}); i.value = ${JSON.stringify(s.type[1])}; i.dispatchEvent(new Event("input", { bubbles:true })); return 1; })()`); await sleep(700); }
  await sleep(300);
};
for (const s of SCREENS) {
  let h = 844;
  await prep(s, h);
  if (s.full) {
    const need = await ev(`Math.max(0, ...[...document.querySelectorAll(".panel, .auth")].map(p => p.scrollHeight))`);
    if (need + 10 > h) { h = Math.ceil(need + 10); await prep(s, h); }
  }
  const rects = await measure(s.sels);
  const links = [];
  await send("Emulation.setEmulatedMedia", { media: "screen" });
  const pdf = await send("Page.printToPDF", { printBackground: true, paperWidth: W / 96, paperHeight: h / 96, marginTop: 0, marginBottom: 0, marginLeft: 0, marginRight: 0, pageRanges: "1" });
  writeFileSync(join(here, "vec", s.id + ".pdf"), Buffer.from(pdf.result.data, "base64"));
  out.push({ id: s.id, w: W, h, rects: Object.fromEntries(s.sels.map((sel, i) => [sel, rects[i]])) });
  console.log(s.id, h, rects.map((r, i) => r ? "" : "MISSING:" + s.sels[i]).filter(Boolean).join(" "));
}
writeFileSync(join(here, "prects.json"), JSON.stringify(out));
console.log("exceptions", JSON.stringify(ex));
proc.kill(); process.exit(0);
