"""Local-first HTTP API + static dashboard. Stdlib only (http.server + sqlite3)."""
import json
import os
import re
import urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from . import collector, db

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB_PATH = os.environ.get('OH_DB', os.path.join(BASE, 'database', 'opps.db'))
CONFIG_PATH = os.environ.get('OH_CONFIG', os.path.join(BASE, 'config', 'app.json'))
DASH_DIR = os.path.join(BASE, 'dashboard')
STATUSES = sorted(collector.STATUSES)
FILTERABLE = {'status', 'service_category', 'source'}
SORTABLE = {'opportunity_score': 'opportunity_score DESC', 'posted_at': 'posted_at DESC',
            'created_at': 'id DESC', 'budget_max': 'budget_max DESC'}


def load_config():
    with open(CONFIG_PATH, 'r', encoding='utf-8') as fh:
        return json.load(fh)


def row_dict(r):
    d = dict(r)
    for k in ('skills', 'technologies', 'topics', 'raw_data'):
        try:
            d[k] = json.loads(d[k]) if isinstance(d[k], str) else (d[k] or [])
        except (ValueError, TypeError):
            d[k] = []
    return d


class Handler(BaseHTTPRequestHandler):
    server_version = 'OpportunityHunter/0.1'

    def log_message(self, *args):
        pass

    def _send(self, code, obj, ctype='application/json'):
        body = obj if isinstance(obj, bytes) else (obj.encode('utf-8') if isinstance(obj, str) else json.dumps(obj).encode('utf-8'))
        self.send_response(code)
        self.send_header('Content-Type', ctype)
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _err(self, code, msg):
        self._send(code, {'error': msg})

    def _body(self, limit=1 << 20):
        try:
            n = int(self.headers.get('Content-Length') or 0)
        except ValueError:
            n = 0
        if n <= 0 or n > limit:
            return {}
        try:
            return json.loads(self.rfile.read(n).decode('utf-8'))
        except (ValueError, UnicodeDecodeError):
            return {}

    def do_GET(self):
        try:
            parsed = urllib.parse.urlparse(self.path)
            path = parsed.path.rstrip('/') or '/'
            qs = urllib.parse.parse_qs(parsed.query)
            if path == '/api/health':
                return self._send(200, {'status': 'ok', 'version': '0.1.0'})
            if path == '/api/stats':
                return self._send(200, stats())
            if path == '/api/sources':
                return self._send(200, sources())
            if path == '/api/categories':
                return self._send(200, categories())
            if path == '/api/runs':
                return self._send(200, runs_list(int((qs.get('limit') or ['20'])[0])))
            m = re.match(r'^/api/runs/(\d+)$', path)
            if m:
                return self._send(200, run_detail(int(m.group(1))))
            if path == '/api/opportunities':
                return self._send(200, opportunities(qs))
            m = re.match(r'^/api/opportunities/(\d+)$', path)
            if m:
                opp = opportunity(int(m.group(1)))
                return self._send(200, opp) if opp else self._err(404, 'not found')
            if path.startswith('/dashboard') or path == '/':
                return self._static('index.html')
            if path.startswith('/assets/'):
                return self._static(path[len('/assets/'):], True)
            return self._err(404, 'not found')
        except BrokenPipeError:
            pass
        except Exception as exc:  # noqa: BLE001
            self._err(500, str(exc)[:300])

    def do_POST(self):
        try:
            path = urllib.parse.urlparse(self.path).path.rstrip('/') or '/'
            if path == '/api/run':
                body = self._body()
                limits = body.get('limits') if isinstance(body, dict) else None
                sources = body.get('sources') if isinstance(body, dict) else None
                summary = collector.run_collection(DB_PATH, load_config(), triggered_by='api', source_filter=sources, limits=limits)
                code = 200 if summary['status'] in ('success', 'partial') else 502
                return self._send(code, summary)
            m = re.match(r'^/api/opportunities/(\d+)/status$', path)
            if m:
                body = self._body()
                return self._send(*set_status(int(m.group(1)), body))
            m = re.match(r'^/api/opportunities/(\d+)/archive$', path)
            if m:
                return self._send(*set_status(int(m.group(1)), {'status': 'ARCHIVED'}))
            m = re.match(r'^/api/opportunities/(\d+)/notes$', path)
            if m:
                body = self._body()
                return self._send(*add_note(int(m.group(1)), body))
            return self._err(404, 'not found')
        except BrokenPipeError:
            pass
        except Exception as exc:  # noqa: BLE001
            self._err(500, str(exc)[:300])

    def _static(self, name, assets=False):
        base = DASH_DIR if not assets else os.path.join(DASH_DIR, 'assets')
        full = os.path.normpath(os.path.join(base, name.lstrip('/')))
        if not full.startswith(os.path.normpath(DASH_DIR)) or not os.path.isfile(full):
            return self._err(404, 'not found')
        ctype = 'text/html'
        if full.endswith('.js'):
            ctype = 'application/javascript'
        elif full.endswith('.css'):
            ctype = 'text/css'
        with open(full, 'rb') as fh:
            return self._send(200, fh.read(), ctype)


def stats():
    conn = db.connect(DB_PATH)
    try:
        total = conn.execute('SELECT COUNT(*) c FROM opportunities').fetchone()['c']
        new = conn.execute("SELECT COUNT(*) c FROM opportunities WHERE status='NEW'").fetchone()['c']
        by_status = {r['status']: r['c'] for r in conn.execute('SELECT status, COUNT(*) c FROM opportunities GROUP BY status')}
        by_source = {r['source']: r['c'] for r in conn.execute('SELECT source, COUNT(*) c FROM opportunities GROUP BY source')}
        by_cat = {r['service_category']: r['c'] for r in conn.execute('SELECT service_category, COUNT(*) c FROM opportunities GROUP BY service_category')}
        avg = conn.execute('SELECT AVG(opportunity_score) a FROM opportunities').fetchone()['a']
        today = conn.execute("SELECT COUNT(*) c FROM opportunities WHERE date(discovered_at)=date('now')").fetchone()['c']
        week = conn.execute("SELECT COUNT(*) c FROM opportunities WHERE date(discovered_at)>=date('now','-7 days')").fetchone()['c']
        return {'total': total, 'new': new, 'by_status': by_status, 'by_source': by_source,
                'by_category': by_cat, 'avg_score': round(avg or 0, 1), 'today': today, 'week': week}
    finally:
        conn.close()


def sources():
    conn = db.connect(DB_PATH)
    try:
        rows = conn.execute(
            'SELECT source, status, MAX(started_at) last_run, SUM(items_found) found, SUM(items_added) added,'
            ' SUM(CASE WHEN status LIKE \'%fail%\' OR status LIKE \'%error%\' THEN 1 ELSE 0 END) errors'
            ' FROM run_sources GROUP BY source').fetchall()
        out = []
        for r in rows:
            last_ok = conn.execute(
                'SELECT MAX(finished_at) m FROM run_sources WHERE source=? AND status=?',
                (r['source'], 'success')).fetchone()['m']
            out.append({'source': r['source'], 'status': r['status'], 'last_run': r['last_run'],
                        'last_success': last_ok, 'found': r['found'] or 0, 'added': r['added'] or 0,
                        'errors': r['errors'] or 0})
        return out
    finally:
        conn.close()


def categories():
    conn = db.connect(DB_PATH)
    try:
        return sorted(r['service_category'] for r in conn.execute('SELECT DISTINCT service_category FROM opportunities'))
    finally:
        conn.close()


def runs_list(limit=20):
    conn = db.connect(DB_PATH)
    try:
        return [dict(r) for r in conn.execute('SELECT * FROM runs ORDER BY id DESC LIMIT ?', (max(1, min(limit, 100)),))]
    finally:
        conn.close()


def run_detail(rid):
    conn = db.connect(DB_PATH)
    try:
        run = conn.execute('SELECT * FROM runs WHERE id=?', (rid,)).fetchone()
        if not run:
            return {'error': 'not found'}
        out = dict(run)
        out['sources'] = [dict(r) for r in conn.execute('SELECT * FROM run_sources WHERE run_id=? ORDER BY id', (rid,))]
        return out
    finally:
        conn.close()


def opportunities(qs):
    def one(k, default=None):
        v = qs.get(k)
        return v[0] if v else default
    where, args = [], []
    for f in FILTERABLE:
        v = one(f)
        if v:
            where.append('%s=?' % f)
            args.append(v)
    for num in ('min_score', 'min_budget'):
        v = one(num)
        if v is not None:
            try:
                where.append('opportunity_score>=?' if num == 'min_score' else '(budget_max>=? OR budget_min>=?)')
                args.append(float(v))
                if num == 'min_budget':
                    args.append(float(v))
            except ValueError:
                pass
    for txt in ('q',):
        v = one(txt)
        if v:
            where.append('(title LIKE ? OR description LIKE ? OR company_name LIKE ?)')
            args += ['%' + v + '%'] * 3
    if one('since'):
        where.append("date(discovered_at)>=date(?)")
        args.append(one('since'))
    sort = SORTABLE.get(one('sort'), 'id DESC')
    page = max(1, int(one('page') or 1))
    per = max(1, min(int(one('per_page') or 20), 100))
    sql = 'SELECT * FROM opportunities'
    if where:
        sql += ' WHERE ' + ' AND '.join(where)
    conn = db.connect(DB_PATH)
    try:
        total = conn.execute('SELECT COUNT(*) c FROM (%s)' % sql, args).fetchone()['c']
        rows = conn.execute(sql + ' ORDER BY %s LIMIT ? OFFSET ?' % sort, args + [per, (page - 1) * per]).fetchall()
        return {'total': total, 'page': page, 'per_page': per, 'items': [row_dict(r) for r in rows]}
    finally:
        conn.close()


def opportunity(oid):
    conn = db.connect(DB_PATH)
    try:
        r = conn.execute('SELECT * FROM opportunities WHERE id=?', (oid,)).fetchone()
        if not r:
            return None
        out = row_dict(r)
        out['history'] = [dict(h) for h in conn.execute(
            'SELECT * FROM status_history WHERE opportunity_id=? ORDER BY id', (oid,))]
        out['notes'] = [dict(n) for n in conn.execute(
            'SELECT * FROM notes WHERE opportunity_id=? ORDER BY id', (oid,))]
        return out
    finally:
        conn.close()


def set_status(oid, body):
    st = (body.get('status') or '').upper()
    if st not in STATUSES:
        return 400, {'error': 'invalid status'}
    conn = db.connect(DB_PATH)
    try:
        r = conn.execute('SELECT status FROM opportunities WHERE id=?', (oid,)).fetchone()
        if not r:
            return 404, {'error': 'not found'}
        old = r['status']
        now = collector.now_iso()
        conn.execute('UPDATE opportunities SET status=?,updated_at=? WHERE id=?', (st, now, oid))
        conn.execute('INSERT INTO status_history (opportunity_id,old_status,new_status,changed_at,note) VALUES (?,?,?,?,?)',
                     (oid, old, st, now, str(body.get('note') or '')[:500]))
        conn.commit()
        return 200, {'id': oid, 'old': old, 'new': st}
    finally:
        conn.close()


def add_note(oid, body):
    text = str(body.get('body') or '').strip()[:2000]
    if not text:
        return 400, {'error': 'empty note'}
    conn = db.connect(DB_PATH)
    try:
        r = conn.execute('SELECT id FROM opportunities WHERE id=?', (oid,)).fetchone()
        if not r:
            return 404, {'error': 'not found'}
        cur = conn.execute('INSERT INTO notes (opportunity_id,body,created_at) VALUES (?,?,?)',
                           (oid, text, collector.now_iso()))
        conn.commit()
        return 200, {'id': cur.lastrowid}
    finally:
        conn.close()


def main():
    db.migrate(DB_PATH)
    port = int(os.environ.get('OH_PORT', '8091'))
    server = ThreadingHTTPServer(('0.0.0.0', port), Handler)
    print('Opportunity Hunter API on :%d (db=%s)' % (port, DB_PATH), flush=True)
    server.serve_forever()


if __name__ == '__main__':
    main()
