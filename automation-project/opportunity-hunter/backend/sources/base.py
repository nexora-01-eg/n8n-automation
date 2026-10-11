"""Source adapter contract. New source = subclass + register in SOURCES. Nothing else changes."""
import json
import urllib.request


class SourceAdapter:
    id = 'base'
    label = 'Base'

    def __init__(self, config):
        self.config = config or {}
        self.max_items = int(self.config.get('max_items', 40))

    def fetch(self):
        """Return list of raw dicts. Raise with clear message on failure."""
        raise NotImplementedError

    def normalize(self, raw):
        """Map raw -> normalized opportunity dict (UNKNOWN for missing, never invented)."""
        raise NotImplementedError

    def run(self):
        raws = self.fetch()[:self.max_items]
        items, errors = [], []
        for r in raws:
            try:
                items.append(self.normalize(r))
            except Exception as exc:  # noqa: BLE001 - per-item isolation
                errors.append({'error_type': type(exc).__name__, 'error_message': str(exc)[:300]})
        return items, errors


def http_get_json(url, timeout=25, headers=None):
    req = urllib.request.Request(url, headers=headers or {'User-Agent': 'OpportunityHunter/0.1 (local research tool)'})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read().decode('utf-8', 'replace'))
