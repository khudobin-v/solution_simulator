import os
import sqlite3
from contextlib import contextmanager
from pathlib import Path
from typing import Optional

DB_PATH = Path(os.environ.get("DB_PATH", str(Path(__file__).parent / "app.db")))


def init_db() -> None:
    with _conn() as c:
        c.executescript("""
            CREATE TABLE IF NOT EXISTS users (
                id            INTEGER PRIMARY KEY AUTOINCREMENT,
                username      TEXT UNIQUE NOT NULL,
                password_hash TEXT NOT NULL,
                created_at    TEXT NOT NULL DEFAULT (datetime('now'))
            );
            CREATE TABLE IF NOT EXISTS results (
                id                  INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id             INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                name                TEXT NOT NULL,
                geometry            TEXT NOT NULL,
                grid_size           INTEGER NOT NULL,
                steps               INTEGER NOT NULL,
                temperature         REAL NOT NULL,
                base_rate           REAL NOT NULL,
                diffusion_rate      REAL NOT NULL,
                seed                INTEGER NOT NULL,
                pore_count          INTEGER NOT NULL,
                initial_solid_cells INTEGER NOT NULL,
                final_solid_cells   INTEGER NOT NULL,
                dissolution_step    INTEGER NOT NULL,
                dissolved_percent   REAL NOT NULL,
                created_at          TEXT NOT NULL DEFAULT (datetime('now'))
            );
        """)


@contextmanager
def _conn():
    con = sqlite3.connect(DB_PATH)
    con.row_factory = sqlite3.Row
    con.execute("PRAGMA foreign_keys = ON")
    try:
        yield con
        con.commit()
    finally:
        con.close()


# ── Users ─────────────────────────────────────────────────────────────────────

def create_user(username: str, password_hash: str) -> int:
    with _conn() as c:
        return c.execute(
            "INSERT INTO users (username, password_hash) VALUES (?, ?)",
            (username, password_hash),
        ).lastrowid


def get_user_by_username(username: str) -> Optional[dict]:
    with _conn() as c:
        row = c.execute("SELECT * FROM users WHERE username = ?", (username,)).fetchone()
        return dict(row) if row else None


def get_user_by_id(user_id: int) -> Optional[dict]:
    with _conn() as c:
        row = c.execute("SELECT * FROM users WHERE id = ?", (user_id,)).fetchone()
        return dict(row) if row else None


# ── Results ───────────────────────────────────────────────────────────────────

def save_result(user_id: int, name: str, params: dict, stats: dict) -> int:
    with _conn() as c:
        return c.execute("""
            INSERT INTO results
              (user_id, name, geometry, grid_size, steps, temperature, base_rate,
               diffusion_rate, seed, pore_count,
               initial_solid_cells, final_solid_cells, dissolution_step, dissolved_percent)
            VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)
        """, (
            user_id, name,
            params["geometry"], params["grid_size"], params["steps"],
            params["temperature"], params["base_rate"], params["diffusion_rate"],
            params["seed"], params["pore_count"],
            stats["initial_solid_cells"], stats["final_solid_cells"],
            stats["dissolution_step"], stats["dissolved_percent"],
        )).lastrowid


def get_user_results(user_id: int) -> list:
    with _conn() as c:
        rows = c.execute(
            "SELECT * FROM results WHERE user_id = ? ORDER BY created_at DESC",
            (user_id,),
        ).fetchall()
        return [dict(r) for r in rows]


def delete_result(result_id: int, user_id: int) -> bool:
    with _conn() as c:
        return c.execute(
            "DELETE FROM results WHERE id = ? AND user_id = ?",
            (result_id, user_id),
        ).rowcount > 0
