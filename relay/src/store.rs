//! Tiny SQLite-backed state: one push token per identity, plus a short queue of
//! undelivered (sealed) envelopes. Deliberately minimal — see the privacy note
//! in README. Low traffic, so a single mutex-guarded connection is plenty.

use std::sync::Mutex;

use rusqlite::Connection;

pub struct Store {
    conn: Mutex<Connection>,
}

pub struct Queued {
    pub message_id: String,
    pub envelope: Vec<u8>,
}

impl Store {
    pub fn open(path: &str) -> anyhow::Result<Self> {
        let conn = Connection::open(path)?;
        conn.execute_batch(
            "PRAGMA journal_mode=WAL;
             CREATE TABLE IF NOT EXISTS registrations (
                identity   TEXT PRIMARY KEY,
                push_token TEXT NOT NULL,
                updated_at INTEGER NOT NULL
             );
             CREATE TABLE IF NOT EXISTS queue (
                recipient  TEXT NOT NULL,
                message_id TEXT NOT NULL,
                envelope   BLOB NOT NULL,
                created_at INTEGER NOT NULL,
                PRIMARY KEY (recipient, message_id)
             );
             CREATE INDEX IF NOT EXISTS queue_recipient ON queue(recipient);",
        )?;
        // PushKit/CallKit VoIP token, added later — ignore the error when the
        // column already exists (SQLite has no IF NOT EXISTS for ADD COLUMN).
        let _ = conn.execute("ALTER TABLE registrations ADD COLUMN voip_token TEXT", []);
        Ok(Self { conn: Mutex::new(conn) })
    }

    /// Upserts the APNs token, and the VoIP token when one is supplied. A `None`
    /// VoIP token leaves any existing one intact (older clients omit it).
    pub fn upsert_registration(
        &self,
        identity: &str,
        push_token: &str,
        voip_token: Option<&str>,
        now: i64,
    ) -> anyhow::Result<()> {
        self.conn.lock().unwrap().execute(
            "INSERT INTO registrations (identity, push_token, voip_token, updated_at)
             VALUES (?1, ?2, ?3, ?4)
             ON CONFLICT(identity) DO UPDATE SET
                push_token=?2,
                voip_token=COALESCE(?3, voip_token),
                updated_at=?4",
            (identity, push_token, voip_token, now),
        )?;
        Ok(())
    }

    pub fn push_token(&self, identity: &str) -> anyhow::Result<Option<String>> {
        let conn = self.conn.lock().unwrap();
        let mut stmt =
            conn.prepare("SELECT push_token FROM registrations WHERE identity=?1")?;
        let mut rows = stmt.query([identity])?;
        Ok(match rows.next()? {
            Some(row) => Some(row.get(0)?),
            None => None,
        })
    }

    /// The PushKit VoIP token for an identity, if one was ever registered.
    pub fn voip_token(&self, identity: &str) -> anyhow::Result<Option<String>> {
        let conn = self.conn.lock().unwrap();
        let mut stmt =
            conn.prepare("SELECT voip_token FROM registrations WHERE identity=?1")?;
        let mut rows = stmt.query([identity])?;
        Ok(match rows.next()? {
            // The column is nullable, so the cell itself may be NULL.
            Some(row) => row.get::<_, Option<String>>(0)?,
            None => None,
        })
    }

    /// Dedups on (recipient, message_id) — a re-send is a no-op, mirroring the
    /// app's message-id dedup so relay + Bluetooth can both carry a message.
    pub fn enqueue(
        &self,
        recipient: &str,
        message_id: &str,
        envelope: &[u8],
        now: i64,
    ) -> anyhow::Result<()> {
        self.conn.lock().unwrap().execute(
            "INSERT OR IGNORE INTO queue (recipient, message_id, envelope, created_at)
             VALUES (?1, ?2, ?3, ?4)",
            (recipient, message_id, envelope, now),
        )?;
        Ok(())
    }

    pub fn inbox(&self, recipient: &str) -> anyhow::Result<Vec<Queued>> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare(
            "SELECT message_id, envelope FROM queue WHERE recipient=?1 ORDER BY created_at",
        )?;
        let rows = stmt.query_map([recipient], |row| {
            Ok(Queued { message_id: row.get(0)?, envelope: row.get(1)? })
        })?;
        Ok(rows.collect::<Result<Vec<_>, _>>()?)
    }

    pub fn ack(&self, recipient: &str, message_ids: &[String]) -> anyhow::Result<()> {
        let mut conn = self.conn.lock().unwrap();
        let tx = conn.transaction()?;
        for id in message_ids {
            tx.execute(
                "DELETE FROM queue WHERE recipient=?1 AND message_id=?2",
                (recipient, id),
            )?;
        }
        tx.commit()?;
        Ok(())
    }

    /// Drops undelivered envelopes older than `cutoff` (epoch ms) so the queue
    /// can't grow without bound.
    pub fn cleanup(&self, cutoff: i64) -> anyhow::Result<usize> {
        let n = self
            .conn
            .lock()
            .unwrap()
            .execute("DELETE FROM queue WHERE created_at < ?1", [cutoff])?;
        Ok(n)
    }
}
