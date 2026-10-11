"""SQLite access + migrations. Stdlib only."""
import os
import sqlite3

MIGRATIONS_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'database', 'migrations')


def connect(db_path):
    os.makedirs(os.path.dirname(os.path.abspath(db_path)), exist_ok=True)
    conn = sqlite3.connect(db_path, timeout=30)
    conn.row_factory = sqlite3.Row
    conn.execute('PRAGMA journal_mode=WAL')
    conn.execute('PRAGMA foreign_keys=ON')
    return conn


def migrate(db_path):
    conn = connect(db_path)
    try:
        files = sorted(f for f in os.listdir(MIGRATIONS_DIR) if f.endswith('.sql'))
        for fname in files:
            with open(os.path.join(MIGRATIONS_DIR, fname), 'r', encoding='utf-8') as fh:
                conn.executescript(fh.read())
        conn.commit()
    finally:
        conn.close()
