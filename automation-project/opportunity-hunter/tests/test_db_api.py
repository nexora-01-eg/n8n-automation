import json
import os
import sys
import tempfile
import unittest
import urllib.request

sys.path.insert(0, '/app')
from backend import collector, db

API = 'http://localhost:8091'


class TestDB(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.dbp = os.path.join(self.tmp, 't.db')
        db.migrate(self.dbp)

    def test_status_check(self):
        conn = db.connect(self.dbp)
        try:
            with self.assertRaises(Exception):
                conn.execute("INSERT INTO opportunities (source,source_item_id,url,title,discovered_at,fingerprint,created_at,updated_at,status) VALUES (?,?,?,?,?,?,?,?,?)",
                             ('s', '1', 'u', 't', '2026-01-01', 'f', '2026-01-01', '2026-01-01', 'BOGUS'))
        finally:
            conn.close()

    def test_insert_and_history(self):
        conn = db.connect(self.dbp)
        try:
            conn.execute("INSERT INTO opportunities (source,source_item_id,url,title,discovered_at,fingerprint,created_at,updated_at) VALUES (?,?,?,?,?,?,?,?)",
                         ('s', '1', 'u', 't', '2026-01-01', 'f', '2026-01-01', '2026-01-01'))
            conn.execute("UPDATE opportunities SET status='REVIEWING' WHERE id=1")
            conn.execute("INSERT INTO status_history (opportunity_id,old_status,new_status,changed_at) VALUES (?,?,?,?)",
                         (1, 'NEW', 'REVIEWING', '2026-01-02'))
            conn.execute("INSERT INTO notes (opportunity_id,body,created_at) VALUES (?,?,?)", (1, 'note one', '2026-01-03'))
            conn.commit()
            h = conn.execute('SELECT * FROM status_history WHERE opportunity_id=1').fetchall()
            n = conn.execute('SELECT * FROM notes WHERE opportunity_id=1').fetchall()
            self.assertEqual(len(h), 1)
            self.assertEqual(len(n), 1)
        finally:
            conn.close()


def api(path, method='GET', body=None, expect=None):
    import urllib.error
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(API + path, data=data, method=method,
                                 headers={'Content-Type': 'application/json'})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return r.status, json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read().decode() or '{}')


class TestAPI(unittest.TestCase):
    def test_health(self):
        code, body = api('/api/health')
        self.assertEqual(code, 200)
        self.assertEqual(body['status'], 'ok')

    def test_stats_shape(self):
        code, body = api('/api/stats')
        self.assertEqual(code, 200)
        for k in ('total', 'new', 'by_status', 'by_source', 'avg_score'):
            self.assertIn(k, body)

    def test_opportunities_filters(self):
        code, body = api('/api/opportunities?per_page=5&sort=opportunity_score')
        self.assertEqual(code, 200)
        self.assertIn('total', body)
        self.assertIn('items', body)

    def test_status_flow_and_notes(self):
        _, first = api('/api/opportunities?per_page=1')
        if not first['items']:
            self.skipTest('no data yet')
        oid = first['items'][0]['id']
        code, _ = api('/api/opportunities/%d/status' % oid, 'POST', {'status': 'REVIEWING'})
        self.assertEqual(code, 200)
        code, _ = api('/api/opportunities/%d/notes' % oid, 'POST', {'body': 'test note T14'})
        self.assertEqual(code, 200)
        code, full = api('/api/opportunities/%d' % oid)
        self.assertEqual(code, 200)
        self.assertTrue(any(h['new_status'] == 'REVIEWING' for h in full['history']))
        self.assertTrue(any('T14' in n['body'] for n in full['notes']))
        code, _ = api('/api/opportunities/%d/status' % oid, 'POST', {'status': 'NEW'})
        self.assertEqual(code, 200)
        code, _ = api('/api/opportunities/%d/status' % oid, 'POST', {'status': 'BOGUS'})
        self.assertEqual(code, 400)

    def test_runs_and_sources(self):
        code, body = api('/api/runs?limit=5')
        self.assertEqual(code, 200)
        self.assertIsInstance(body, list)
        code, body = api('/api/sources')
        self.assertEqual(code, 200)
        self.assertIsInstance(body, list)


if __name__ == '__main__':
    unittest.main()
