defmodule Messaging.Adapters.Inbox.NoopTest do
  use ExUnit.Case, async: true

  alias Messaging.Adapters.Inbox.Noop

  describe "enqueue/2" do
    test "returns :ok without storing anything" do
      assert :ok = Noop.enqueue("user-123", "msg-456")
    end
  end

  describe "mark_delivered/2" do
    test "returns :ok without doing anything" do
      assert :ok = Noop.mark_delivered("user-123", "msg-456")
    end
  end

  describe "pending_messages/1" do
    test "returns empty list" do
      assert {:ok, []} = Noop.pending_messages("user-123")
    end
  end

  describe "pending_messages/2" do
    test "returns empty list regardless of options" do
      assert {:ok, []} = Noop.pending_messages("user-123", limit: 10)
      assert {:ok, []} = Noop.pending_messages("user-123", offset: 5, limit: 20)
    end
  end

  describe "clear_delivered/1" do
    test "returns zero count" do
      assert {:ok, 0} = Noop.clear_delivered("user-123")
    end
  end

  describe "behavior compliance" do
    test "implements all callbacks from InboxStore behavior" do
      callbacks = Messaging.Behaviors.InboxStore.behaviour_info(:callbacks)

      # Verify all callbacks are implemented
      assert {:enqueue, 2} in callbacks
      assert {:mark_delivered, 2} in callbacks
      assert {:pending_messages, 1} in callbacks
      assert {:pending_messages, 2} in callbacks
      assert {:clear_delivered, 1} in callbacks
    end
  end
end
