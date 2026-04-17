-- ─────────────────────────────────────────────────────────────
-- FairTicket — MySQL 8.0 Schema
-- Contribution: Pranav Bhoj
--
-- Primary responsibility:
--   ○  users, events, seats, tickets  ← authored by Paras
--   ✅ ticket_queue, seat_locks, resale_market,
--      ticket_scan_logs, login_attempts  ← authored by Pranav
--   ✅ prevent_scalping BEFORE INSERT trigger
--   ✅ Indexes on anti-scalping tables
-- ─────────────────────────────────────────────────────────────

-- ══════════════════════════════════════════════════════════════
-- SECTION 2 — ANTI-SCALPING & SECURITY TABLES  [Pranav Bhoj]
-- ══════════════════════════════════════════════════════════════

-- Virtual queue: tracks users waiting per event in fair positional order
CREATE TABLE ticket_queue (
  queue_id       CHAR(36)    PRIMARY KEY,
  event_id       CHAR(36)    NOT NULL,
  user_id        CHAR(36)    NOT NULL,
  queue_position INT         NOT NULL,
  entry_time     DATETIME    DEFAULT NOW(),
  status         VARCHAR(20) DEFAULT 'WAITING',
  FOREIGN KEY (event_id) REFERENCES events(event_id),
  FOREIGN KEY (user_id)  REFERENCES users(user_id)
);

-- Temporarily holds a seat after purchase (5-minute grace period)
CREATE TABLE seat_locks (
  lock_id    CHAR(36)  PRIMARY KEY,
  seat_id    CHAR(36)  UNIQUE NOT NULL,
  user_id    CHAR(36)  NOT NULL,
  lock_time  DATETIME  DEFAULT NOW(),
  expires_at DATETIME  NOT NULL,
  FOREIGN KEY (seat_id)  REFERENCES seats(seat_id),
  FOREIGN KEY (user_id)  REFERENCES users(user_id)
);

-- Resale marketplace with DB-level price enforcement via trigger below
CREATE TABLE resale_market (
  listing_id CHAR(36)      PRIMARY KEY,
  ticket_id  CHAR(36)      NOT NULL,
  seller_id  CHAR(36)      NOT NULL,
  price      DECIMAL(10,2) NOT NULL,
  listed_at  DATETIME      DEFAULT NOW(),
  status     VARCHAR(20)   DEFAULT 'ACTIVE',
  FOREIGN KEY (ticket_id) REFERENCES tickets(ticket_id),
  FOREIGN KEY (seller_id) REFERENCES users(user_id)
);

-- Every scan logged here; second scan on same ticket_id = duplicate → rejected
CREATE TABLE ticket_scan_logs (
  log_id     CHAR(36) PRIMARY KEY,
  ticket_id  CHAR(36) NOT NULL,
  scanned_at DATETIME DEFAULT NOW(),
  FOREIGN KEY (ticket_id) REFERENCES tickets(ticket_id)
);

-- Logs every login attempt per IP for bot/suspicious activity detection
CREATE TABLE login_attempts (
  id           INT AUTO_INCREMENT PRIMARY KEY,
  user_id      CHAR(36),
  ip_address   VARCHAR(100),
  success      BOOLEAN,
  attempted_at DATETIME DEFAULT NOW()
);

-- ══════════════════════════════════════════════════════════════
-- SECTION 3 — INDEXES  [Pranav Bhoj — anti-scalping tables]
--             + core table indexes  [Paras Jadhav]
-- ══════════════════════════════════════════════════════════════

CREATE INDEX idx_events_date        ON events(event_date);           -- [Paras]
CREATE INDEX idx_tickets_owner      ON tickets(owner_user_id);       -- [Paras]
CREATE INDEX idx_seats_event_status ON seats(event_id, status);      -- [Paras]
CREATE INDEX idx_seat_locks_seat    ON seat_locks(seat_id);          -- [Pranav]
CREATE INDEX idx_queue_event_pos    ON ticket_queue(event_id, queue_position); -- [Pranav]

-- ══════════════════════════════════════════════════════════════
-- SECTION 4 — ANTI-SCALPING TRIGGER  [Pranav Bhoj]
--
-- Fires BEFORE every INSERT into resale_market.
-- Looks up the original ticket price and raises a SQLSTATE error
-- if the new listing price exceeds it — enforcement at DB level,
-- impossible to bypass even with direct SQL access.
-- ══════════════════════════════════════════════════════════════

DROP TRIGGER IF EXISTS prevent_scalping;

DELIMITER //
CREATE TRIGGER prevent_scalping
  BEFORE INSERT ON resale_market
  FOR EACH ROW
BEGIN
  DECLARE orig_price DECIMAL(10,2);

  -- Join tickets → events to find the original face-value price
  SELECT e.ticket_price INTO orig_price
  FROM tickets t
  JOIN events e ON t.event_id = e.event_id
  WHERE t.ticket_id = NEW.ticket_id;

  -- Block the INSERT if resale price exceeds original
  IF NEW.price > orig_price THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Resale price exceeds original ticket price — scalping prevented';
  END IF;
END //
DELIMITER ;
