"""Deterministic rules-based classification + field extraction. Honest: NOT AI."""
import re

MONEY = re.compile(r'\$\s?([\d,]+(?:\.\d+)?)\s*(?:[-–—to]+\s*\$?\s?([\d,]+(?:\.\d+)?))?')
RATE_WORDS = {
    'hour': 'HOURLY', 'hr': 'HOURLY', '/hr': 'HOURLY', 'hourly': 'HOURLY',
    'month': 'MONTHLY', 'monthly': 'MONTHLY', '/mo': 'MONTHLY',
    'fixed': 'FIXED', 'project': 'FIXED', 'flat': 'FIXED',
}

CATEGORIES = [
    ('AI Agents', ['agent', 'autonomous', 'mcp', 'crewai', 'langgraph', 'tool use']),
    ('AI', ['llm', 'gpt', 'claude', 'gemini', 'rag ', ' rag', 'fine-tun', 'machine learning', ' ML ', 'chatbot', 'openai']),
    ('Automation', ['automation', 'n8n', 'zapier', 'make.com', 'workflow', 'scraping', 'bot ']),
    ('Python', ['python', 'django', 'flask', 'fastapi']),
    ('Web Development', ['website', 'web app', 'frontend', 'backend', 'react', 'next.js', 'node', 'php', 'laravel', 'wordpress', 'full-stack', 'full stack']),
    ('Design', ['design', 'ui/ux', 'ui ', 'ux ', 'figma', 'logo', 'brand']),
    ('Video Editing', ['video', 'editing', 'premiere', 'after effects', 'reels', 'youtube edit']),
    ('SEO', ['seo', 'ranking', 'backlink', 'keyword']),
    ('Data', ['data', 'excel', 'csv', 'pandas', 'sql', 'dashboard', 'analytics']),
    ('E-commerce', ['shopify', 'woocommerce', 'e-commerce', 'ecommerce', 'store']),
    ('Content Creation', ['content', 'copywrit', 'blog post', 'article writ']),
]

SKILLS = ['python', 'javascript', 'react', 'node', 'n8n', 'zapier', 'openai', 'llm', 'seo', 'figma',
          'wordpress', 'shopify', 'sql', 'excel', 'premiere', 'photoshop', 'fastapi', 'django',
          'machine learning', 'chatbot', 'automation', 'scraping', 'video editing', 'copywriting']

TECHS = ['python', 'javascript', 'typescript', 'react', 'next.js', 'node', 'django', 'flask', 'fastapi',
         'php', 'laravel', 'wordpress', 'shopify', 'n8n', 'zapier', 'openai', 'figma', 'sql', 'postgres']


def _num(s):
    try:
        return float(s.replace(',', ''))
    except (ValueError, AttributeError):
        return None


def extract_budget(text):
    t = (text or '').lower()
    m = MONEY.search(text or '')
    bmin = bmax = None
    if m:
        bmin = _num(m.group(1))
        bmax = _num(m.group(2)) if m.group(2) else bmin
    btype = 'UNKNOWN'
    for word, kind in RATE_WORDS.items():
        if word in t:
            btype = kind
            break
    if bmin is None and any(w in t for w in ['budget', 'paid', 'pay ', '$', 'compensation']):
        btype = 'FIXED' if btype == 'UNKNOWN' else btype
    currency = 'USD' if (bmin is not None or '$' in (text or '')) else 'UNKNOWN'
    return btype, bmin, bmax, currency


def extract_deadline(text):
    t = (text or '').lower()
    if any(w in t for w in ['asap', 'urgent', 'immediately', 'right away']):
        return None, 'ASAP'
    m = re.search(r'(\b(?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\s+\d{1,2}(?:\s*,?\s*\d{4})?)', t)
    if m:
        return None, m.group(1).upper()
    return None, 'UNKNOWN'


def extract_remote(text):
    t = (text or '').lower()
    if any(w in t for w in ['remote', 'work from home', 'wfh', 'anywhere', 'async']):
        return 1
    if any(w in t for w in ['on-site', 'onsite', 'on site', 'hybrid']):
        return 0
    return None


def classify(text):
    t = (' ' + (text or '').lower() + ' ')
    best, hits = 'Other', 0
    topics = []
    for cat, keys in CATEGORIES:
        n = 0
        for k in keys:
            if k in t:
                n += 1
                topics.append(k.strip())
        if n > hits:
            best, hits = cat, n
    if hits == 0:
        best = 'Unknown'
    return best, topics[:8], hits


def extract_skills(text):
    t = (' ' + (text or '').lower() + ' ')
    return sorted({s for s in SKILLS if s in t})


def extract_techs(text):
    t = (' ' + (text or '').lower() + ' ')
    return sorted({s for s in TECHS if s in t})
