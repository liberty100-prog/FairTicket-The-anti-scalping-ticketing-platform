-- ─────────────────────────────────────────────────────────────
-- FairTicket — MySQL 8.0 Schema
-- Contribution: Pranav Bhoj
--
-- Covers:
--   - Anti-scalping infrastructure tables:
--       ticket_queue  — virtual queue system
--       seat_locks    — post-purchase seat hold (5-min grace period)
--       resale_market — controlled resale marketplace
--       ticket_scan_logs — entry duplicate-scan prevention
--       login_attempts   — suspicious IP detection data
--   - Performance indexes for queue and lock lookups
--   - `prevent_scalping` MySQL BEFORE INSERT trigger —
--       blocks any resale listing priced above the original ticket price
-- ─────────────────────────────────────────────────────────────

USE fairticket;

-- ── ANTI-SCALPING & SECURITY TABLES ──────────────────────────

-- Tracks users waiting in a virtual queue per event
-- queue_position determines fair order of access
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

-- Temporarily locks a seat after purchase to prevent concurrent booking
-- Lock expires after 5 minutes (managed in application logic)
CREATE TABLE IF NOT EXISTS seat_locks (
  lock_id    CHAR(36)  PRIMARY KEY,
  seat_id    CHAR(36)  UNIQUE NOT NULL,
  user_id    CHAR(36)  NOT NULL,
  lock_time  DATETIME  DEFAULT NOW(),
  expires_at DATETIME  NOT NULL,
  FOREIGN KEY (seat_id)  REFERENCES seats(seat_id),
  FOREIGN KEY (user_id)  REFERENCES users(user_id)
);

-- Controlled resale marketplace — price enforced by prevent_scalping trigger
-- Sellers may only list at or below the original ticket price
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

-- Every scan is logged here; duplicate ticket_id = rejected entry
CREATE TABLE IF NOT EXISTS ticket_scan_logs (
  log_id     CHAR(36) PRIMARY KEY,
  ticket_id  CHAR(36) NOT NULL,
  scanned_at DATETIME DEFAULT NOW(),
  FOREIGN KEY (ticket_id) REFERENCES tickets(ticket_id)
);

-- Logs every login attempt (success or failure) per IP address
-- Used by admin to detect and flag suspicious bot activity
CREATE TABLE IF NOT EXISTS login_attempts (
  id           INT AUTO_INCREMENT PRIMARY KEY,
  user_id      CHAR(36),
  ip_address   VARCHAR(100),
  success      BOOLEAN,
  attempted_at DATETIME DEFAULT NOW()
);

-- ── INDEXES ───────────────────────────────────────────────────

CREATE INDEX idx_seat_locks_seat ON seat_locks(seat_id);
CREATE INDEX idx_queue_event_pos ON ticket_queue(event_id, queue_position);

-- ── ANTI-SCALPING TRIGGER ─────────────────────────────────────
-- Fires BEFORE every INSERT into resale_market.
-- Looks up the original ticket price from the events table.
-- Raises a SQLSTATE error if the resale price exceeds it —
-- making price enforcement atomic and impossible to bypass at the DB level.

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
