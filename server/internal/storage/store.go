package storage

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"time"

	_ "modernc.org/sqlite"
)

type Store struct {
	db *sql.DB
}

// New opens (or creates) a sqlite database file at path and ensures schema.
func New(dbPath string) (*Store, error) {
	dsn := fmt.Sprintf("file:%s?_pragma=busy_timeout=5000", dbPath)
	db, err := sql.Open("sqlite", dsn)
	if err != nil {
		return nil, err
	}
	if err := migrate(db); err != nil {
		_ = db.Close()
		return nil, err
	}
	return &Store{db: db}, nil
}

func migrate(db *sql.DB) error {
	// new normalized table
	if _, err := db.Exec(`
CREATE TABLE IF NOT EXISTS items (
  type TEXT NOT NULL,
  id   TEXT NOT NULL,
  value TEXT NOT NULL,
  updated_at DATETIME NOT NULL,
  PRIMARY KEY (type, id)
);
`); err != nil {
		return err
	}
	//    // legacy kv for migration (may or may not exist)
	//    if _, err := db.Exec(`
	//CREATE TABLE IF NOT EXISTS kv (
	//  key TEXT PRIMARY KEY,
	//  value TEXT NOT NULL,
	//  updated_at DATETIME NOT NULL
	//);
	//`); err != nil {
	//        return err
	//    }
	// migrate legacy kv data into items once (if items empty)
	var cnt int
	if err := db.QueryRow("SELECT COUNT(*) FROM items").Scan(&cnt); err != nil {
		return err
	}
	if cnt == 0 {
		// settings
		if v, ok, _ := getKV(db, "settings"); ok {
			_ = setItem(db, "settings", "settings", v)
		}
		// selected
		if v, ok, _ := getKV(db, "selected"); ok {
			_ = setItem(db, "meta", "selected", v)
		}
		// servers (split array)
		if v, ok, _ := getKV(db, "servers"); ok {
			var list []map[string]interface{}
			if err := json.Unmarshal([]byte(v), &list); err == nil {
				for _, m := range list {
					if id, ok := m["id"].(string); ok && id != "" {
						if b, err := json.Marshal(m); err == nil {
							_ = setItem(db, "server", id, string(b))
						}
					}
				}
			}
		}
	}
	return nil
}

func (s *Store) Close() error { return s.db.Close() }

// Generic items API
func (s *Store) GetItem(typ, id string) (string, bool, error) {
	var value string
	err := s.db.QueryRow("SELECT value FROM items WHERE type=? AND id=?", typ, id).Scan(&value)
	if err == sql.ErrNoRows {
		return "", false, nil
	}
	if err != nil {
		return "", false, err
	}
	return value, true, nil
}

func (s *Store) SetItem(typ, id, value string) error { return setItem(s.db, typ, id, value) }

func setItem(db *sql.DB, typ, id, value string) error {
	_, err := db.Exec("INSERT INTO items(type,id,value,updated_at) VALUES(?,?,?,?) ON CONFLICT(type,id) DO UPDATE SET value=excluded.value, updated_at=excluded.updated_at", typ, id, value, time.Now())
	return err
}

func (s *Store) ListItems(typ string) ([]string, error) {
	rows, err := s.db.Query("SELECT value FROM items WHERE type=? ORDER BY updated_at", typ)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []string
	for rows.Next() {
		var v string
		if err := rows.Scan(&v); err != nil {
			return nil, err
		}
		out = append(out, v)
	}
	return out, rows.Err()
}

func (s *Store) DeleteItem(typ, id string) error {
	_, err := s.db.Exec("DELETE FROM items WHERE type=? AND id=?", typ, id)
	return err
}

// legacy helpers
func getKV(db *sql.DB, key string) (string, bool, error) {
	var v string
	err := db.QueryRow("SELECT value FROM kv WHERE key=?", key).Scan(&v)
	if err == sql.ErrNoRows {
		return "", false, nil
	}
	if err != nil {
		return "", false, err
	}
	return v, true, nil
}
