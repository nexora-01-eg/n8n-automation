"""RemoteOK adapter. Public JSON API, no auth (link back per their ToS)."""
from datetime import datetime, timezone

from .base import SourceAdapter, http_get_json

_API = 'https://remoteok.com/api'
_FIELDS = ('id', 'date', 'company', 'position', 'tags', 'location', 'salary_min',
           'salary_max', 'url', 'description', 'logo')


class RemoteOKAdapter(SourceAdapter):
    id = 'remoteok'
    label = 'RemoteOK'

    def fetch(self):
        data = http_get_json(_API)
        if isinstance(data, list) and data and isinstance(data[0], dict) and 'legal' in data[0]:
            data = data[1:]
        return [d for d in data if isinstance(d, dict)][:self.max_items]

    def normalize(self, raw):
        posted = None
        try:
            if raw.get('date'):
                posted = datetime.fromtimestamp(int(raw['date']), tz=timezone.utc).isoformat()
        except (ValueError, TypeError):
            posted = None
        desc = raw.get('description') or ''
        return {
            'source': self.id,
            'source_item_id': str(raw.get('id')),
            'url': raw.get('url') or 'UNKNOWN',
            'title': raw.get('position') or 'UNKNOWN',
            'description': desc,
            'posted_at': posted,
            'raw_data': {k: raw.get(k) for k in _FIELDS},
        }
