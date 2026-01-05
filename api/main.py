# api/main.py
import os
import psycopg
from fastapi import FastAPI

app = FastAPI()
DB = os.environ["DATABASE_URL"]

@app.get("/events/{user_id}")
def latest_events(user_id: int):
    # intentionally typical query
    q = """
    SELECT id, user_id, created_at
    FROM events
    WHERE user_id = %s
    ORDER BY created_at DESC
    LIMIT 20
    """
    with psycopg.connect(DB) as conn:
        with conn.cursor() as cur:
            cur.execute(q, (user_id,))
            rows = cur.fetchall()
    return {"count": len(rows)}
