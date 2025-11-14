# Setup Instructions

## Prerequisites

- Erlang/OTP ≥ 26
- Elixir ≥ 1.16
- PostgreSQL 14+ (via Docker Compose)
- Docker and Docker Compose

## Quick Start

### 1. Start Dependencies

```bash
# Start PostgreSQL and Redis
docker-compose up -d
```

### 2. Install Dependencies

```bash
# Install all Elixir dependencies
mix deps.get
```

### 3. Setup Database

```bash
# Create the database
mix ecto.create

# Run migrations
mix ecto.migrate
```

### 4. Run the Applications

#### Option A: Run both apps in separate terminals (recommended for development)

Terminal 1 - API Server:
```bash
cd apps/messaging_api
iex -S mix phx.server
```

Terminal 2 - Job Processor:
```bash
cd apps/job_processor
iex -S mix
```

#### Option B: Run from root (will start both in one VM)

```bash
iex -S mix
```

### 5. Verify Setup

Test the health endpoint:
```bash
curl http://localhost:4000/healthz
```

Expected response:
```json
{"status":"ok","timestamp":"2024-11-14T..."}
```

## Project Structure

```
real-time-messaging/
├── apps/
│   ├── messaging_core/       # Shared Ecto repo, schemas, and contexts
│   ├── messaging_api/         # Phoenix API + WebSocket
│   └── job_processor/         # Oban workers
├── config/
│   ├── config.exs            # Base configuration
│   ├── dev.exs               # Development config
│   ├── test.exs              # Test config
│   ├── prod.exs              # Production config
│   └── runtime.exs           # Runtime/environment config
├── docker-compose.yaml       # PostgreSQL + Redis
└── mix.exs                   # Umbrella project definition
```

## Current Status

✅ Umbrella application structure created
✅ messaging_core app with Ecto, Repo, schemas (Message, Receipt, Inbox), and migrations
✅ messaging_api Phoenix app with endpoints, controllers, PubSub, and health checks
✅ job_processor app with Oban configuration and placeholder worker modules
✅ Configuration files (config.exs, dev.exs, test.exs, runtime.exs, prod.exs)

## What's Ready

- **Database Schemas**: Messages, Receipts, and Inbox tables with migrations
- **API Endpoints**: 
  - `GET /healthz` - Health check (implemented)
  - `POST /v1/messages` - Create message (placeholder)
  - `POST /v1/messages/:id/read` - Mark read (placeholder)
- **WebSocket Support**: Socket infrastructure ready for channels
- **Oban Workers**: 4 placeholder workers ready for implementation:
  - SendMessage (deliver_realtime queue)
  - SendLater (scheduled_delivery queue)
  - OptimizeImage (heavy_io queue)
  - CompactFile (files queue)

## Next Steps

The scaffold is complete and ready for feature implementation. To proceed:

1. Implement the message creation logic in `MessageController.create/2`
2. Implement the mark_read logic in `MessageController.mark_read/2`
3. Implement worker logic for message delivery
4. Add Phoenix Channels for real-time communication
5. Add authentication/authorization

## Environment Variables

### Development
Uses defaults in `config/dev.exs`

### Production
Required environment variables:
- `DATABASE_URL` - PostgreSQL connection string
- `SECRET_KEY_BASE` - Phoenix secret key (generate with: `mix phx.gen.secret`)
- `PORT` - HTTP port (default: 4000)
- `POOL_SIZE` - Database pool size (default: 20)

Optional Oban concurrency overrides:
- `OBAN_DELIVER_REALTIME_CONCURRENCY` (default: 50)
- `OBAN_SCHEDULED_DELIVERY_CONCURRENCY` (default: 5)
- `OBAN_FILES_CONCURRENCY` (default: 4)
- `OBAN_HEAVY_IO_CONCURRENCY` (default: 2)

## Testing

```bash
# Create test database
MIX_ENV=test mix ecto.create

# Run migrations for test
MIX_ENV=test mix ecto.migrate

# Run tests
mix test
```

## Troubleshooting

### Dependencies won't install
- Check your internet connection
- Try: `mix local.hex --force && mix local.rebar --force`
- Then: `mix deps.get`

### Database connection fails
- Ensure Docker is running: `docker ps`
- Check PostgreSQL is running: `docker-compose ps`
- Verify connection settings in `config/dev.exs`

### Port 4000 already in use
- Change the port in `config/dev.exs`
- Or set: `PORT=4001 iex -S mix phx.server`

