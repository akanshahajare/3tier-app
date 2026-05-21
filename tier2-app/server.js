// ════════════════════════════════════════════════════════
//  TIER 2 — Application + Business Logic Layer (v3)
//  Database : PostgreSQL  (Tier 3 — port 5432)
//  Cache    : Redis       (port 6379) ← NEW in v3
//
//  How caching works:
//    GET /api/students
//      1. Check Redis first — if data exists → return it (CACHE HIT)
//      2. If not in Redis   → query PostgreSQL (CACHE MISS)
//      3. Store result in Redis with 60s TTL for next request
//
//    POST / DELETE
//      → Always goes to PostgreSQL
//      → Clears Redis cache so next GET fetches fresh data
// ════════════════════════════════════════════════════════

const express      = require("express");
const cors         = require("cors");
const { Pool }     = require("pg");
const { createClient } = require("redis");

const app  = express();
const PORT = 3000;
const CACHE_KEY = "all_students";   // Redis key for student list
const CACHE_TTL = 60;               // Cache expires after 60 seconds

app.use(express.json());
app.use(cors({ origin: "*" }));


// ── Tier 3: PostgreSQL Connection ─────────────────────
const db = new Pool({
  host:     process.env.DB_HOST     || "127.0.0.1",
  port:     process.env.DB_PORT     || 5432,
  user:     process.env.DB_USER     || "appuser",
  password: process.env.DB_PASSWORD || "apppassword",
  database: process.env.DB_NAME     || "school_db",
  max:      10
});


// ── Redis Cache Connection ─────────────────────────────
const cache = createClient({
  url: `redis://${process.env.REDIS_HOST || "127.0.0.1"}:${process.env.REDIS_PORT || 6379}`
});

// Connect to Redis and log status
cache.connect()
  .then(() => console.log("  Redis cache connected ✓"))
  .catch(err => console.warn("  Redis not available — running without cache:", err.message));


// ── Business Logic ────────────────────────────────────
function validateStudent(name, age, course) {
  if (!name || !age || !course)   return "All fields are required.";
  if (name.trim().length < 2)     return "Name must be at least 2 characters.";
  if (age < 10 || age > 100)      return "Age must be between 10 and 100.";
  if (course.trim().length === 0) return "Course cannot be empty.";
  return null;
}


// ── Health Check ──────────────────────────────────────
app.get("/health", async (req, res) => {
  const redisAlive = cache.isReady;
  res.json({
    status:   "Tier 2 App Server running",
    database: "PostgreSQL",
    cache:    redisAlive ? "Redis (connected)" : "Redis (not connected)",
    version:  "v3"
  });
});


// ── GET all students ──────────────────────────────────
// Cache-aside pattern:
//   1. Try Redis → 2. On miss: query PostgreSQL → 3. Store in Redis
app.get("/api/students", async (req, res) => {
  try {

    // ── Step 1: Check Redis cache first ─────────────
    if (cache.isReady) {
      const cached = await cache.get(CACHE_KEY);
      if (cached) {
        // CACHE HIT — return data from Redis, skip DB
        console.log("  [CACHE HIT] Serving students from Redis");
        return res.json({
          source:   "redis",                           // tells frontend: came from cache
          database: "PostgreSQL",
          cache:    "Redis",
          ttl:      await cache.ttl(CACHE_KEY),        // seconds left before cache expires
          data:     JSON.parse(cached)
        });
      }
    }

    // ── Step 2: Cache MISS — query PostgreSQL ────────
    console.log("  [CACHE MISS] Fetching students from PostgreSQL");
    const result = await db.query(
      "SELECT id, name, age, course FROM students ORDER BY id DESC"
    );

    // ── Step 3: Store result in Redis for next time ──
    if (cache.isReady) {
      await cache.setEx(CACHE_KEY, CACHE_TTL, JSON.stringify(result.rows));
      console.log(`  [CACHE SET] Stored in Redis for ${CACHE_TTL}s`);
    }

    res.json({
      source:   "database",                           // tells frontend: came from PostgreSQL
      database: "PostgreSQL",
      cache:    "Redis",
      data:     result.rows
    });

  } catch (err) {
    console.error("Error:", err.message);
    res.status(500).json({ error: "Failed to fetch students." });
  }
});


// ── GET single student ────────────────────────────────
// Individual records not cached — always hit PostgreSQL
app.get("/api/students/:id", async (req, res) => {
  try {
    const result = await db.query(
      "SELECT id, name, age, course FROM students WHERE id = $1",
      [req.params.id]
    );
    if (!result.rows.length)
      return res.status(404).json({ error: "Student not found." });
    res.json({ source: "database", database: "PostgreSQL", data: result.rows[0] });
  } catch (err) {
    res.status(500).json({ error: "Failed to fetch student." });
  }
});


// ── POST new student ──────────────────────────────────
// Write goes to PostgreSQL → then invalidate Redis cache
app.post("/api/students", async (req, res) => {
  const { name, age, course } = req.body;

  const validationError = validateStudent(name, age, course);
  if (validationError)
    return res.status(400).json({ error: validationError });

  try {
    const result = await db.query(
      "INSERT INTO students (name, age, course) VALUES ($1, $2, $3) RETURNING id",
      [name.trim(), age, course.trim()]
    );

    // Invalidate cache — next GET will fetch fresh data from PostgreSQL
    if (cache.isReady) {
      await cache.del(CACHE_KEY);
      console.log("  [CACHE CLEAR] Cache invalidated after INSERT");
    }

    res.status(201).json({
      message: "Student added successfully.",
      id:      result.rows[0].id
    });
  } catch (err) {
    console.error("DB Error:", err.message);
    res.status(500).json({ error: "Failed to save student." });
  }
});


// ── DELETE student ────────────────────────────────────
// Delete from PostgreSQL → invalidate Redis cache
app.delete("/api/students/:id", async (req, res) => {
  try {
    const result = await db.query(
      "DELETE FROM students WHERE id = $1 RETURNING id",
      [req.params.id]
    );
    if (!result.rows.length)
      return res.status(404).json({ error: "Student not found." });

    // Invalidate cache after delete
    if (cache.isReady) {
      await cache.del(CACHE_KEY);
      console.log("  [CACHE CLEAR] Cache invalidated after DELETE");
    }

    res.json({ message: "Student deleted successfully." });
  } catch (err) {
    res.status(500).json({ error: "Failed to delete student." });
  }
});


// ── Start Server ──────────────────────────────────────
app.listen(PORT, () => {
  console.log("════════════════════════════════════════");
  console.log("  TIER 2 — App Server v3");
  console.log(`  URL     : http://localhost:${PORT}`);
  console.log(`  DB      : PostgreSQL @ ${process.env.DB_HOST || "127.0.0.1"}:5432`);
  console.log(`  Cache   : Redis     @ ${process.env.REDIS_HOST || "127.0.0.1"}:6379`);
  console.log("════════════════════════════════════════");
});
