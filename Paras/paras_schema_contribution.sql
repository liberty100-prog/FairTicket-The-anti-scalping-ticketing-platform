-- ─────────────────────────────────────────────────────────────
-- FairTicket — MySQL 8.0 Schema
-- Contribution: Paras Jadhav
--
-- Primary responsibility:
--   ✅ Database creation
--   ✅ users, events, seats, tickets  ← authored by Paras
--   ○  ticket_queue, seat_locks, resale_market,
--      ticket_scan_logs, login_attempts  ← authored by Pranav
--   ✅ Performance indexes on core tables
-- ─────────────────────────────────────────────────────────────

CREATE DATABASE IF NOT EXISTS fairticket
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE fairticket;

-- ══════════════════════════════════════════════════════════════
-- SECTION 1 — CORE TABLES  [Paras Jadhav]
-- ══════════════════════════════════════════════════════════════

-- Stores all registered users; is_admin flag gates admin routes
CREATE TABLE IF NOT EXISTS users (
  user_id          CHAR(36)     PRIMARY KEY,
  name             TEXT         NOT NULL,
  email            VARCHAR(255) UNIQUE NOT NULL,
  phone            VARCHAR(50),
  verified_id_hash TEXT,
  password_hash    TEXT         NOT NULL,
  is_admin         BOOLEAN      DEFAULT FALSE,
  created_at       DATETIME     DEFAULT NOW()
);

-- Each event has a fixed seat capacity and a sale window
CREATE TABLE IF NOT EXISTS events (
  event_id        CHAR(36)      PRIMARY KEY,
  event_name      TEXT          NOT NULL,
  venue           TEXT          NOT NULL,
  event_date      DATE          NOT NULL,
  total_seats     INT           NOT NULL,
  available_seats INT           NOT NULL,
  ticket_price    DECIMAL(10,2) NOT NULL,
  sale_start_time DATETIME      NOT NULL
);

-- Individual seat records per event; status tracks booking state
CREATE TABLE IF NOT EXISTS seats (
  seat_id     CHAR(36)    PRIMARY KEY,
  event_id    CHAR(36)    NOT NULL,
  section     VARCHAR(50) NOT NULL,
  row_label   VARCHAR(10) NOT NULL,
  seat_number INT         NOT NULL,
  status      VARCHAR(20) DEFAULT 'AVAILABLE'
              CHECK (status IN ('AVAILABLE', 'RESERVED', 'PURCHASED')),
  FOREIGN KEY (event_id) REFERENCES events(event_id) ON DELETE CASCADE
);

-- Ticket record created atomically at purchase; tied to one seat and one owner
CREATE TABLE IF NOT EXISTS tickets (
  ticket_id     CHAR(36)    PRIMARY KEY,
  event_id      CHAR(36)    NOT NULL,
  seat_id       CHAR(36)    NOT NULL,
  owner_user_id CHAR(36)    NOT NULL,
  purchase_time DATETIME    DEFAULT NOW(),
  ticket_status VARCHAR(20) DEFAULT 'PURCHASED'
                CHECK (ticket_status IN ('RESERVED','PURCHASED','RESALE_LISTED','USED')),
  FOREIGN KEY (event_id)      REFERENCES events(event_id),
  FOREIGN KEY (seat_id)       REFERENCES seats(seat_id),
  FOREIGN KEY (owner_user_id) REFERENCES users(user_id)
);

-- ══════════════════════════════════════════════════════════════
-- SECTION 2 — ANTI-SCALPING & SECURITY TABLES  [Pranav Bhoj]
-- ══════════════════════════════════════════════════════════════

-- Virtual queue: tracks users waiting per event in fair order
CREATE TABLE IF NOT EXISTS ticket_queue (
  queue_id       CHAR(36)    PRIMARY KEY,
  event_id       CHAR(36)    NOT NULL,
  user_id        CHAR(36)    NOT NULL,
  queue_position INT         NOT NULL,
  entry_time     DATETIME    DEFAULT NOW(),
  status         VARCHAR(20) DEFAULT 'WAITING',
  FOREIGN KEY (event_id) REFERENCES events(event_id),
  FOREIGN KEY (user_id)  REFERENCES users(user_id)
);

-- Temporarily holds a seat after purchase (5-minute grace period lock)
CREATE TABLE IF NOT EXISTS seat_locks (
  lock_id    CHAR(36)  PRIMARY KEY,
  seat_id    CHAR(36)  UNIQUE NOT NULL,
  user_id    CHAR(36)  NOT NULL,
  lock_time  DATETIME  DEFAULT NOW(),
  expires_at DATETIME  NOT NULL,
  FOREIGN KEY (seat_id)  REFERENCES seats(seat_id),
  FOREIGN KEY (user_id)  REFERENCES users(user_id)
);

-- Controlled resale marketplace; price enforced by prevent_scalping trigger
CREATE TABLE IF NOT EXISTS resale_market (
  listing_id CHAR(36)      PRIMARY KEY,
  ticket_id  CHAR(36)      NOT NULL,
  seller_id  CHAR(36)      NOT NULL,
  price      DECIMAL(10,2) NOT NULL,
  listed_at  DATETIME      DEFAULT NOW(),
  status     VARCHAR(20)   DEFAULT 'ACTIVE',
  FOREIGN KEY (ticket_id) REFERENCES tickets(ticket_id),
  FOREIGN KEY (seller_id) REFERENCES users(user_id)
);

-- Every scan logged here; duplicate ticket_id = rejected at gate
CREATE TABLE IF NOT EXISTS ticket_scan_logs (
  log_id     CHAR(36) PRIMARY KEY,
  ticket_id  CHAR(36) NOT NULL,
  scanned_at DATETIME DEFAULT NOW(),
  FOREIGN KEY (ticket_id) REFERENCES tickets(ticket_id)
);

-- Logs every login attempt per IP; powers suspicious activity detection
CREATE TABLE IF NOT EXISTS login_attempts (
  id           INT AUTO_INCREMENT PRIMARY KEY,
  user_id      CHAR(36),
  ip_address   VARCHAR(100),
  success      BOOLEAN,
  attempted_at DATETIME DEFAULT NOW()
);

-- ══════════════════════════════════════════════════════════════
-- SECTION 3 — INDEXES  [Paras Jadhav]
-- Speeds up the most common query patterns
-- ══════════════════════════════════════════════════════════════

CREATE INDEX idx_events_date        ON events(event_date);
CREATE INDEX idx_tickets_owner      ON tickets(owner_user_id);
CREATE INDEX idx_seat_locks_seat    ON seat_locks(seat_id);
CREATE INDEX idx_queue_event_pos    ON ticket_queue(event_id, queue_position);
CREATE INDEX idx_seats_event_status ON seats(event_id, status);

-- ── ANTI-SCALPING TRIGGER  [Pranav Bhoj] ─────────────────────
-- Fires BEFORE every INSERT into resale_market.
-- Blocks any resale price above the event's original ticket price.

DROP TRIGGER IF EXISTS prevent_scalping;

DELIMITER //
CREATE TRIGGER prevent_scalping
  BEFORE INSERT ON resale_market
  FOR EACH ROW
BEGIN
  DECLARE orig_price DECIMAL(10,2);

  SELECT e.ticket_price INTO orig_price
  FROM tickets t
  JOIN events e ON t.event_id = e.event_id
  WHERE t.ticket_id = NEW.ticket_id;

  IF NEW.price > orig_price THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Resale price exceeds original ticket price — scalping prevented';
  END IF;
END //
DELIMITER ;
