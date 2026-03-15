# Deployment Plan — Notes App

This document outlines how to host the Notes App (React frontend + Java Spring Boot backend) so anyone can access it via a public URL.

---

## Architecture Overview

The app has two parts that need to be deployed separately:

- **Frontend** — React (static files, built with Vite)
- **Backend** — Java Spring Boot (a running server process)
- **Database** — Currently H2 in-memory. Must be replaced with a persistent database before deploying.

---

## Step 0: Replace the In-Memory Database (Required)

The H2 in-memory database resets every time the server restarts — not viable for production. You must switch to a persistent database first.

**Recommended: PostgreSQL**

1. Update `pom.xml` — swap H2 for PostgreSQL driver:
   ```xml
   <dependency>
       <groupId>org.postgresql</groupId>
       <artifactId>postgresql</artifactId>
       <scope>runtime</scope>
   </dependency>
   ```

2. Update `application.properties`:
   ```properties
   spring.datasource.url=jdbc:postgresql://<host>:5432/notesdb
   spring.datasource.username=<user>
   spring.datasource.password=<password>
   spring.jpa.hibernate.ddl-auto=update
   ```

3. Set these values via environment variables in production (never hardcode credentials).

---

## Deployment Options

### Option A — Cheapest / Simplest (Recommended to Start)

| Service | What it hosts | Cost |
|---|---|---|
| **Vercel** | React frontend | Free |
| **Railway** | Java backend | Free tier (~$5/mo after trial) |
| **Railway** | PostgreSQL database | Free tier (~$5/mo after trial) |

**Estimated monthly cost: $0–$10/mo**

Railway's free tier gives 500 hours/month — enough to run one service continuously. After the trial credit runs out, expect ~$5/mo per service. Vercel's frontend hosting stays free indefinitely for personal/small projects.

---

### Option B — Mid-Tier (More Control, Better Uptime)

| Service | What it hosts | Cost |
|---|---|---|
| **Vercel** | React frontend | Free |
| **Render** | Java backend (Web Service) | $7/mo (paid tier, no sleep) |
| **Render** or **Supabase** | PostgreSQL | Free tier or $7–15/mo |

> Note: Render's free tier spins down after 15 minutes of inactivity, causing a slow first load (~30s). The $7/mo paid tier keeps it always on.

**Estimated monthly cost: $7–$22/mo**

---

### Option C — Full Cloud (AWS/GCP/Azure)

For maximum control, scalability, and reliability. Higher complexity.

| Component | AWS Option | Estimated Cost |
|---|---|---|
| Frontend | S3 + CloudFront | ~$1–5/mo |
| Backend | Elastic Beanstalk or EC2 (t3.micro) | ~$8–15/mo |
| Database | RDS PostgreSQL (db.t3.micro) | ~$15–25/mo |
| Domain | Route 53 | ~$12/yr per domain |

**Estimated monthly cost: $25–$50/mo**

This is overkill for a small app but makes sense if you expect high traffic or need fine-grained control.

---

## Domain Name (Optional)

If you want a custom URL (e.g., `mynotes.com`) instead of a generated one like `mynotes.railway.app`:

- Purchase a domain via **Namecheap**, **Google Domains**, or **Cloudflare Registrar**
- Cost: **$10–15/yr** for a `.com` domain
- Point DNS to wherever your frontend is hosted (Vercel handles this automatically)

---

## Recommended Path (Lowest friction to go live)

1. **Migrate database** from H2 to PostgreSQL
2. **Deploy backend** to Railway (free to start)
3. **Provision PostgreSQL** on Railway (one click, auto-wires connection string)
4. **Build the frontend** (`npm run build`) and **deploy to Vercel** (connect GitHub repo, zero config)
5. **Update the API URL** in the frontend from `/api` to the Railway backend URL
6. **(Optional)** Buy a domain and connect it to Vercel

Total time to deploy: ~1–2 hours once the database migration is done.
Total cost to start: **$0** (both Railway and Vercel have free tiers to get you started).

---

## Summary Table

| Option | Monthly Cost | Effort | Best For |
|---|---|---|---|
| A — Railway + Vercel | $0–10 | Low | Getting live fast |
| B — Render + Vercel | $7–22 | Low-Medium | Always-on, reliable |
| C — AWS/GCP | $25–50 | High | Scale / full control |
| + Custom domain | +$1/mo (~$12/yr) | Minimal | Professional URL |
