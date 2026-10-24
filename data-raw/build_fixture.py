#!/usr/bin/env python3
"""Build the SQLite test fixture from the synthetic-hospital-data sample.

Usage:
    python3 data-raw/build_fixture.py <sample_dir> <out.sqlite> [rows_per_table]

<sample_dir> is data/v2/sample of https://github.com/ThomUK/synthetic-hospital-data.
Every table in layer1/, reference/, derived/ and aggregate/ is written with at
most rows_per_table rows (a seeded reservoir sample so dates spread across the
window). SQLite has no schemas, so derived and aggregate tables are prefixed
derived_ and agg_. A view is added so TABLE_TYPE handling can be tested.
Declared column types are kept (DATE, TIMESTAMP, BOOLEAN, ...) so the package's
type classification sees realistic metadata.
"""
import glob
import json
import os
import sqlite3
import sys

import duckdb

TYPE_MAP = {
    "VARCHAR": "TEXT", "INTEGER": "INTEGER", "BIGINT": "BIGINT", "DOUBLE": "DOUBLE",
    "DATE": "DATE", "TIMESTAMP": "TIMESTAMP", "BOOLEAN": "BOOLEAN", "VARCHAR[]": "TEXT",
}
PREFIX = {"layer1": "", "reference": "", "derived": "derived_", "aggregate": "agg_"}


def to_sqlite(v):
    if v is None:
        return None
    if isinstance(v, bool):
        return int(v)
    if isinstance(v, (list, tuple)):
        return json.dumps(list(v))
    if hasattr(v, "isoformat"):
        return v.isoformat(sep=" ") if hasattr(v, "hour") else v.isoformat()
    return v


def main(sample_dir, out, cap=2000):
    if os.path.exists(out):
        os.remove(out)
    con = duckdb.connect()
    db = sqlite3.connect(out)
    n_tables = 0
    for layer, prefix in PREFIX.items():
        for f in sorted(glob.glob(os.path.join(sample_dir, layer, "*.parquet"))):
            name = prefix + os.path.splitext(os.path.basename(f))[0]
            cols = con.execute(f"describe select * from read_parquet('{f}')").fetchall()
            ddl = ", ".join(f'"{c[0]}" {TYPE_MAP.get(c[1], "TEXT")}' for c in cols)
            db.execute(f'CREATE TABLE "{name}" ({ddl})')
            rows = con.execute(
                f"select * from read_parquet('{f}') using sample reservoir({cap} rows) repeatable (42)"
            ).fetchall()
            ph = ", ".join("?" * len(cols))
            db.executemany(f'INSERT INTO "{name}" VALUES ({ph})', [tuple(to_sqlite(v) for v in r) for r in rows])
            n_tables += 1
            print(f"{name}: {len(rows)} rows, {len(cols)} cols")
    db.execute(
        "CREATE VIEW v_emergency_spells AS SELECT provspno, person_id, admidate, disdate, speldur "
        "FROM derived_spells WHERE emergency = 1"
    )
    db.commit()
    db.execute("VACUUM")
    db.close()
    print(f"wrote {out}: {n_tables} tables + 1 view, {os.path.getsize(out)/1e6:.1f} MB")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], int(sys.argv[3]) if len(sys.argv) > 3 else 2000)
