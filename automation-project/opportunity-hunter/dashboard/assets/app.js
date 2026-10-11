/* Opportunity Hunter dashboard. Vanilla JS, no deps. All numbers come from /api. */
const API = '';
const $ = id => document.getElementById(id);
const esc = s => String(s == null ? '' : s).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
const STATUSES = ['NEW', 'REVIEWING', 'INTERESTED', 'APPLIED', 'CONTACTED', 'REPLIED', 'WON', 'LOST', 'REJECTED', 'ARCHIVED'];
const state = { view: 'dash', opp: { page: 1, q: '', status: '', category: '', source: '', min_score: '', sort: 'opportunity_score' }, detail: null };

async function api(path, opts) {
  const r = await fetch(API + path, opts);
  if (!r.ok) throw new Error('API ' + r.status);
  return r.json();
}
function scoreCls(s) { return s >= 70 ? 'hi' : (s >= 40 ? 'mid' : 'lo'); }
function show(view) {
  state.view = view;
  document.querySelectorAll('nav button').forEach(b => b.classList.toggle('on', b.dataset.v === view));
  document.querySelectorAll('.view').forEach(v => v.style.display = v.id === 'v-' + view ? '' : 'none');
  ({ dash: loadDash, opps: loadOpps, money: loadMoney, sources: loadSources, runs: loadRuns })[view]();
}
async function loadDash() {
  const s = await api('/api/stats');
  const el = $('dashCards');
  el.innerHTML = [['Total', s.total], ['New', s.new], ['Today', s.today], ['This week', s.week],
    ['Avg score', s.avg_score], ['Applied', s.by_status.APPLIED || 0], ['Won', s.by_status.WON || 0], ['Lost', s.by_status.LOST || 0]]
    .map(([k, v]) => `<div class="card"><div class="v">${v}</div><div class="k">${k}</div></div>`).join('');
  const f = ['NEW', 'INTERESTED', 'APPLIED', 'WON'].map(k => `<span class="st">${k}: <b>${s.by_status[k] || 0}</b></span>`).join('<span class="arw">→</span>');
  $('funnel').innerHTML = `<div class="funnel">${f}</div>`;
  $('dashSrc').innerHTML = '<table><tr><th>Source</th><th>Count</th></tr>' +
    Object.entries(s.by_source).map(([k, v]) => `<tr><td>${esc(k)}</td><td>${v}</td></tr>`).join('') + '</table>';
  $('dashCat').innerHTML = '<table><tr><th>Category</th><th>Count</th></tr>' +
    Object.entries(s.by_category).map(([k, v]) => `<tr><td>${esc(k)}</td><td>${v}</td></tr>`).join('') + '</table>';
}
function oppQuery() {
  const o = state.opp, p = new URLSearchParams({ page: o.page, per_page: 20, sort: o.sort });
  ['q', 'status', 'category', 'source'].forEach(k => { if (o[k]) p.set(k === 'q' ? 'q' : k, o[k]); });
  if (o.min_score) p.set('min_score', o.min_score);
  return '/api/opportunities?' + p.toString();
}
async function loadOpps() {
  const d = await api(oppQuery());
  const rows = d.items.map(o => `<tr>
    <td><a href="#" data-open="${o.id}">${esc(o.title.slice(0, 80))}</a><br><small style="color:var(--muted)">${esc(o.company_name)} · ${esc(o.source)}</small></td>
    <td>${esc(o.service_category)}</td><td>${o.budget_max ? '$' + o.budget_max : (o.budget_type !== 'UNKNOWN' ? esc(o.budget_type) : '—')}</td>
    <td><span class="score ${scoreCls(o.opportunity_score)}">${o.opportunity_score}</span></td>
    <td><span class="pill ${o.status}">${o.status}</span></td>
    <td><small>${esc((o.posted_at || '').slice(0, 10))}</small></td></tr>`).join('');
  $('oppTable').innerHTML = `<table><tr><th>Title</th><th>Category</th><th>Budget</th><th>Score</th><th>Status</th><th>Posted</th></tr>${rows || '<tr><td colspan=6>No results</td></tr>'}</table>
    <div class="pager"><button class="btn ghost" id="pgPrev" ${d.page <= 1 ? 'disabled' : ''}>‹ Prev</button><span>Page ${d.page} of ${Math.max(1, Math.ceil(d.total / d.per_page))} (${d.total})</span><button class="btn ghost" id="pgNext">Next ›</button></div>`;
  $('pgPrev').onclick = () => { state.opp.page--; loadOpps(); };
  $('pgNext').onclick = () => { state.opp.page++; loadOpps(); };
  document.querySelectorAll('[data-open]').forEach(a => a.onclick = e => { e.preventDefault(); openDetail(a.dataset.open); });
}
async function openDetail(id) {
  const o = await api('/api/opportunities/' + id);
  state.detail = o;
  const why = [['service_match', o.service_match_score, 30], ['budget', o.budget_score, 20], ['freshness', o.freshness_score, 15],
    ['clarity', o.clarity_score, 15], ['remote', o.remote_score, 10], ['client', o.client_signal_score, 10],
    ['missing_penalty', -o.missing_penalty, 0], ['risk_penalty', -o.risk_penalty, 0]]
    .map(([k, v]) => `${k}: ${v}`).join('\n');
  $('sheet').innerHTML = `<h2>${esc(o.title)}</h2>
    <p><span class="pill ${o.status}">${o.status}</span> <span class="score ${scoreCls(o.opportunity_score)}">${o.opportunity_score}</span>
    <a href="${esc(o.url)}" target="_blank" rel="noopener"><button class="btn">Open Original ↗</button></a></p>
    <div class="kv">
    <b>Source</b><span>${esc(o.source)} · ${esc(o.posted_at || 'UNKNOWN')}</span>
    <b>Category</b><span>${esc(o.service_category)}</span>
    <b>Budget</b><span>${esc(o.budget_type)} ${o.budget_min || ''} ${o.budget_max || ''} ${esc(o.budget_currency)}</span>
    <b>Deadline</b><span>${esc(o.deadline_text)}</span>
    <b>Client/Company</b><span>${esc(o.company_name)} / ${esc(o.client_name)} (${esc(o.client_type)})</span>
    <b>Skills</b><span>${esc((o.skills || []).join(', '))}</span>
    <b>Tech</b><span>${esc((o.technologies || []).join(', '))}</span>
    <b>Remote</b><span>${o.remote === 1 ? 'yes' : (o.remote === 0 ? 'no' : 'UNKNOWN')}</span>
    <b>Confidence</b><span>${o.confidence_score}</span>
    <b>AI</b><span>${esc(o.ai_mode)}</span>
    <b>Discovered</b><span>${esc(o.discovered_at)}</span>
    <b>Fingerprint</b><span><small>${esc(o.fingerprint.slice(0, 16))}…</small></span></div>
    <h3>Description</h3><p style="white-space:pre-wrap">${esc(o.description.slice(0, 3000))}</p>
    <h3>Why this score?</h3><pre class="why">${esc(why)}</pre>
    <h3>Status</h3><div>${STATUSES.map(s => `<button class="stbtn ${s === o.status ? 'on' : ''}" data-st="${s}">${s}</button>`).join('')}</div>
    <h3>Notes</h3><div id="notes">${(o.notes || []).map(n => `<div class="note">${esc(n.body)}<br><small>${esc(n.created_at)}</small></div>`).join('') || '<small>No notes</small>'}</div>
    <div class="toolbar"><input id="noteIn" placeholder="Add a note…" style="flex:1"><button class="btn" id="noteAdd">Add</button></div>
    <h3>History</h3>${(o.history || []).map(h => `<div class="note">${esc(h.old_status)} → ${esc(h.new_status)}<br><small>${esc(h.changed_at)} ${esc(h.note || '')}</small></div>`).join('') || '<small>No changes</small>'}`;
  $('modal').classList.add('open');
  document.querySelectorAll('[data-st]').forEach(b => b.onclick = async () => {
    await api('/api/opportunities/' + id + '/status', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ status: b.dataset.st }) });
    openDetail(id); loadOpps();
  });
  $('noteAdd').onclick = async () => {
    const v = $('noteIn').value.trim();
    if (!v) return;
    await api('/api/opportunities/' + id + '/notes', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ body: v }) });
    openDetail(id);
  };
}
async function loadMoney() {
  const d = await api('/api/opportunities?status=NEW&sort=opportunity_score&per_page=15');
  const withBudget = d.items.filter(o => o.budget_max).slice(0, 10);
  constReviewed = await api('/api/opportunities?status=INTERESTED&sort=opportunity_score&per_page=15');
  const row = o => `<tr><td><a href="#" data-open="${o.id}">${esc(o.title.slice(0, 70))}</a></td><td>${esc(o.service_category)}</td><td><span class="score ${scoreCls(o.opportunity_score)}">${o.opportunity_score}</span></td></tr>`;
  $('moneyNew').innerHTML = '<table><tr><th>Top unreviewed</th><th>Cat</th><th>Score</th></tr>' + d.items.map(row).join('') + '</table>';
  $('moneyBudget').innerHTML = '<table><tr><th>With budget</th><th>Budget</th><th>Score</th></tr>' + withBudget.map(o => `<tr><td><a href="#" data-open="${o.id}">${esc(o.title.slice(0, 70))}</a></td><td>$${o.budget_max}</td><td><span class="score ${scoreCls(o.opportunity_score)}">${o.opportunity_score}</span></td></tr>`).join('') + '</table>';
  $('moneyInt').innerHTML = '<table><tr><th>Interested</th><th>Cat</th><th>Score</th></tr>' + withReviewed.items.map(row).join('') + '</table>';
  document.querySelectorAll('[data-open]').forEach(a => a.onclick = e => { e.preventDefault(); openDetail(a.dataset.open); });
}
async function loadSources() {
  const s = await api('/api/sources');
  $('srcTable').innerHTML = '<table><tr><th>Source</th><th>Status</th><th>Last run</th><th>Last success</th><th>Found</th><th>Added</th><th>Errors</th></tr>' +
    s.map(r => `<tr><td>${esc(r.source)}</td><td class="${r.status === 'success' ? 'ok' : (r.status === 'failed' ? 'bad' : 'warn')}">${esc(r.status)}</td><td><small>${esc(r.last_run || '—')}</small></td><td><small>${esc(r.last_success || '—')}</small></td><td>${r.found}</td><td>${r.added}</td><td>${r.errors}</td></tr>`).join('') + '</table>';
}
async function loadRuns() {
  const r = await api('/api/runs?limit=20');
  $('runTable').innerHTML = '<table><tr><th>ID</th><th>Started</th><th>Status</th><th>Found</th><th>New</th><th>Dups</th><th>Errors</th></tr>' +
    r.map(x => `<tr><td><a href="#" data-run="${x.id}">#${x.id}</a></td><td><small>${esc(x.started_at || '')}</small></td><td class="${x.status === 'success' ? 'ok' : (x.status === 'failed' ? 'bad' : 'warn')}">${esc(x.status)}</td><td>${x.items_found}</td><td>${x.items_added}</td><td>${x.duplicates}</td><td>${x.errors}</td></tr>`).join('') + '</table><div id="runDetail"></div>';
  document.querySelectorAll('[data-run]').forEach(a => a.onclick = async e => {
    e.preventDefault();
    const d = await api('/api/runs/' + a.dataset.run);
    $('runDetail').innerHTML = '<h3>Run #' + d.id + '</h3><table><tr><th>Source</th><th>Status</th><th>Found</th><th>Added</th><th>Error</th></tr>' +
      d.sources.map(s => `<tr><td>${esc(s.source)}</td><td>${esc(s.status)}</td><td>${s.items_found}</td><td>${s.items_added}</td><td><small>${esc(s.error_message || '')}</small></td></tr>`).join('') + '</table>';
  });
}
async function runNow() {
  const btn = $('runBtn');
  btn.disabled = true; btn.textContent = 'Running…';
  try {
    const r = await api('/api/run', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{}' });
    alert('Run #' + r.run_id + ': ' + r.status + ' — found ' + r.found + ', new ' + r.added + ', errors ' + r.errors);
    show(state.view);
  } catch (e) { alert('Run failed: ' + e.message); }
  btn.disabled = false; btn.textContent = 'Run now';
}
window.addEventListener('DOMContentLoaded', () => {
  document.querySelectorAll('nav button').forEach(b => b.onclick = () => show(b.dataset.v));
  $('modal').onclick = e => { if (e.target.id === 'modal') $('modal').classList.remove('open'); };
  ['fQ', 'fStatus', 'fCat', 'fSrc', 'fScore'].forEach(id => $('' + id).addEventListener('input', () => {
    state.opp.q = $('fQ').value; state.opp.status = $('fStatus').value; state.opp.category = $('fCat').value;
    state.opp.source = $('fSrc').value; state.opp.min_score = $('fScore').value; state.opp.page = 1; loadOpps();
  }));
  $('runBtn').onclick = runNow;
  api('/api/categories').then(c => { $('fCat').innerHTML = '<option value="">All categories</option>' + c.map(x => `<option>${esc(x)}</option>`).join(''); });
  show('dash');
});
