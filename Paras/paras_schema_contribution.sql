-- ─────────────────────────────────────────────────────────────
-- FairTicket — MySQL 8.0 Schema
-- Contribution: Paras Jadhav
--
-- Covers:
--   - Database creation
--   - Core tables: users, events, seats, tickets
--   - Performance indexes on frequently queried columns
-- ─────────────────────────────────────────────────────────────

CREATE DATABASE IF NOT EXISTS fairticket
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE fairticket;

-- ── CORE TABLES ───────────────────────────────────────────────

-- Stores registered users; is_admin flag controls admin access
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

-- Each event has a fixed seat capacity and sale window
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

-- Individual seat records per event; status tracks availability
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

-- Ticket record created atomically at purchase; tied to owner and seat
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

-- ── PERFORMANCE INDEXES ───────────────────────────────────────
-- Speeds up the most common query patterns across the application

CREATE INDEX idx_events_date        ON events(event_date);
CREATE INDEX idx_tickets_owner      ON tickets(owner_user_id);
CREATE INDEX idx_seats_event_status ON seats(event_id, status);
