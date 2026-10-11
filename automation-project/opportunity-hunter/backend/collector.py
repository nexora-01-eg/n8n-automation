"""Collector: runs adapters, enriches, dedupes, stores. Single implementation used by API/n8n/CLI."""
import json
from datetime import datetime, timezone

from . import classify, db, fingerprint, scoring
from .ai import get_provider
from .sources.hn import HNHiringAdapter
from .sources.remoteok import RemoteOKAdapter

ADAPTERS = {'hn_hiring': HNHiringAdapter, 'remoteok': RemoteOKAdapter}
STATUSES = {'NEW', 'REVIEWING', 'INTERESTED', 'APPLIED', 'CONTACTED', 'REPLIED', 'WON', 'LOST', 'REJECTED', 'ARCHIVED'}


def now_iso():
    return datetime.now(timezone.utc).isoformat()


def validate(item):
    errs = []
    if not item.get('title'):
        errs.append('missing title')
    if not item.get('url'):
        errs.append('missing url')
    return errs


def enrich(item, weights, ai):
    text = ((item.get('title') or '') + ' ' + (item.get('description') or ''))
    cat, topics, hits = classify.classify(text)
    item['service_category'] = cat
    item['topics'] = topics
    item['_cat_hits'] = hits
    item['skills'] = classify.extract_skills(text)
    item['technologies'] = classify.extract_techs(text)
    btype, bmin, bmax, curr = classify.extract_budget(item.get('description') or '')
    item['budget_type'] = btype
    item['budget_min'] = bmin
    item['budget_max'] = bmax
    item['budget_currency'] = curr
    dl, dlt = classify.extract_deadline(item.get('description') or '')
    item['deadline'] = dl
    item['deadline_text'] = dlt
    item['remote'] = classify.extract_remote(text)
    parts = scoring.score(item, weights)
    item.update(parts)
    item.update(ai.enrich(item))
    item['fingerprint'] = fingerprint.fingerprint(item.get('url'), item.get('title'), item.get('source'))
    return item


COLUMNS = ('source,source_item_id,url,title,description,normalized_description,service_category,'
           'service_subcategory,budget_type,budget_min,budget_max,budget_currency,deadline,deadline_text,'
           'location,remote,company_name,client_name,client_type,project_type,skills,technologies,topics,'
           'posted_at,discovered_at,opportunity_score,confidence_score,service_match_score,budget_score,'
           'freshness_score,clarity_score,remote_score,client_signal_score,missing_penalty,risk_penalty,'
           'status,possible_duplicate,ai_mode,ai_summary,raw_data,fingerprint,created_at,updated_at')


def store_item(conn, item, discovered):
    skills = json.dumps(item.get('skills', []))
    techs = json.dumps(item.get('technologies', []))
    topics = json.dumps(item.get('topics', []))
    vals = (item.get('source'), item.get('source_item_id'), item.get('url'), item.get('title'),
            item.get('description', ''), item.get('description', '')[:2000], item.get('service_category', 'Unknown'),
            'UNKNOWN', item.get('budget_type', 'UNKNOWN'), item.get('budget_min'), item.get('budget_max'),
            item.get('budget_currency', 'UNKNOWN'), item.get('deadline'), item.get('deadline_text', 'UNKNOWN'),
            'UNKNOWN', item.get('remote'), 'UNKNOWN', 'UNKNOWN', 'UNKNOWN', 'UNKNOWN',
            skills, techs, topics, item.get('posted_at'), discovered,
            item.get('opportunity_score', 0), item.get('confidence_score', 0),
            item.get('service_match_score', 0), item.get('budget_score', 0), item.get('freshness_score', 0),
            item.get('clarity_score', 0), item.get('remote_score', 0), item.get('client_signal_score', 0),
            item.get('missing_penalty', 0), item.get('risk_penalty', 0),
            'NEW', 0, item.get('ai_mode', 'AI_DISABLED'), item.get('ai_summary'),
            json.dumps(item.get('raw_data', {})), item.get('fingerprint'), discovered, discovered)
    try:
        cur = conn.execute('INSERT INTO opportunities (%s) VALUES (%s)' % (COLUMNS, ','.join('?' * 43)), vals)
        return cur.lastrowid, False
    except Exception:
        return None, True


def find_candidates(conn, item):
    rows = conn.execute(
        'SELECT id,title,url,fingerprint FROM opportunities WHERE source=? ORDER BY id DESC LIMIT 400',
        (item.get('source'),)).fetchall()
    glob = conn.execute(
        'SELECT id,title,url,fingerprint FROM opportunities WHERE url=? LIMIT 5',
        (fingerprint.norm_url(item.get('url')),)).fetchall()
    seen = {r['id'] for r in rows}
    out = list(rows)
    for r in glob:
        if r['id'] not in seen:
            out.append(r)
    return [dict(r) for r in out]


def run_collection(db_path, config, triggered_by='manual', source_filter=None, limits=None):
    weights = ((config.get('scoring') or {}).get('weights')) or {}
    ai = get_provider(config)
    conn = db.connect(db_path)
    try:
        started = now_iso()
        cur = conn.execute(
            'INSERT INTO runs (started_at,status,triggered_by) VALUES (?,?,?)', (started, 'running', triggered_by))
        run_id = cur.lastrowid
        conn.commit()
        summary = {'run_id': run_id, 'sources': [], 'found': 0, 'added': 0, 'dups': 0, 'rejected': 0, 'errors': 0}
        for src in config.get('sources', []):
            if source_filter and src['id'] not in source_filter:
                continue
            if not src.get('enabled', True):
                continue
            cls = ADAPTERS.get(src['id'])
            if not cls:
                continue
            cfg = dict(src)
            if limits and src['id'] in limits:
                cfg['max_items'] = limits[src['id']]
            s_start = now_iso()
            rcur = conn.execute(
                'INSERT INTO run_sources (run_id,source,status,started_at) VALUES (?,?,?,?)',
                (run_id, src['id'], 'running', s_start))
            rs_id = rcur.lastrowid
            conn.commit()
            found = added = dups = 0
            status, etype, emsg = 'success', None, None
            try:
                adapter = cls(cfg)
                raws, fetch_errors = adapter.run()
                for fe in fetch_errors:
                    conn.execute(
                        'INSERT INTO run_sources (run_id,source,status,error_type,error_message,started_at,finished_at) VALUES (?,?,?,?,?,?,?)',
                        (run_id, src['id'], 'item-error', fe.get('error_type'), fe.get('error_message'), s_start, now_iso()))
                for raw in raws:
                    found += 1
                    item = dict(raw)
                    if validate(item):
                        summary['rejected'] += 1
                        continue
                    item = enrich(item, weights, ai)
                    dup = False
                    for cand in find_candidates(conn, item):
                        is_dup, reason = fingerprint.possible_duplicate(item, cand)
                        if is_dup:
                            dup = True
                            break
                    if dup:
                        dups += 1
                        continue
                    oid, was_dup = store_item(conn, item, started)
                    if was_dup:
                        dups += 1
                    else:
                        added += 1
            except Exception as exc:  # noqa: BLE001 - per-source isolation
                status, etype, emsg = 'failed', type(exc).__name__, str(exc)[:500]
                summary['errors'] += 1
            conn.execute(
                'UPDATE run_sources SET status=?,items_found=?,items_added=?,error_type=?,error_message=?,finished_at=? WHERE id=?',
                (status, found, added, etype, emsg, now_iso(), rs_id))
            conn.commit()
            summary['sources'].append({'source': src['id'], 'status': status, 'found': found,
                                       'added': added, 'error': emsg})
            summary['found'] += found
            summary['added'] += added
            summary['dups'] += dups
        done = now_iso()
        final = 'success' if summary['errors'] == 0 else ('partial' if summary['added'] > 0 else 'failed')
        conn.execute(
            'UPDATE runs SET finished_at=?,status=?,sources_total=?,items_found=?,items_added=?,duplicates=?,rejected=?,errors=? WHERE id=?',
            (done, final, len(summary['sources']), summary['found'], summary['added'],
             summary['dups'], summary['rejected'], summary['errors'], run_id))
        conn.commit()
        summary['status'] = final
        summary['finished_at'] = done
        return summary
    finally:
        conn.close()
