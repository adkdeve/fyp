#!/bin/sh
set -e

python - <<'PY'
import os
import time
from urllib.parse import urlparse

from sqlalchemy import create_engine, text
from sqlalchemy.exc import OperationalError

database_url = os.environ.get("DATABASE_URL")
if not database_url:
    raise SystemExit("DATABASE_URL is required")

parsed = urlparse(database_url)
target = parsed.hostname or "database"

for attempt in range(1, 31):
    try:
        engine = create_engine(database_url, pool_pre_ping=True)
        with engine.connect() as connection:
            connection.execute(text("SELECT 1"))
        print(f"Database is ready at {target}")
        break
    except OperationalError:
        print(f"Waiting for database at {target} ({attempt}/30)")
        time.sleep(2)
else:
    raise SystemExit(f"Database did not become ready at {target}")
PY

if [ "${RUN_MIGRATIONS:-true}" = "true" ]; then
    alembic upgrade head
fi

exec "$@"
