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

CREATE DATABASE fairticket
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE fairticket;

-- ══════════════════════════════════════════════════════════════
-- SECTION 1 — CORE TABLES  [Paras Jadhav]
-- ══════════════════════════════════════════════════════════════

-- Stores all registered users; is_admin flag gates admin routes
CREATE TABLE users (
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
CREATE TABLE events (
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
CREATE TABLE seats (
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
CREATE TABLE tickets (
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


