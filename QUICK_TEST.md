# Quick Test Reference

## Start Server
```bash
mix phx.server
```

## Run Automated Test
```bash
./test_conversation.sh
```

## Manual Test (Copy & Paste)

```bash
# Variables
CONV="11111111-1111-1111-1111-111111111111"
ALICE="aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
BOB="bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"
API="http://localhost:4000/v1"

# 1. Alice sends message
curl -X POST "$API/messages" -H 'Content-Type: application/json' \
  -d "{\"conversation_id\":\"$CONV\",\"sender_id\":\"$ALICE\",\"body\":{\"text\":\"Hello Bob!\"},\"idempotency_key\":\"test-1\"}" | jq .

# Save message ID
MSG1="<paste-message-id>"

# 2. Bob replies
curl -X POST "$API/messages" -H 'Content-Type: application/json' \
  -d "{\"conversation_id\":\"$CONV\",\"sender_id\":\"$BOB\",\"body\":{\"text\":\"Hi Alice!\"},\"idempotency_key\":\"test-2\"}" | jq .

# 3. List messages
curl "$API/conversations/$CONV/messages" | jq .

# 4. Mark delivered
curl -X POST "$API/messages/$MSG1/deliver" | jq .

# 5. Mark read
curl -X POST "$API/messages/$MSG1/read" | jq .

# 6. Check final state
curl "$API/conversations/$CONV/messages" | jq '.messages[] | {seq, status, text: .body.text}'
```

## Clear Database (Between Tests)
```bash
mix run -e "Messaging.Repo.delete_all(Messaging.Schemas.Message); IO.puts('✓ Cleared')"
```

## Check Health
```bash
curl http://localhost:4000/healthz | jq .
```

## Expected Flow

1. **Create** → Status: `queued`, seq auto-assigned
2. **List** → See all messages ordered by seq
3. **Deliver** → Status: `delivered`, timestamp set
4. **Read** → Status: `read`, timestamp set

## Status State Machine

```
queued → delivered → read
```

Each transition records a timestamp:
- `delivered_at`
- `read_at`

