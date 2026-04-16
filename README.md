# 🎟️ FairTicket — Anti-Scalping Ticketing System

A full-stack anti-black-market ticketing platform built with Node.js, Express, MySQL 8.0, and Vanilla JavaScript. Designed to ensure fair access to tickets by preventing scalping, bot abuse, and double-booking.

---

## 🚀 Tech Stack

| Layer | Technology |
|---|---|
| **Backend** | Node.js + Express |
| **Database** | MySQL 8.0 |
| **Frontend** | Vanilla JavaScript (SPA) |
| **Auth** | JWT + bcrypt (12 rounds) |
| **ORM/Driver** | mysql2/promise |

---

## ✅ Core Features

- **Identity-bound tickets** — Each ticket is tied to a verified user account; free transfer is not allowed
- **Virtual queue system** — Users join a fair queue during ticket drops instead of racing the server
- **Atomic seat booking** — Uses SQL transactions with row-level locking (`FOR UPDATE`) to prevent double-booking race conditions
- **Controlled resale marketplace** — Sellers can only list at or below the original price, enforced by a MySQL `BEFORE INSERT` trigger (`prevent_scalping`) and a server-side guard
- **Duplicate-entry prevention** — Every scan is logged; second scans on the same ticket are rejected immediately
- **4-ticket limit** — Maximum 4 tickets per user per event, enforced atomically at the database level

---

## 🔒 Security & Anti-Bot

- **JWT-based authentication** with bcrypt password hashing (12 rounds)
- **Rate limiting** on the booking endpoint (5 requests/min per IP)
- **Login attempt logging** with suspicious IP detection — flags IPs with >10 failed attempts per hour
- **SQL row-level locking (`FOR UPDATE`)** inside atomic transactions prevents concurrent double-booking; a `seat_locks` table adds a 5-minute post-purchase grace period

---

## 🗂️ Project Structure

```
Ticketing System/
├── server.js          # Express backend — all API routes
├── schema.sql         # Database schema (run this first)
├── seed.sql           # Sample data + test accounts (run this second)
├── package.json
├── .env.example       # Copy to .env and fill in your values
└── frontend/
    ├── index.html     # Single-page app entry point
    ├── app.js         # Frontend SPA logic
    └── style.css      # Styles

---

This is group project consisting of members:
1. Paras Jadhav
2. Pranav Bhoj
3. Aryan Gurav

