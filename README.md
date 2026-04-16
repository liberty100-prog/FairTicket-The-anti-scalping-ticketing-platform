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
```

---

## ⚙️ Setup Instructions

### Prerequisites
- [Node.js](https://nodejs.org/) v18+
- [MySQL 8.0](https://dev.mysql.com/downloads/mysql/)
- [MySQL Workbench](https://dev.mysql.com/downloads/workbench/) (recommended)

---

### Step 1 — Clone / Download the project

```bash
# If using Git
git clone <repo-url>
cd "Ticketing System"
```

Or unzip the project folder if shared as a ZIP file.

---

### Step 2 — Install dependencies

```bash
npm install
```

---

### Step 3 — Set up the database

Open **MySQL Workbench**, connect to your local MySQL server, then run the following files **in order**:

1. `schema.sql` — creates the `fairticket` database and all tables
2. `seed.sql` — inserts sample events, seats, and test user accounts

---

### Step 4 — Configure environment variables

Copy `.env.example` to `.env`:

```bash
copy .env.example .env
```

Edit `.env` with your MySQL credentials:

```env
DB_HOST=localhost
DB_PORT=3306
DB_USER=root
DB_PASSWORD=        # leave blank if no password set
DB_NAME=fairticket
JWT_SECRET=your_secret_key_here
PORT=3001
```

---

### Step 5 — Start the server

```bash
node server.js
```

You should see:
```
✓ MySQL connection verified
✓ FairTicket API running on http://localhost:3001
```

---

### Step 6 — Open the frontend

Open your browser and go to:
```
http://localhost:3001
```

---

## 🔑 Test Credentials

| Role | Email | Password |
|---|---|---|
| 👑 Admin | `admin@fairticket.com` | `Admin@1234` |
| 👤 Regular User | `user@fairticket.com` | `User@1234` |

> **Admin** has access to the Analytics dashboard, Event Management panel, and Entry Scanner.

---

## 🌐 API Endpoints

| Method | Endpoint | Auth | Description |
|---|---|---|---|
| POST | `/api/register` | — | Register a new user |
| POST | `/api/login` | — | Login and receive JWT |
| GET | `/api/events` | — | List all events |
| GET | `/api/events/:id/seats` | ✅ | Get seat map for an event |
| POST | `/api/book` | ✅ | Book selected seats (max 4) |
| GET | `/api/my-tickets` | ✅ | View your tickets |
| POST | `/api/queue/join` | ✅ | Join the virtual queue |
| GET | `/api/my-queues` | ✅ | View your queue positions |
| GET | `/api/resale` | — | Browse resale listings |
| POST | `/api/resale` | ✅ | List a ticket for resale |
| POST | `/api/resale/:id/buy` | ✅ | Buy a resale ticket |
| POST | `/api/scan` | ✅ | Scan a ticket for entry |
| GET | `/api/analytics` | 👑 Admin | View platform analytics |
| GET | `/api/admin/events` | 👑 Admin | List all events (admin view) |
| POST | `/api/admin/events` | 👑 Admin | Create a new event |
| DELETE | `/api/admin/events/:id` | 👑 Admin | Delete an event |
| GET | `/api/admin/suspicious-logins` | 👑 Admin | View flagged IPs |

---

## 👥 Accessing from Another Device (Same Network)

If your friends are on the **same WiFi**, they can access the app using your machine's local IP:

1. Find your IP: run `ipconfig` and look for the **IPv4 Address** (e.g. `192.168.0.103`)
2. In `frontend/app.js`, change line 6 to:
   ```js
   const API = "http://192.168.0.103:3001/api";
   ```
3. Share the updated `frontend/index.html` with your friend

> ⚠️ Your laptop must stay on and `node server.js` must be running.

---

## 🌍 Remote Access (Different Networks)

Use [ngrok](https://ngrok.com/) to expose your local server publicly:

```bash
# After starting node server.js, in a second terminal:
ngrok http 3001
```

Copy the generated URL (e.g. `https://abc123.ngrok-free.app`) and update `app.js`:
```js
const API = "https://abc123.ngrok-free.app/api";
```

> Note: The ngrok URL changes every time you restart it on the free tier.
