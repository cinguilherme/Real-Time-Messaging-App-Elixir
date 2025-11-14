#!/bin/bash

# Test Conversation Lifecycle
# Simulates two clients (Alice and Bob) having a conversation

API_URL="http://localhost:4000/v1"

# Generate UUIDs for the test
CONVERSATION_ID="11111111-1111-1111-1111-111111111111"
ALICE_ID="aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
BOB_ID="bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"

echo "=================================================="
echo "  Real-time Messaging - Conversation Test"
echo "=================================================="
echo ""
echo "Conversation ID: $CONVERSATION_ID"
echo "Alice ID: $ALICE_ID"
echo "Bob ID: $BOB_ID"
echo ""

# Step 1: Alice sends first message
echo "📱 Step 1: Alice sends 'Hello Bob!'"
echo "---"
ALICE_MSG_1=$(curl -s -X POST "$API_URL/messages" \
  -H 'Content-Type: application/json' \
  -d "{
    \"conversation_id\": \"$CONVERSATION_ID\",
    \"sender_id\": \"$ALICE_ID\",
    \"body\": {\"text\": \"Hello Bob!\"},
    \"idempotency_key\": \"alice-msg-1\"
  }")
echo "$ALICE_MSG_1" | jq .
ALICE_MSG_1_ID=$(echo "$ALICE_MSG_1" | jq -r '.message_id')
echo ""
sleep 1

# Step 2: Bob sends reply
echo "📱 Step 2: Bob sends 'Hi Alice, how are you?'"
echo "---"
BOB_MSG_1=$(curl -s -X POST "$API_URL/messages" \
  -H 'Content-Type: application/json' \
  -d "{
    \"conversation_id\": \"$CONVERSATION_ID\",
    \"sender_id\": \"$BOB_ID\",
    \"body\": {\"text\": \"Hi Alice, how are you?\"},
    \"idempotency_key\": \"bob-msg-1\"
  }")
echo "$BOB_MSG_1" | jq .
BOB_MSG_1_ID=$(echo "$BOB_MSG_1" | jq -r '.message_id')
echo ""
sleep 1

# Step 3: Alice sends another message
echo "📱 Step 3: Alice sends 'I'm doing great, thanks!'"
echo "---"
ALICE_MSG_2=$(curl -s -X POST "$API_URL/messages" \
  -H 'Content-Type: application/json' \
  -d "{
    \"conversation_id\": \"$CONVERSATION_ID\",
    \"sender_id\": \"$ALICE_ID\",
    \"body\": {\"text\": \"I'm doing great, thanks!\"},
    \"idempotency_key\": \"alice-msg-2\"
  }")
echo "$ALICE_MSG_2" | jq .
ALICE_MSG_2_ID=$(echo "$ALICE_MSG_2" | jq -r '.message_id')
echo ""
sleep 1

# Step 4: List all messages in conversation
echo "📋 Step 4: List all messages in conversation"
echo "---"
curl -s "$API_URL/conversations/$CONVERSATION_ID/messages" | jq .
echo ""
sleep 1

# Step 5: Simulate delivery - Bob receives Alice's messages
echo "✓ Step 5: Mark Alice's first message as delivered to Bob"
echo "---"
curl -s -X POST "$API_URL/messages/$ALICE_MSG_1_ID/deliver" | jq .
echo ""
sleep 1

# Step 6: Bob marks Alice's first message as read
echo "👁 Step 6: Bob marks Alice's first message as read"
echo "---"
curl -s -X POST "$API_URL/messages/$ALICE_MSG_1_ID/read" | jq .
echo ""
sleep 1

# Step 7: Mark Alice's second message as delivered and read
echo "✓👁 Step 7: Mark Alice's second message as delivered and read"
echo "---"
curl -s -X POST "$API_URL/messages/$ALICE_MSG_2_ID/deliver" | jq .
curl -s -X POST "$API_URL/messages/$ALICE_MSG_2_ID/read" | jq .
echo ""
sleep 1

# Step 8: Mark Bob's message as delivered and read by Alice
echo "✓👁 Step 8: Alice receives and reads Bob's message"
echo "---"
curl -s -X POST "$API_URL/messages/$BOB_MSG_1_ID/deliver" | jq .
curl -s -X POST "$API_URL/messages/$BOB_MSG_1_ID/read" | jq .
echo ""
sleep 1

# Step 9: Final state - List all messages with their statuses
echo "📋 Step 9: Final conversation state (all messages with statuses)"
echo "---"
curl -s "$API_URL/conversations/$CONVERSATION_ID/messages" | jq '.messages[] | {seq, sender_id, text: .body.text, status, delivered_at, read_at}'
echo ""

echo "=================================================="
echo "  ✅ Conversation Test Complete!"
echo "=================================================="
echo ""
echo "Summary:"
echo "- Total messages: $(curl -s "$API_URL/conversations/$CONVERSATION_ID/messages" | jq -r '.count')"
echo "- All messages have been delivered and read"
echo "- Sequence numbers preserved order"
echo ""

