"""Explainable opportunity scoring. Every part stored separately. No black box."""
from datetime import datetime, timezone


def _parse_dt(s):
    if not s:
        return None
    try:
        return datetime.fromisoformat(str(s).replace('Z', '+00:00'))
    except ValueError:
        return None


def score(item, weights):
    """item: normalized dict. Returns dict of parts + total 0..100."""
    parts = {}
    text = ((item.get('title') or '') + ' ' + (item.get('description') or '')).lower()

    hits = item.get('_cat_hits', 0)
    parts['service_match_score'] = min(weights.get('service_match', 30), hits * 10)

    if item.get('budget_min') is not None:
        parts['budget_score'] = weights.get('budget', 20)
    elif (item.get('budget_type') or 'UNKNOWN') != 'UNKNOWN':
        parts['budget_score'] = weights.get('budget', 20) // 2
    else:
        parts['budget_score'] = 0

    posted = _parse_dt(item.get('posted_at'))
    if posted:
        age_h = (datetime.now(timezone.utc) - posted).total_seconds() / 3600.0
        if age_h <= 24:
            parts['freshness_score'] = weights.get('freshness', 15)
        elif age_h <= 72:
            parts['freshness_score'] = weights.get('freshness', 15) * 2 // 3
        elif age_h <= 168:
            parts['freshness_score'] = weights.get('freshness', 15) // 3
        else:
            parts['freshness_score'] = 0
    else:
        parts['freshness_score'] = 0

    words = len(text.split())
    if words >= 40:
        parts['clarity_score'] = weights.get('clarity', 15)
    elif words >= 15:
        parts['clarity_score'] = weights.get('clarity', 15) * 2 // 3
    elif words >= 5:
        parts['clarity_score'] = weights.get('clarity', 15) // 3
    else:
        parts['clarity_score'] = 0

    parts['remote_score'] = weights.get('remote', 10) if item.get('remote') == 1 else 0

    parts['client_signal_score'] = 0
    if (item.get('company_name') or 'UNKNOWN') != 'UNKNOWN':
        parts['client_signal_score'] += weights.get('client', 10) // 2
    if any(w in text for w in ['looking for', 'hiring', 'need a', 'need help', 'seeking']):
        parts['client_signal_score'] += weights.get('client', 10) // 2

    missing = 0
    for f in ('budget_min', 'deadline_text', 'company_name'):
        v = item.get(f)
        if v is None or v in ('UNKNOWN', ''):
            missing += 1
    parts['missing_penalty'] = min(weights.get('missing_penalty', 15), missing * 5)

    risk = 0
    if any(w in text for w in ['crypto doubl', 'guaranteed income', 'no experience needed', 'wire transfer', 'gift card']):
        risk += 10
    if not item.get('url'):
        risk += 5
    parts['risk_penalty'] = min(weights.get('risk_penalty', 20), risk)

    total = (parts['service_match_score'] + parts['budget_score'] + parts['freshness_score']
             + parts['clarity_score'] + parts['remote_score'] + parts['client_signal_score']
             - parts['missing_penalty'] - parts['risk_penalty'])
    parts['opportunity_score'] = max(0, min(100, total))

    filled = sum(1 for f in ('title', 'url', 'description', 'budget_min', 'deadline_text', 'company_name', 'posted_at')
                 if item.get(f) not in (None, '', 'UNKNOWN'))
    parts['confidence_score'] = int(round(100.0 * filled / 7.0))
    return parts
