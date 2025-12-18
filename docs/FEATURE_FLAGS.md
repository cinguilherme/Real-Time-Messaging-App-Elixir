# Feature Flags Guide

This document provides comprehensive information about the feature flag system in the Real-Time Messaging application.

## Overview

The feature flag system allows you to:
- Enable/disable features independently
- Configure different storage backends per feature
- Validate configuration at boot time with clear error messages
- Deploy different configurations per environment
- Scale job queues dynamically based on enabled features

## Configuration File

### Location

The feature configuration is loaded from a YAML file. By default, the system looks for `config/features.yaml`, but you can override this with the `FEATURES_CONFIG` environment variable:

```bash
export FEATURES_CONFIG=/etc/app/features.yaml
```

### Structure

```yaml
features:
  receipts: true              # Per-user delivery/read tracking
  inbox: true                 # Offline message queue
  scheduled_delivery: true    # "Send later" functionality
  media: true                 # Image optimization
  file_ops: true              # File operations
  pubsub: true                # Real-time broadcasts

storage:
  messages: postgres          # [postgres, memory]
  receipts: postgres          # [postgres, none]
  inbox: postgres             # [postgres, redis, none]
  history: postgres           # [postgres, none]
  blobs: s3                   # [s3, local, none]

scaling:
  mode: single_node           # [single_node, multi_node]
  job_isolation: false        # true/false

jobs:
  deliver_realtime: 50        # Concurrency for real-time delivery
  scheduled_delivery: 5       # Concurrency for scheduled messages
  files: 4                    # Concurrency for file operations
  heavy_io: 2                 # Concurrency for heavy I/O tasks
```

## Feature Reference

### Receipts

**What it does:** Tracks per-user delivery and read status for messages. Essential for group conversations where you need to know which specific users have received or read a message.

**When to disable:** Single-user conversations or when privacy requirements prohibit tracking individual read status.

**Dependencies:**
- Requires `storage.receipts` to be set to `postgres`

**Storage options:**
- `postgres` - Store receipts in PostgreSQL using the `receipts` table
- `none` - Disable receipt tracking entirely

### Inbox

**What it does:** Maintains an offline queue of messages waiting to be delivered to users who are currently offline. When users reconnect, pending messages are delivered from their inbox.

**When to disable:** Real-time only messaging where offline delivery is not needed, or when using push notifications instead.

**Dependencies:**
- Requires `storage.inbox` to be set to `postgres` or `redis`

**Storage options:**
- `postgres` - Store inbox in PostgreSQL using the `inbox` table
- `redis` - Store inbox in Redis (not yet implemented)
- `none` - Disable inbox feature

### Scheduled Delivery

**What it does:** Enables "send later" functionality where messages can be scheduled for delivery at a specific future time.

**When to disable:** When only immediate delivery is needed.

**Dependencies:**
- Requires `jobs.scheduled_delivery` to be greater than 0

**Queue configuration:**
- Set `jobs.scheduled_delivery` to the desired concurrency level
- Set to `0` to disable the queue entirely

### Media Processing

**What it does:** Provides image optimization and media processing pipelines. Processes uploaded images in background jobs with dedicated concurrency limits.

**When to disable:** Text-only messaging, GDPR-sensitive deployments, or resource-constrained environments.

**Dependencies:**
- Requires `storage.blobs` to be set to `s3` or `local`
- Requires `jobs.heavy_io` to be greater than 0

**Storage options:**
- `s3` - Store blobs in Amazon S3 (requires AWS credentials)
- `local` - Store blobs on local filesystem (development/testing)
- `none` - Disable blob storage

### File Operations

**What it does:** Handles file compaction and other file processing tasks in background jobs.

**When to disable:** When file operations are not needed.

**Dependencies:**
- Requires `jobs.files` to be greater than 0

### PubSub

**What it does:** Enables real-time WebSocket broadcasts for delivery and read notifications.

**When to disable:** When WebSocket real-time updates are not needed (API-only mode).

**Dependencies:**
- None (Phoenix.PubSub is started conditionally)

## Validation Rules

The system validates configuration at boot time and fails fast with clear error messages if rules are violated:

### Rule Matrix

| Condition | Requirement | Error if violated |
|-----------|------------|-------------------|
| `features.receipts: true` | `storage.receipts != none` | "Receipts feature requires storage.receipts (postgres)" |
| `features.inbox: true` | `storage.inbox != none` | "Inbox feature requires storage.inbox (postgres or redis)" |
| `features.scheduled_delivery: true` | `jobs.scheduled_delivery > 0` | "Scheduled delivery requires jobs.scheduled_delivery queue" |
| `features.media: true` | `storage.blobs != none` | "Media feature requires storage.blobs (s3 or local)" |
| `features.media: true` | `jobs.heavy_io > 0` | "Media feature requires jobs.heavy_io queue" |
| `features.file_ops: true` | `jobs.files > 0` | "File operations require jobs.files queue" |
| `scaling.mode: multi_node` | `storage.messages == postgres` | "Multi-node requires postgres storage (not memory)" |
| Any `storage: postgres` | Repo configured | "Postgres storage requires Messaging.Repo configuration" |

### Example Validation Error

If you enable receipts but set storage to `none`, you'll see:

```
Feature configuration validation failed:

  1. Receipts feature is enabled but storage.receipts is set to 'none'. 
     Set storage.receipts to 'postgres' to enable receipts.

Please check your configuration file and fix the errors above.
```

## Deployment Scenarios

### Scenario 1: Full Featured Production

**Use case:** Production deployment with all features enabled.

**Config:** `config/features.standard.yaml`

```yaml
features:
  receipts: true
  inbox: true
  scheduled_delivery: true
  media: true
  file_ops: true
  pubsub: true

storage:
  messages: postgres
  receipts: postgres
  inbox: postgres
  history: postgres
  blobs: s3

jobs:
  deliver_realtime: 50
  scheduled_delivery: 5
  files: 4
  heavy_io: 2
```

**Environment variables:**
```bash
FEATURES_CONFIG=/etc/app/features.yaml
DATABASE_URL=postgres://...
S3_BUCKET=my-app-blobs
S3_REGION=us-east-1
```

### Scenario 2: Minimal/Testing

**Use case:** Development, testing, or minimal deployments.

**Config:** `config/features.minimal.yaml`

```yaml
features:
  receipts: false
  inbox: false
  scheduled_delivery: false
  media: false
  file_ops: false
  pubsub: true

storage:
  messages: postgres
  receipts: none
  inbox: none
  history: none
  blobs: none

jobs:
  deliver_realtime: 50
  scheduled_delivery: 0
  files: 0
  heavy_io: 0
```

### Scenario 3: GDPR-Compliant (No Media)

**Use case:** Privacy-focused deployment without media processing.

**Config:** `config/features.no-media.yaml`

```yaml
features:
  receipts: true
  inbox: true
  scheduled_delivery: true
  media: false          # Disabled
  file_ops: true
  pubsub: true

storage:
  messages: postgres
  receipts: postgres
  inbox: postgres
  history: postgres
  blobs: none          # No blob storage

jobs:
  deliver_realtime: 50
  scheduled_delivery: 5
  files: 4
  heavy_io: 0          # No heavy I/O
```

### Scenario 4: Multi-Node with Job Isolation

**Use case:** Separate API nodes from worker nodes for better scaling.

**API Node Config:**
```yaml
features:
  receipts: true
  inbox: true
  scheduled_delivery: true
  media: true
  file_ops: true
  pubsub: true

storage:
  messages: postgres
  receipts: postgres
  inbox: postgres
  history: postgres
  blobs: s3

scaling:
  mode: multi_node
  job_isolation: true    # Don't run jobs on API node

jobs:
  deliver_realtime: 0    # Disabled on API nodes
  scheduled_delivery: 0
  files: 0
  heavy_io: 0
```

**Worker Node Config:**
```yaml
features:
  receipts: true
  inbox: true
  scheduled_delivery: true
  media: true
  file_ops: true
  pubsub: false          # No PubSub on worker nodes

storage:
  messages: postgres
  receipts: postgres
  inbox: postgres
  history: postgres
  blobs: s3

scaling:
  mode: multi_node
  job_isolation: true

jobs:
  deliver_realtime: 50   # Full concurrency on workers
  scheduled_delivery: 5
  files: 4
  heavy_io: 2
```

## Adapter Selection Logic

The system automatically selects the appropriate adapter implementation based on your configuration:

### Receipts

- `features.receipts: true` + `storage.receipts: postgres` → `Messaging.Adapters.Receipts.Postgres`
- `features.receipts: false` OR `storage.receipts: none` → `Messaging.Adapters.Receipts.Noop`

### Inbox

- `features.inbox: true` + `storage.inbox: postgres` → `Messaging.Adapters.Inbox.Postgres`
- `features.inbox: true` + `storage.inbox: redis` → `Messaging.Adapters.Inbox.Postgres` (Redis adapter TBD)
- `features.inbox: false` OR `storage.inbox: none` → `Messaging.Adapters.Inbox.Noop`

### Blobs

- `storage.blobs: s3` → `Messaging.Adapters.Blobs.S3`
- `storage.blobs: local` → `Messaging.Adapters.Blobs.Local`
- `storage.blobs: none` → `Messaging.Adapters.Blobs.Noop`

### History

- `storage.history: postgres` → `Messaging.Adapters.History.Postgres`
- `storage.history: none` → `Messaging.Adapters.History.Noop`

## Boot Process

When the application starts, the following happens:

1. **Load Configuration**
   - Read YAML from `$FEATURES_CONFIG` (default: `config/features.yaml`)
   - Parse YAML into Elixir data structures

2. **Validate Configuration**
   - Run all validation rules
   - Fail fast with detailed error messages if validation fails
   - Return validated config struct

3. **Configure Adapters**
   - Select appropriate adapter module for each feature
   - Store adapter selection in application environment

4. **Build Supervisor Tree**
   - Add Postgres Repo if any feature uses postgres storage
   - Add Phoenix.PubSub if `features.pubsub: true`
   - Configure Oban with dynamic queue list based on job concurrency

5. **Log Boot Summary**
   - Display enabled features
   - Show storage configuration
   - List active job queues

### Example Boot Log

```
[info] ⚙️  Feature Configuration Loaded
[info] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[info] Features:
[info]   ✓ Messages (core)
[info]   ✓ Receipts (per-user tracking)
[info]   ✓ Inbox (offline queue)
[info]   ✓ Scheduled delivery
[info]   ✗ Media processing
[info]   ✓ File operations
[info]   ✓ PubSub broadcasts
[info] Storage:
[info]   Messages: postgres
[info]   Receipts: postgres
[info]   Inbox: postgres
[info]   History: postgres
[info]   Blobs: none
[info] Scaling:
[info]   Mode: single_node
[info]   Job Isolation: false
[info] Job Queues:
[info]   deliver_realtime: 50
[info]   scheduled_delivery: 5
[info]   files: 4
[info] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Troubleshooting

### Error: Configuration file not found

**Problem:**
```
Feature configuration file not found: config/features.yaml

Set FEATURES_CONFIG environment variable...
```

**Solution:**
- Ensure `config/features.yaml` exists in your project
- Or set `FEATURES_CONFIG` to point to your config file location

### Error: Validation failed

**Problem:**
```
Feature configuration validation failed:

  1. Receipts feature is enabled but storage.receipts is set to 'none'.
```

**Solution:**
- Check the validation rules section above
- Adjust your configuration to meet the requirements
- Either enable the required storage or disable the feature

### Error: Failed to parse YAML

**Problem:**
```
Failed to parse YAML configuration: ...
```

**Solution:**
- Check YAML syntax (proper indentation, no tabs)
- Validate YAML at yamllint.com
- Ensure boolean values are lowercase (`true`/`false`, not `True`/`False`)

### Noop Adapters Logging Too Much

**Problem:** Debug logs showing "disabled: skipping..." for every operation

**Solution:** Noop adapters log at `:debug` level. In production, set your logger level to `:info` or higher:

```elixir
config :logger, level: :info
```

## Migration Guide

### From Hardcoded Features to Feature Flags

If you're migrating from a version without feature flags:

1. **Create default config** with all features enabled (mirrors current behavior):
   ```bash
   cp config/features.standard.yaml config/features.yaml
   ```

2. **Deploy with feature flags system** - No behavior change yet

3. **Test in staging** with different configurations

4. **Gradually customize** configs per environment

5. **Remove old hardcoded switches** if any existed

## Best Practices

1. **Version Control**
   - Commit default `config/features.yaml` to git
   - Add environment-specific configs to `.gitignore` (e.g., `features.local.yaml`)

2. **Environment Variables**
   - Use `FEATURES_CONFIG` to point to environment-specific configs
   - Don't embed secrets in YAML (use env vars for credentials)

3. **Validation**
   - Always run validation in CI/CD before deployment
   - Test boot process in staging with production config

4. **Documentation**
   - Document why specific features are disabled in your environment
   - Keep deployment runbooks updated with config requirements

5. **Monitoring**
   - Watch boot logs to confirm correct configuration loaded
   - Monitor adapter selection in production logs
   - Alert on validation failures

## API Reference

### Configuration Modules

- `Messaging.Config` - Configuration struct
- `Messaging.Config.Loader` - Loads and parses YAML
- `Messaging.Config.Validator` - Validates configuration rules
- `Messaging.Config.Logger` - Logs boot summary

### Behavior Modules

- `Messaging.Behaviors.ReceiptsStore` - Receipt tracking behavior
- `Messaging.Behaviors.InboxStore` - Inbox queue behavior
- `Messaging.Behaviors.BlobStore` - Blob storage behavior
- `Messaging.Behaviors.HistoryStore` - Message history behavior

### Context Modules (Use these in your code)

- `Messaging.Receipts` - Receipt operations facade
- `Messaging.Inbox` - Inbox operations facade
- `Messaging.Blobs` - Blob storage facade
- `Messaging.History` - History operations facade

### Example Usage in Code

```elixir
# Record a delivery receipt (works with any configured adapter)
Messaging.Receipts.record_delivery(message_id, user_id)

# Enqueue message in inbox (works with any configured adapter)
Messaging.Inbox.enqueue(user_id, message_id)

# Store a blob (works with S3, local, or noop adapter)
Messaging.Blobs.put("images/avatar.jpg", image_data, content_type: "image/jpeg")

# Get conversation history (works with postgres or noop adapter)
Messaging.History.get_conversation_history(conversation_id, limit: 50)
```

The beauty of this system is that your code doesn't change - only the configuration determines which implementation is used.
