import sys
import unittest

sys.path.insert(0, '/app')
from backend import fingerprint as fp


class TestFingerprint(unittest.TestCase):
    def test_stable(self):
        a = fp.fingerprint('https://x.test/a?utm_source=rss', 'Hello World', 's')
        b = fp.fingerprint('https://x.test/a', 'hello  world!', 's')
        self.assertEqual(a, b)

    def test_tracking_stripped_but_id_kept(self):
        a = fp.norm_url('https://news.ycombinator.com/item?id=1&utm_source=x')
        b = fp.norm_url('https://news.ycombinator.com/item?id=1')
        self.assertEqual(a, b)
        self.assertIn('id=1', a)

    def test_exact_and_url(self):
        c = {'url': 'https://x.test/a', 'title': 'T', 'fingerprint': 'f1'}
        self.assertEqual(fp.possible_duplicate(dict(c), dict(c)), (True, 'exact-fingerprint'))
        d = dict(c, fingerprint='f2')
        self.assertEqual(fp.possible_duplicate(d, dict(c))[0], True)

    def test_near_dup_needs_tokens(self):
        c = {'url': 'https://x.test/a', 'title': 'Hiring', 'fingerprint': 'f1'}
        e = {'url': 'https://x.test/b', 'title': 'Hiring!', 'fingerprint': 'f2'}
        self.assertEqual(fp.possible_duplicate(c, e), (False, ''))

    def test_jaccard(self):
        self.assertAlmostEqual(fp.jaccard('a b c', 'a b c'), 1.0)
        self.assertEqual(fp.jaccard('', 'x'), 0.0)


if __name__ == '__main__':
    unittest.main()
