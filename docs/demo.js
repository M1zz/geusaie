// 그사이에 웹 체험: 알리오 올리오 한 판을 빠르게 돌려 본다.
// 규칙은 앱과 같다. 단계와 시간은 Recipes.swift, 시간표는 Models.swift 의 Plan,
// 지금 할 일 · 다음 · 틱은 CookSession 의 dueAction · advance · tick 을 그대로 옮겼다. 글은 앱의 번역(T.app)이다.
(() => {
  const root = document.getElementById("demo");
  if (!root) return;
  const T = JSON.parse(root.dataset.text), A = T.app;
  const SPEED = 20;                                   // 1초에 20초가 흐른다
  const S = (id, emoji, role, duration, trigger = null, deadline = false) =>
    ({ id, emoji, role, duration, trigger, deadline, name: A.names[id] });
  const chains = [
    [S("ao-water-on", "🔥", "action", 15), S("ao-boil", "💧", "cook", 285), S("ao-drop", "⬇️", "action", 10),
     S("ao-pasta", "🍝", "cook", 470), S("ao-reserve", "🥣", "action", 20, null, true)],
    [S("ao-garlic", "🍳", "action", 320, ["end", "ao-reserve"], true), S("ao-toss", "🌀", "action", 120, ["after", "ao-reserve"], true)],
  ];
  const preps = [S("ao-prep", "🧑‍🍳", "prep", 60), S("ao-slice", "🧄", "prep", 120),
                 S("ao-pepper", "🌶️", "prep", 105), S("ao-cheese", "🧀", "prep", 130)];
  const steps = [...preps, ...chains.flat()];
  const fmt = (s, ...v) => v.reduce((t, x) => t.replace("%@", x), s);
  const clock = s => `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;

  let st, phase, timer;
  const reset = () => { st = { now: 0, startedAt: {}, doneAt: {}, progress: {} }; phase = "ready"; clearInterval(timer); };

  // Plan: 냄비 사슬은 냄비 시계대로, 도마 일은 손이 비는 틈에 끼워 넣는다.
  function plan() {
    const sp = {}, now = st.now;
    const leadUp = (chain, i) => {
      let total = chain[i].duration;
      for (const s of chain.slice(i + 1)) { if (s.trigger) break; total += s.duration; }
      return total;
    };
    const planChain = chain => {
      const out = {}; let cursor = null;
      for (const [i, s] of chain.entries()) {
        let earliest = 0;
        if (s.trigger) {
          const ref = sp[s.trigger[1]] || out[s.trigger[1]];
          if (!ref) return null;
          earliest = s.trigger[0] === "after" ? ref.end : Math.max(0, ref.start - leadUp(chain, i));
        }
        let start = Math.max(earliest, cursor ?? earliest), end;
        if (st.doneAt[s.id] != null) { start = st.startedAt[s.id] ?? Math.max(0, st.doneAt[s.id] - s.duration); end = st.doneAt[s.id]; }
        else if (st.startedAt[s.id] != null) {
          start = st.startedAt[s.id];
          end = s.role === "cook" ? start + s.duration : Math.max(start + s.duration, now);
        } else { start = Math.max(start, now); end = start + s.duration; }
        out[s.id] = { start, end }; cursor = end;
      }
      return out;
    };
    let pending = chains;
    for (let pass = 0; pending.length && pass <= chains.length + 1; pass++) {
      const stuck = pending.filter(c => { const p = planChain(c); if (p) Object.assign(sp, p); return !p; });
      if (stuck.length === pending.length) break;
      pending = stuck;
    }
    const busy = steps.filter(s => s.role === "action" && sp[s.id]).map(s => [sp[s.id].start, sp[s.id].end]).sort((a, b) => a[0] - b[0]);
    const block = t => busy.find(b => b[0] <= t && t < b[1]);
    let cursor = now, b;
    for (const p of preps) {
      if (st.doneAt[p.id] != null) { sp[p.id] = { start: st.startedAt[p.id] ?? st.doneAt[p.id] - p.duration, end: st.doneAt[p.id] }; continue; }
      let left = Math.max(0, p.duration - (st.progress[p.id] || 0)), t = Math.max(cursor, now);
      while ((b = block(t))) t = b[1];
      const began = st.startedAt[p.id] ?? t;
      while (left > 0) {
        if ((b = block(t))) { t = b[1]; continue; }
        const nb = busy.find(x => x[0] > t), free = Math.min((nb ? nb[0] : Infinity) - t, left);
        t += free; left -= free;
      }
      sp[p.id] = { start: began, end: t }; cursor = t;
    }
    return sp;
  }

  // 지금 차례가 된 냄비 동작. 늦으면 상하는 것부터, 그다음은 먼저 차례가 온 것부터.
  function due(sp) {
    const list = [];
    chains.forEach(c => c.forEach((s, i) => {
      if (s.role !== "action" || st.doneAt[s.id] != null) return;
      if (i > 0 && st.doneAt[c[i - 1].id] == null) return;
      if (sp[s.id].start <= st.now) list.push(s);
    }));
    return list.sort((a, b) => a.deadline === b.deadline ? sp[a.id].start - sp[b.id].start : (a.deadline ? -1 : 1))[0];
  }
  const currentPrep = () => preps.find(p => st.doneAt[p.id] == null);
  const running = () => steps.filter(s => s.role === "cook" && st.startedAt[s.id] != null && st.doneAt[s.id] == null);
  const handsDone = () => steps.every(s => s.role === "cook" || st.doneAt[s.id] != null);
  const finishIfDone = () => { if (handsDone() && !running().length) { phase = "done"; clearInterval(timer); } };

  function tick() {
    st.now++;
    for (const c of running()) if (st.now >= st.startedAt[c.id] + c.duration) st.doneAt[c.id] = st.startedAt[c.id] + c.duration;
    const prep = currentPrep();
    if (prep && !due(plan())) {                       // 손이 빌 때만 도마 일이 는다
      st.startedAt[prep.id] ??= st.now;
      st.progress[prep.id] = Math.min(prep.duration, (st.progress[prep.id] || 0) + 1);
    }
    finishIfDone(); render();
  }

  function next() {                                   // CookSession.advance()
    const sp = plan(), d = due(sp);
    if (d) {
      st.doneAt[d.id] = st.now; st.startedAt[d.id] ??= sp[d.id].start;
      const c = chains.find(c => c.includes(d)), after = c[c.indexOf(d) + 1];
      if (after && after.role === "cook") st.startedAt[after.id] = st.now;   // 지금부터 냄비가 돈다
    } else {
      const prep = currentPrep();
      if (prep) { st.doneAt[prep.id] = st.now; st.startedAt[prep.id] ??= st.now; }
    }
    finishIfDone(); render();
  }

  root.innerHTML = `
    <div class="gs-card" aria-live="polite"><p class="gs-head"></p><p class="gs-title"></p>
      <div class="gs-bar" aria-hidden="true"><i></i></div><p class="gs-sub"></p></div>
    <div class="gs-side">
      <div class="gs-pots">${chains.map((_, i) => `<div class="gs-pot"><span class="gs-lane">${A.lanes[i]}</span>
        <b></b><span class="gs-left"></span><div class="gs-bar" aria-hidden="true"><i></i></div></div>`).join("")}</div>
      <div class="gs-controls"><span class="gs-clock" aria-label="${A.elapsed}">⏱ <b>0:00</b></span>
        <button type="button" class="gs-go"></button></div>
      <p class="muted small">${T.note}</p>
    </div>`;
  const $ = s => root.querySelector(s), card = $(".gs-card"), go = $(".gs-go");
  const pots = [...root.querySelectorAll(".gs-pot")];
  const label = s => `${s.emoji} ${s.name}`;

  function render() {
    const sp = plan(), d = phase === "running" && due(sp), prep = currentPrep();
    let head, title, sub = "", fill = null, mood = "calm";
    if (phase === "ready") { head = A.first; title = label(chains[0][0]); sub = A.startHint; }
    else if (phase === "done") { head = A.now; title = A.ready; mood = "finished"; }
    else if (d) {
      const late = d.deadline && st.now > sp[d.id].start + d.duration;
      head = late ? A.late : d.deadline ? A.nowCant : A.now; title = label(d);
      mood = late ? "late" : d.deadline ? "now" : "soon";
      if (prep && st.progress[prep.id] > 0) sub = fmt(A.resume, prep.emoji, prep.name);
    } else if (prep) {
      head = A.calm; title = label(prep); fill = (st.progress[prep.id] || 0) / prep.duration;
      const up = steps.filter(s => s.role === "action" && st.doneAt[s.id] == null && sp[s.id].start > st.now)
        .sort((a, b) => sp[a.id].start - sp[b.id].start)[0] || preps.find(p => p !== prep && st.doneAt[p.id] == null);
      sub = fill >= 1 ? A.saidNext : up ? fmt(A.upNext, up.emoji, up.name) : "";
    } else { head = A.now; title = A.handsDone; }
    card.dataset.mood = mood;
    $(".gs-head").textContent = head; $(".gs-title").textContent = title; $(".gs-sub").textContent = sub;
    $(".gs-card .gs-bar").hidden = fill == null; $(".gs-card .gs-bar i").style.width = `${(fill || 0) * 100}%`;
    pots.forEach((el, i) => {
      const chain = chains[i], cook = chain.find(s => running().includes(s));
      const left = cook ? cook.duration - (st.now - st.startedAt[cook.id]) : 0;
      el.dataset.kind = cook ? "cooking" : d && chain.includes(d) ? "hands" : "";
      el.querySelector("b").textContent = phase === "ready" ? A.empty : cook ? A.progress[cook.id]
        : d && chain.includes(d) ? A.onIt : chain.every(s => st.doneAt[s.id] != null) ? A.finished : A.empty;
      el.querySelector(".gs-left").textContent = cook ? clock(left) : "";
      el.querySelector("i").style.width = cook ? `${left / cook.duration * 100}%` : "0";
    });
    $(".gs-clock b").textContent = clock(st.now);
    go.textContent = phase === "ready" ? `▶ ${A.start}` : phase === "done" ? `↺ ${T.again}` : `→ ${A.next}`;
  }

  go.addEventListener("click", () => {
    if (phase === "ready") { phase = "running"; timer = setInterval(tick, 1000 / SPEED); render(); }
    else if (phase === "done") { reset(); render(); }
    else next();
  });
  reset(); render();
})();
