# Plan: Todo App with Authentication

## 1. Project Overview & Goals
Build a secure, full-stack Todo application with user registration, authentication, and personalized task management. Each user can only view, create, edit, and delete their own todos.

### Primary Stack & Core Architecture Decisions
- **Frontend**: React + Vite (SPA)
- **Vite Dev Proxy**: Vite development server proxies `/api` to `http://localhost:3000`. Frontend calls `/api` as same-origin requests (`credentials: 'include'`).
  - *Codespaces Note*: In GitHub Codespaces, forwarded ports run on different subdomains (e.g., `<port>-<guid>.app.github.dev`), which browsers treat as cross-site if accessed directly. Using Vite's reverse proxy for `/api` ensures the browser only speaks directly to the frontend origin, keeping cookies first-party/same-site and bypassing cross-site cookie restrictions in modern browsers and Codespaces port forwarding.
- **Backend**: Node.js + Express
  - `app.set('trust proxy', 1)` enabled to ensure accurate client IP identification by `express-rate-limit` behind reverse proxies (Codespaces port forwarders, NGINX, Cloudflare).
  - Payload limiting via `express.json({ limit: '10kb' })` to mitigate body payload DoS attacks.
- **Database/Storage**: SQLite via `better-sqlite3` (WAL mode, foreign keys enabled, parameterized queries exclusively).
- **Authentication**:
  - Salted password hashing via `bcrypt` (work factor 12).
  - Password length enforced strictly between **10 and 72 characters** (matching bcrypt 72-byte safe limit).
  - Short-lived JSON Web Tokens (JWT) stored in `httpOnly`, `SameSite=Lax` cookies.
  - **Pinned JWT Algorithm**: Hardcoded to `HS256` explicitly on sign (`algorithm: 'HS256'`) and on verify (`algorithms: ['HS256']`) to block algorithm confusion attacks.
  - **Fail-Fast Secret Validation**: Server refuses to start (`process.exit(1)`) if `JWT_SECRET` is missing or shorter than 32 characters.
  - **Constant-Time User Enumeration Defense**:
    - Generic response on login failure: identical `401 Unauthorized` with `{ "error": "Invalid email or password" }`.
    - Dummy `bcrypt.compare` executed against a pre-computed hash if user is not found in database to eliminate timing side-channels.
    - Generic response on registration if email already exists: identical success message without revealing account existence.
- **Access Control (No Resource Enumeration)**:
  - Non-owned todos return `404 Not Found` (never 403 Forbidden) on `PATCH` / `DELETE` to prevent attackers from discovering the existence of other users' tasks.
- **CSRF Protection**: Anti-CSRF token verification (`csrf-csrf` / double-submit cookie pattern) on all state-changing routes (`POST`, `PATCH`, `DELETE`) with `X-CSRF-Token` header.
- **Validation**: Server-side request validation using `zod` (todo title trimmed and restricted to max 200 characters).
- **Security**: `helmet`, explicit `cors` whitelist (defense-in-depth), `express-rate-limit` for auth endpoints.
- **Testing**: `vitest` + `supertest` for backend API testing, `vitest` + `@testing-library/react` for frontend testing.

---

## 2. Pinned Dependencies (Exact Versions)

To satisfy the non-negotiable security requirement of pinning dependencies and avoiding drift or unvetted updates:

### Server Dependencies
```json
{
  "dependencies": {
    "bcrypt": "5.1.1",
    "cookie-parser": "1.4.7",
    "cors": "2.8.5",
    "csrf-csrf": "3.1.0",
    "dotenv": "16.4.7",
    "express": "4.21.2",
    "express-rate-limit": "7.5.0",
    "helmet": "8.0.0",
    "jsonwebtoken": "9.0.2",
    "better-sqlite3": "11.8.1",
    "zod": "3.24.2"
  },
  "devDependencies": {
    "supertest": "7.0.0",
    "vitest": "3.0.7"
  }
}
```

### Client Dependencies
```json
{
  "dependencies": {
    "lucide-react": "0.475.0",
    "react": "18.3.1",
    "react-dom": "18.3.1"
  },
  "devDependencies": {
    "@testing-library/jest-dom": "6.6.3",
    "@testing-library/react": "16.2.0",
    "@vitejs/plugin-react": "4.3.4",
    "jsdom": "26.0.0",
    "vite": "6.2.0"
  }
}
```

---

## 3. Directory & File Structure

```text
workspace/todo-app/
├── .env.example
├── .gitignore
├── package.json               # Root workspace orchestrating server & client with exact pinned versions
├── package-lock.json
├── PLAN.md                    # This architecture and implementation plan
├── server/
│   ├── src/
│   │   ├── config/
│   │   │   ├── constants.js   # Pre-computed bcrypt dummy hash & JWT algorithm constants
│   │   │   └── env.js         # Startup validation (exits if JWT_SECRET missing or < 32 chars)
│   │   ├── db/
│   │   │   ├── connection.js  # better-sqlite3 instance, WAL mode, foreign keys
│   │   │   └── schema.sql     # DDL for users and todos tables
│   │   ├── middleware/
│   │   │   ├── auth.js        # JWT verification (pinned to algorithms: ['HS256']) from httpOnly cookie
│   │   │   ├── csrf.js        # CSRF token generation & validation on state-changing routes
│   │   │   ├── rateLimiter.js # express-rate-limit configured with trust proxy support
│   │   │   ├── validate.js    # Zod validation middleware
│   │   │   └── errorHandler.js# Centralized error handler (no leaking stack traces)
│   │   ├── routes/
│   │   │   ├── auth.js        # /api/auth (register, login, logout, me, csrf-token)
│   │   │   └── todos.js       # /api/todos (CRUD with 404 on unowned items)
│   │   ├── schemas/
│   │   │   ├── auth.schema.js # Zod schemas (password: 10-72 chars, valid email)
│   │   │   └── todo.schema.js # Zod schemas (title: 1-200 chars trimmed)
│   │   └── index.js           # Express app setup, trust proxy, json limit 10kb, helmet, CORS, routes
│   └── tests/
│       ├── auth.test.js       # Auth API integration tests (generic errors, dummy compare, 10-72 pw)
│       ├── csrf.test.js       # CSRF protection verification on state-changing routes
│       └── todos.test.js      # Todos API integration tests (verifies 404 on unowned todos)
└── client/
    ├── index.html
    ├── vite.config.js         # Configured with dev server proxy (/api -> http://localhost:3000)
    └── src/
        ├── api/
        │   └── client.js      # Fetch wrapper calling /api same-origin with X-CSRF-Token
        ├── components/
        │   ├── AuthForm.jsx   # Login & Register forms (10-72 char password validation)
        │   ├── TodoItem.jsx   # Individual todo item with toggle & delete
        │   ├── TodoList.jsx   # List of todos with filter (all, active, completed)
        │   └── Navbar.jsx     # Header with user info & logout button
        ├── context/
        │   └── AuthContext.jsx# Authentication & CSRF state provider
        ├── App.jsx            # Main view switcher (Auth view vs Todo dashboard)
        ├── main.jsx           # React DOM root
        └── index.css          # Clean, modern CSS styling
```

---

## 4. Data Model & SQLite Schema

```sql
-- server/src/db/schema.sql

PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    email TEXT UNIQUE NOT NULL COLLATE NOCASE,
    password_hash TEXT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS todos (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    title TEXT NOT NULL,
    completed INTEGER NOT NULL DEFAULT 0 CHECK (completed IN (0, 1)),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_todos_user_id ON todos(user_id);
```

---

## 5. API Endpoints & Contracts

### Authentication (`/api/auth`)
| Method | Endpoint | Request Body | Description | Auth Required | CSRF Protected | Rate Limited |
|---|---|---|---|---|---|---|
| `GET` | `/api/auth/csrf-token` | None | Returns CSRF token and sets CSRF cookie | No | No | No |
| `POST` | `/api/auth/register` | `{ email, password }` | Registers user (password: 10–72 chars). **If email exists, returns generic `200 {"message": "Registration received. You may now log in."}` without error or duplicate insert.** | No | Yes | Yes (max 10 req/15min) |
| `POST` | `/api/auth/login` | `{ email, password }` | Validates credentials, sets `httpOnly` auth cookie. **If email not found, runs dummy bcrypt compare and returns generic `401 {"error": "Invalid email or password"}`.** | No | Yes | Yes (max 10 req/15min) |
| `POST` | `/api/auth/logout` | None | Clears the `httpOnly` auth cookie | Yes | Yes | No |
| `GET` | `/api/auth/me` | None | Returns currently authenticated user `{ id, email }` | Yes | No | No |

> [!IMPORTANT]
> **Authentication Enumeration & Timing Protections**:
> 1. **Registration**: If an email is already registered, the backend returns a generic success response (`200 OK` `{ "message": "Registration received. You may now log in." }`) instead of revealing that the email is taken.
> 2. **Login**: Both non-existent email and incorrect password return `401 Unauthorized` `{ "error": "Invalid email or password" }`.
> 3. **Timing Equalization**: When an email is not found, the backend executes `bcrypt.compare(password, DUMMY_HASH)` against a pre-computed valid bcrypt hash so response latency is indistinguishable from an account that exists.

### Todos (`/api/todos`)
| Method | Endpoint | Request Body / Params | Description | Auth Required | CSRF Protected | Ownership Check |
|---|---|---|---|---|---|---|
| `GET` | `/api/todos` | Query: `?status=all|active|completed` | Returns all todos belonging to `req.user.id` | Yes | No | Yes (scoped to `user_id`) |
| `POST` | `/api/todos` | `{ title }` | Creates a new todo (title: 1–200 chars) bound to `req.user.id` | Yes | Yes | Yes (`user_id = req.user.id`) |
| `PATCH` | `/api/todos/:id` | `{ title?, completed? }` | Updates todo only if `user_id === req.user.id`. **Returns `404 Not Found` if todo does not exist OR belongs to another user.** | Yes | Yes | Yes (always 404 for unowned items) |
| `DELETE` | `/api/todos/:id` | Param: `id` | Deletes todo only if `user_id === req.user.id`. **Returns `404 Not Found` if todo does not exist OR belongs to another user.** | Yes | Yes | Yes (always 404 for unowned items) |

---

## 6. Security & Threat Modeling (OWASP Top 10)

| Threat Category | Potential Risk | Mitigation in this App |
|---|---|---|
| **A01: Broken Access Control (IDOR & Info Leaks)** | User attempts to discover or manipulate another user's todos via `:id`. | • Queries include `AND user_id = ?`.<br>• **Non-Owned Resource Cloaking**: If a todo is not owned by `req.user.id`, the server responds with **`404 Not Found`** (never 403), completely hiding the existence of other users' data. |
| **A02: Cryptographic Failures & JWT Confusion** | Weak keys, algorithm substitution (`none` or RS256 confusion), weak password hashing. | • `bcrypt` with work factor 12.<br>• **Fail-Fast Boot**: App exits (`process.exit(1)`) if `JWT_SECRET` is missing or `< 32` characters.<br>• **Algorithm Pinning**: Explicitly enforce `algorithm: 'HS256'` on `jwt.sign` and `algorithms: ['HS256']` on `jwt.verify`.<br>• Secret stored only in environment variables (`.env.example` committed, `.env` git-ignored). |
| **A03: Injection (SQL Injection)** | Attacker inputs malicious SQL payloads via title or query params. | Exclusively parameterized queries using `better-sqlite3` statements (`db.prepare('...').run(param)`). Zero string concatenation in SQL queries. |
| **A04: Insecure Design & DoS** | Large request payload memory exhaustion or brute-force attacks. | • `express.json({ limit: '10kb' })` prevents memory exhaustion via huge JSON payloads.<br>• `express-rate-limit` on auth routes.<br>• Password length enforced between **10 and 72 characters** via Zod.<br>• Todo title restricted to **1 to 200 characters** via Zod. |
| **A05: Security Misconfiguration** | Proxy IP spoofing, leaked headers, loose CORS. | • `app.set('trust proxy', 1)` enables accurate client IP resolution behind Codespaces/reverse proxies.<br>• `helmet()` enabled for secure HTTP headers.<br>• Vite dev proxy serves `/api` as same-origin, eliminating cross-site cookie blocking in GitHub Codespaces. |
| **A06: Vulnerable & Outdated Components** | Drift or supply-chain vulnerabilities in dependencies. | **Exact pinned versions** in `package.json` (no `^` or `~`), verified with `npm audit --audit-level=high` and `osv-scanner` via `bash scripts/security-check.sh`. |
| **A07: Identification & Auth Failures** | User enumeration and timing attacks. | • **Generic Register**: Same generic response for existing emails.<br>• **Generic Login**: Generic `"Invalid email or password"` message.<br>• **Dummy Compare**: Constant-time `bcrypt.compare` against `DUMMY_HASH` when user is not found.<br>• JWT in `httpOnly`, `SameSite=Lax`, and `Secure` (in prod) cookies with short 15m lifetime. |
| **A08: Software & Data Integrity Failures** | Malformed input payloads. | Strict input validation via `zod` for all request bodies and query params. Unrecognized fields stripped. |
| **A09: Security Logging & Monitoring Failures** | Inadequate tracking of suspicious activities. | Structured logging of authentication attempts and 4xx/5xx responses (passwords and secrets redacted). |
| **A10: Cross-Site Request Forgery (CSRF) & XSS** | Forged requests executing state-changing actions via authenticated cookies. | • Anti-CSRF token verification (`X-CSRF-Token` header) on all state-changing endpoints (`POST`, `PATCH`, `DELETE`).<br>• React automatically escapes JSX expressions; `dangerouslySetInnerHTML` is prohibited. |

---

## 7. Phased Implementation Roadmap

1. **Phase 1: Project Setup & Environment Validation (Backend)**
   - Create root `package.json` with exact pinned versions and install dependencies.
   - Implement `server/src/config/env.js`:
     - Throw fatal error and `process.exit(1)` if `JWT_SECRET` is missing or `< 32` characters.
   - Implement `server/src/config/constants.js`:
     - Define `JWT_ALGORITHM = 'HS256'`.
     - Define pre-computed `DUMMY_HASH` for constant-time comparisons.
   - Setup `server/src/db/connection.js` and execute `schema.sql` on startup.
   - Commit clean `.env.example`.

2. **Phase 2: Authentication, CSRF & Authorization Middleware**
   - Configure `app.set('trust proxy', 1)` and `express.json({ limit: '10kb' })`.
   - Implement `zod` schemas for auth (email format, password 10–72 chars).
   - Implement CSRF middleware (`csrf.js`) and endpoint `GET /api/auth/csrf-token`.
   - Implement `/api/auth/register` with generic response on duplicate email.
   - Implement `/api/auth/login` with dummy bcrypt compare on user not found, generic 401 error, and HS256-signed JWT httpOnly cookie.
   - Implement `auth.js` middleware verifying JWT with pinned `algorithms: ['HS256']`.

3. **Phase 3: Todo API Endpoints**
   - Implement `zod` schema for todos (title: trimmed, 1–200 characters).
   - Implement `/api/todos` CRUD using parameterized queries.
   - Enforce resource cloaking: unowned todos return `404 Not Found` for update and delete requests.
   - Attach CSRF verification to state-changing routes (`POST`, `PATCH`, `DELETE`).

4. **Phase 4: Frontend Development (React + Vite)**
   - Set up Vite React client with dev proxy in `vite.config.js`:
     ```javascript
     server: {
       proxy: {
         '/api': {
           target: 'http://localhost:3000',
           changeOrigin: true
         }
       }
     }
     ```
   - Build API client using same-origin `/api` calls with `credentials: 'include'` and `X-CSRF-Token`.
   - Build auth context, login & register forms with password length validation helper (10–72 chars).
   - Build todo interface (max 200 char input indicator, filters, toggle, delete).

5. **Phase 5: Automated Testing**
   - Backend integration tests with `supertest`:
     - Startup abort test when `JWT_SECRET` < 32 chars.
     - Password length boundary tests (reject < 10, reject > 72, accept valid).
     - Todo title length boundary tests (reject empty, reject > 200, accept valid).
     - Payload size limit test (payload > 10kb returns 413).
     - Generic error response and dummy compare verification on login.
     - Generic response on duplicate email registration.
     - CSRF rejection on state-changing routes when `X-CSRF-Token` is missing.
     - IDOR / Cloaking test: User B modifying/deleting User A's todo receives `404 Not Found`.
   - Run tests and verify 100% pass rate.

6. **Phase 6: Static Security Audit & Remediation**
   - Run `bash scripts/security-check.sh workspace/todo-app`.
   - Verify Gitleaks, Semgrep, OSV-scanner, Trivy, and `npm audit`.
   - Fix any HIGH/CRITICAL findings until all checks pass clean.
