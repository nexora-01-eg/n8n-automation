"""Fingerprints + near-duplicate detection. Pure stdlib, deterministic."""
import hashlib
import re

_WS = re.compile(r'\s+')
_NONWORD = re.compile(r'[^a-z0-9 ]')


TRACKING_PARAMS = {'utm_source', 'utm_medium', 'utm_campaign', 'utm_term', 'utm_content',
                    'ref', 'referrer', 'fbclid', 'gclid', '_ga', 'mc_cid', 'mc_eid', 'igshid'}


def norm_url(url):
    import urllib.parse
    u = (url or '').strip()
    if not u:
        return ''
    try:
        parts = urllib.parse.urlsplit(u.lower())
    except ValueError:
        return u.lower()
    q = urllib.parse.parse_qsl(parts.query, keep_blank_values=False)
    kept = sorted((k, v) for k, v in q if k not in TRACKING_PARAMS)
    clean_q = urllib.parse.urlencode(kept)
    path = parts.path.rstrip('/') or '/'
    out = parts.scheme + '://' + parts.netloc + path
    if clean_q:
        out += '?' + clean_q
    return out


def norm_text(t):
    t = (t or '').lower()
    t = _WS.sub(' ', t)
    t = _NONWORD.sub('', t)
    return t.strip()


def fingerprint(url, title, source):
    base = norm_url(url) + '|' + norm_text(title) + '|' + (source or '')
    return hashlib.sha256(base.encode('utf-8')).hexdigest()


def tokens(t):
    return set(norm_text(t).split())


def jaccard(a, b):
    ta, tb = tokens(a), tokens(b)
    if not ta or not tb:
        return 0.0
    return len(ta & tb) / len(ta | tb)


def is_same_url(a, b):
    ua, ub = norm_url(a), norm_url(b)
    return bool(ua) and ua == ub


def possible_duplicate(candidate, existing, threshold=0.85, min_tokens=5):
    """Return (is_dup, reason). Exact/URL match = dup; high title similarity = possible.

    Short titles are excluded from near-matching (they false-positive on
    headers like 'Hiring' or 'Apply here').
    """
    if candidate.get('fingerprint') and candidate['fingerprint'] == existing.get('fingerprint'):
        return True, 'exact-fingerprint'
    if is_same_url(candidate.get('url'), existing.get('url')):
        return True, 'same-url'
    ct, et = tokens(candidate.get('title', '')), tokens(existing.get('title', ''))
    if len(ct) >= min_tokens and len(et) >= min_tokens:
        sim = len(ct & et) / len(ct | et)
        if sim >= threshold:
            return True, 'near-title-%.2f' % sim
    return False, ''
