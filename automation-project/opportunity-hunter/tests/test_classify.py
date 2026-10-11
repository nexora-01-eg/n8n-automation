import sys
import unittest

sys.path.insert(0, '/app')
from backend import classify, scoring


class TestClassify(unittest.TestCase):
    def test_category(self):
        cat, topics, hits = classify.classify('Need python developer for automation with n8n')
        self.assertIn(cat, ('Automation', 'Python'))
        self.assertGreater(hits, 0)

    def test_unknown_when_empty(self):
        cat, topics, hits = classify.classify('hello world foo')
        self.assertEqual(cat, 'Unknown')

    def test_budget(self):
        t, mn, mx, cur = classify.extract_budget('Budget $500-$1000 fixed project')
        self.assertEqual(t, 'FIXED')
        self.assertEqual(mn, 500.0)
        self.assertEqual(mx, 1000.0)
        t2, mn2, _, _ = classify.extract_budget('no money mentioned')
        self.assertIsNone(mn2)

    def test_deadline(self):
        _, d = classify.extract_deadline('need ASAP please')
        self.assertEqual(d, 'ASAP')
        _, d2 = classify.extract_deadline('take your time')
        self.assertEqual(d2, 'UNKNOWN')

    def test_remote(self):
        self.assertEqual(classify.extract_remote('fully remote async team'), 1)
        self.assertEqual(classify.extract_remote('onsite in Cairo'), 0)
        self.assertIsNone(classify.extract_remote('great role'))

    def test_skills(self):
        s = classify.extract_skills('Python and SEO and video editing needed')
        self.assertIn('python', s)
        self.assertIn('seo', s)


class TestScoring(unittest.TestCase):
    def _item(self, **kw):
        d = {'title': 'Need help', 'url': 'https://x.test/1', 'description': 'word ' * 50,
             'budget_min': None, 'budget_type': 'UNKNOWN', 'deadline_text': 'UNKNOWN',
             'company_name': 'UNKNOWN', 'posted_at': None, 'remote': None}
        d.update(kw)
        return d

    def test_bounds(self):
        w = {'service_match': 30, 'budget': 20, 'freshness': 15, 'clarity': 15,
             'remote': 10, 'client': 10, 'missing_penalty': 15, 'risk_penalty': 20}
        p = scoring.score(self._item(), w)
        self.assertGreaterEqual(p['opportunity_score'], 0)
        self.assertLessEqual(p['opportunity_score'], 100)
        self.assertIn('service_match_score', p)

    def test_budget_helps(self):
        w = {'service_match': 30, 'budget': 20, 'freshness': 15, 'clarity': 15,
             'remote': 10, 'client': 10, 'missing_penalty': 15, 'risk_penalty': 20}
        a = scoring.score(self._item(), w)
        b = scoring.score(self._item(budget_min=500.0, budget_type='FIXED'), w)
        self.assertGreater(b['opportunity_score'], a['opportunity_score'])

    def test_risk_penalty(self):
        w = {'service_match': 30, 'budget': 20, 'freshness': 15, 'clarity': 15,
             'remote': 10, 'client': 10, 'missing_penalty': 15, 'risk_penalty': 20}
        p = scoring.score(self._item(title='guaranteed income wire transfer gift card'), w)
        self.assertGreater(p['risk_penalty'], 0)


if __name__ == '__main__':
    unittest.main()
