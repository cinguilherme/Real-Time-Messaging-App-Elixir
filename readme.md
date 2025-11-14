Realtime Messaging API + Job Processing (Elixir + Oban)

A backend‑only project that provides a realtime messaging API (HTTP + WebSocket) and a background job processing service for heavy/async work like image optimization, file compaction, and scheduled (“send later”) delivery. There is no frontend code in this repository.

⸻

Highlights
	•	Instant acks: clients get a response as soon as a message is queued (API returns immediately).
	•	Async delivery: actual message delivery happens in background via Oban workers.
	•	Delivery & read receipts: delivered (pushed/available) and read events are emitted over WS/PubSub.
	•	Send later / scheduled delivery: schedule any message to be delivered at a future UTC timestamp.
	•	CPU/IO offload: heavy work runs in dedicated Oban queues/nodes.
	•	Postgres‑backed reliability: Oban stores jobs with retries, backoff, and auditing.
	•	Idempotency & ordering: built‑in patterns to avoid duplicates and preserve per‑conversation order.
	•	Zero Pro dependency: uses Oban (OSS) only.

⸻

Repo Layout (Umbrella)

.
├─ apps/
│  ├─ messaging_api/         # Phoenix API + Channels/PubSub + contexts (Messages, Receipts)
│  └─ job_processor/         # Oban + workers (delivery, media, file ops)
├─ rel/                      # Releases (Distillery/Mix releases config)
├─ config/                   # Umbrella config (runtime.exs, dev/test/prod)
└─ README.md

Why umbrella? Clear separation of realtime API concerns from background processing. You can scale them independently (different nodes/containers), share Ecto schemas, and keep a single deployment artifact if desired.

Architecture Notes:
	•	messaging_api: Handles HTTP requests and WebSocket connections. Returns immediately after enqueueing messages.
	•	job_processor: Runs Oban workers for async delivery, scheduled messages, and heavy processing tasks.
	•	Communication: Both apps share the same Postgres database. Jobs are enqueued via Oban tables.
	•	Deployment flexibility: Can run in separate VMs/containers for isolation or in a single BEAM VM. Tradeoffs to be evaluated through testing.

⸻

Core Features

1) Messaging lifecycle & receipts

States: queued → delivered → read (+ failed side‑path)
	•	queued: message persisted and Oban job enqueued; API returns 201 immediately with {message_id, status: "queued"}. This is the initial state when a message is received.
	•	delivered: recipient got the push or message is available in their inbox queue; status updated and delivered event broadcast over WS/PubSub.
	•	read: recipient marks read via endpoint or WS event; status updated and read event broadcast.

+---------+      +-----------+      +------+
|  queued | ---> | delivered | ---> | read |
+---------+      +-----------+      +------+
     \__________________________________________/ 
                  (retries/idempotency)

The endpoint responds immediately after persisting the message to the database and enqueuing the delivery job. The actual delivery to the recipient happens asynchronously via Oban workers.

2) Send later / scheduled delivery
	•	Set scheduled_at (UTC) when creating a message; Oban runs it at/after that time.
	•	Timezone handling is done at the edge (convert local → UTC before insert).
	•	Works for one‑off sends (e.g., “Happy Birthday tomorrow 09:00 local”).

3) Heavy/async tasks
	•	Dedicated queues: heavy_io (image optimization), files (compaction), etc.
	•	Separate concurrency caps to protect the messaging hot path.
	•	Optional separate node group to isolate CPU/memory.

4) Ordering & concurrency
	•	Per‑conversation sequence numbers to preserve order.
	•	Two approaches under evaluation (system designed to support both for testing):
		○	Option A: Delivery worker only advances the next undelivered seq (DB guarded with FOR UPDATE SKIP LOCKED or advisory locks).
		○	Option B: Enqueue a single conversation‑drain job instead of per‑message jobs.
	•	Final implementation will be determined through performance testing and real-world load evaluation.

5) Observability & operations
	•	Exposes Telemetry metrics (HTTP, DB, job success/failure, queue latency).
	•	Health endpoints: liveness/readiness probes.
	•	Pruner & Lifeline plugins to keep Oban tables tidy and revive stuck jobs.

⸻

Tech Stack

Runtime
	•	Elixir ≥ 1.16, Erlang/OTP ≥ 26
	•	Phoenix (API + Channels)
	•	Ecto + PostgreSQL (messages and jobs)
	•	Oban (OSS): job processing, scheduling, retries
	•	Phoenix PubSub (deliver/read notifications)

Libraries (typical)
	•	phoenix, phoenix_pubsub, phoenix_html (if needed for channels deps)
	•	plug_cowboy (HTTP server)
	•	ecto_sql, postgrex
	•	oban
	•	telemetry, telemetry_metrics, telemetry_poller
	•	jason (JSON), finch (optional HTTP client for webhooks)
	•	bcrypt_elixir or similar if auth is needed

Infra
	•	PostgreSQL 14+
	•	(Optional) Redis or object storage if media pipelines require it (not required by Oban)
	•	Docker / Kubernetes (optional deployment targets) - not required to exist in this code repo, infra will live separatly, here only the docker-compose.yaml file is provided.

⸻

Data Model (minimal)

messages
	•	id (uuid)
	•	conversation_id (uuid)
	•	sender_id (uuid)
	•	seq (int, monotonically increasing per conversation)
	•	body (text/json)
	•	status (enum: queued|delivered|read|failed)
	•	scheduled_at (utc_datetime, nullable)
	•	sent_at / delivered_at / read_at (utc_datetime)
	•	idempotency_key (string, unique, nullable)
	•	inserted_at / updated_at

receipts (optional per‑recipient record for group conversations & read receipt privacy)
	•	id (uuid)
	•	message_id (uuid fk)
	•	user_id (uuid)
	•	status (delivered|read)
	•	at (utc_datetime)

Purpose: Track individual delivery/read status for group conversations or when users opt-out of broadcasting read receipts (similar to WhatsApp privacy settings). For 1:1 conversations with full read receipts enabled, the message status field is sufficient.

inbox (optional for offline delivery)
	•	user_id (uuid)
	•	message_id (uuid)
	•	enqueued_at / delivered_at

⸻

API Overview (example)

Create message (immediate or scheduled)

POST /v1/messages
{
  "conversation_id": "…",
  "sender_id": "…",
  "body": {"text": "Happy birthday!"},
  "scheduled_at": "2026-03-10T12:00:00Z",   // optional
  "idempotency_key": "client-uuid-123"       // optional but recommended
}
→ 201 Created
{
  "message_id": "…", "status": "queued"
}

Mark read

POST /v1/messages/:id/read
→ 204 No Content

WebSocket/Channels topics (examples)
	•	conv:{conversation_id} → broadcasts delivered and read events
	•	msg:{message_id} → fine‑grained per‑message events

⸻

Job Queues & Workers

Queues (default config)

config :job_processor, Oban,
  repo: Messaging.Repo,
  queues: [
    deliver_realtime: 50,
    scheduled_delivery: 5,
    files: 4,
    heavy_io: 2
  ],
  plugins: [
    Oban.Plugins.Pruner,
    Oban.Plugins.Lifeline
  ]

Workers

Delivery Workers (two separate implementations):
	•	SendMessage (queue: deliver_realtime)
		○	Handles immediate message delivery
		○	Fetch message, guard idempotency, deliver/publish, set delivered_at
	•	SendLater (queue: scheduled_delivery)
		○	Separate worker for scheduled messages
		○	Uses Oban's scheduled_at feature to delay execution until the specified time
		○	Example: Send at 13:00 but schedule delivery for 14:00

Background Processing Workers:
	•	OptimizeImage (queue: heavy_io)
	•	CompactFile (queue: files)

Scheduling
	•	Use scheduled_at on job insert for “send later”.
	•	For periodic duties (e.g., cleanup), add Oban.Plugins.Cron with static cron entries.

⸻

Idempotency & Ordering Patterns

Idempotent delivery
	•	Use idempotency_key on message creation (unique index) to avoid duplicates.
	•	Worker checks status/delivered_at before acting; updates within a transaction.

Per‑conversation ordering
	•	Maintain seq per conversation_id.
	•	Option A: In the delivery worker, select the lowest seq not yet delivered with FOR UPDATE SKIP LOCKED. Only deliver if seq == expected_next_seq; otherwise requeue or return snooze.
	•	Option B: Enqueue a single conversation-drain job that processes messages in order.
	•	(See "Ordering & concurrency" section above for evaluation approach.)

⸻

Setup & Development

Prereqs
	•	Erlang/OTP ≥ 26, Elixir ≥ 1.16
	•	PostgreSQL 14+
	•	Node/Yarn not required (no frontend), unless you use Phoenix generators that pull assets.

Configure env vars

DATABASE_URL=postgres://user:pass@localhost:5432/messaging
POOL_SIZE=20
SECRET_KEY_BASE=…               # Phoenix endpoint
PORT=4000

Install & run

# at repo root
mix deps.get
mix ecto.setup           # creates DB and runs migrations for both apps

# Two applications: API and Job Processor
# Option 1: Run in separate processes (recommended for production consideration)
iex -S mix phx.server    # apps/messaging_api (shell 1)
IEX_BUILD=1 iex -S mix   # apps/job_processor (shell 2, loads Oban + workers)

# Option 2: Single BEAM VM (simpler for development, evaluate tradeoffs for production)
# The Elixir runtime can handle both processes in one VM, but separating them may provide
# better isolation for resource management and scaling. Performance testing will determine
# the best deployment strategy.

Tests

mix test
MIX_ENV=test mix ecto.create && MIX_ENV=test mix ecto.migrate


⸻

Observability
	•	Telemetry: emit HTTP latencies, DB timings, job run time, queue depth, error counts.
	•	Metrics: recommended Prometheus exporter (via Telemetry.Metrics + plug).
	•	Logs: structured JSON (Logger + Jason). Include message_id, conversation_id, job_id.

Example metrics (names are suggestions):
	•	messages_created_total, messages_delivered_total, messages_read_total
	•	oban_job_duration_seconds{queue,worker} histogram
	•	delivery_lag_seconds (inserted_at → delivered_at)

⸻

Deployment

Mix Releases
	•	Build one umbrella release or split by app.
	•	Configure API node and Job node with different OBAN_QUEUES/env if you want isolation.

Docker (example outline)
	•	Multi‑stage build: mix release → small runtime image.
	•	Separate images: messaging-api and job-processor.
	•	Healthchecks: /healthz for API; Oban DB connectivity check for job node.

Kubernetes (optional)
	•	Two Deployments: api and jobs (different resources/limits).
	•	HPA on API; fixed/low concurrency on heavy_io to cap CPU.
	•	Postgres as managed service (RDS/CloudSQL) or stable in‑cluster operator.

⸻

Security Notes
	•	Enable TLS at the ingress/reverse proxy.
	•	AuthN/Z: JWT or session for API; validate sender_id/membership in conversation_id.
	•	Rate limit write endpoints; backpressure via queue bounds.
	•	Validate message size/type; store large media out‑of‑band (S3/etc.) and reference by URL/key.

⸻

Failure Modes & Playbook
	•	Job retries: transient errors auto‑retry (exponential backoff). After max_attempts, mark failed and surface in logs/metrics.
	•	DB outage: API flips to 503 or degraded mode; jobs pause (Oban requires DB). Use read‑only mode if possible.
	•	Queue saturation: Observe oban_job_duration_seconds and queue latency; lower concurrency on heavy queues or scale out job nodes.
	•	Deadlocks/contention: Keep delivery transaction minimal; index on (conversation_id, seq).

⸻

Local Timezones & Scheduling
	•	Clients submit local time + timezone; server converts to UTC before writing scheduled_at.
	•	Never schedule from naive times; keep everything in UTC in the DB.

⸻

Extending
	•	Add webhooks on delivery/read events (Finch HTTP client in a separate worker).
	•	Add media pipelines (thumbnailer, virus scan) as extra queues.
	•	Add message search (PG trigram/GIN) if needed.

⸻

License

MIT (or your choice).

⸻

Quick Start (copy/paste)

# create immediate message
curl -X POST http://localhost:4000/v1/messages \
  -H 'content-type: application/json' \
  -d '{
    "conversation_id": "11111111-1111-1111-1111-111111111111",
    "sender_id": "22222222-2222-2222-2222-222222222222",
    "body": {"text": "Hello"},
    "idempotency_key": "demo-1"
  }'

# schedule for later (UTC)
curl -X POST http://localhost:4000/v1/messages \
  -H 'content-type: application/json' \
  -d '{
    "conversation_id": "11111111-1111-1111-1111-111111111111",
    "sender_id": "22222222-2222-2222-2222-222222222222",
    "body": {"text": "Happy Birthday!"},
    "scheduled_at": "2026-01-25T12:00:00Z",
    "idempotency_key": "demo-2"
  }'

# mark read
curl -X POST http://localhost:4000/v1/messages/<message_id>/read