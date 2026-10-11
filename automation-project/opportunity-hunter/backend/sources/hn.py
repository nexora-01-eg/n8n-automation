"""Hacker News 'Who is hiring?' adapter. Public APIs, no auth.

Strategy: Algolia search finds the latest monthly hiring thread -> Firebase kids
give real job comments (title/text/url/time). All fields come from the source.
"""
from datetime import datetime, timezone

from .base import SourceAdapter, http_get_json

_ALGOLIA = ('http://hn.algolia.com/api/v1/search_by_date?query=who%20is%20hiring'
           '&tags=story&hitsPerPage=20')
_ITEM = 'https://hacker-news.firebaseio.com/v0/item/{}.json'


class HNHiringAdapter(SourceAdapter):
    id = 'hn_hiring'
    label = 'HN Who is Hiring'

    def _thread_id(self):
        import re
        hits = http_get_json(_ALGOLIA).get('hits', [])
        cands = []
        for h in hits:
            title = (h.get('title') or '').lower()
            if 'who is hiring' in title and 'wants to be hired' not in title:
                cands.append(h)
        cands.sort(key=lambda h: h.get('created_at_i') or 0, reverse=True)
        monthly = [h for h in cands if re.search(r'who is hiring\?\s*\(', (h.get('title') or '').lower())]
        for h in (monthly or cands)[:6]:
            try:
                item = http_get_json(_ITEM.format(h['objectID']))
            except Exception:
                continue
            if item and (item.get('kids') or []):
                return h['objectID']
        raise RuntimeError('hiring thread with comments not found')

    def fetch(self):
        tid = self._thread_id()
        thread = http_get_json(_ITEM.format(tid))
        kids = thread.get('kids', [])[:self.max_items]
        raws = []
        for kid in kids:
            try:
                it = http_get_json(_ITEM.format(kid))
            except Exception:
                continue
            if it and not it.get('deleted', False):
                raws.append(it)
        return raws

    def normalize(self, raw):
        text = raw.get('text') or ''
        ts = raw.get('time')
        posted = None
        if ts:
            posted = datetime.fromtimestamp(int(ts), tz=timezone.utc).isoformat()
        url = 'https://news.ycombinator.com/item?id=%s' % raw.get('id')
        return {
            'source': self.id,
            'source_item_id': str(raw.get('id')),
            'url': url,
            'title': (text.split('<p>')[0].strip()[:200] or 'HN hiring comment %s' % raw.get('id')),
            'description': text,
            'posted_at': posted,
            'raw_data': {k: raw.get(k) for k in ('id', 'by', 'time', 'type')},
        }
