defmodule Messaging.Adapters.History.NoopTest do
  use ExUnit.Case, async: true

  alias Messaging.Adapters.History.Noop

  describe "store_message/1" do
    test "returns :ok without storing anything" do
      message = %{id: "msg-123", conversation_id: "conv-456", body: %{text: "Hello"}}
      assert :ok = Noop.store_message(message)
    end
  end

  describe "get_conversation_history/2" do
    test "returns empty list" do
      assert {:ok, []} = Noop.get_conversation_history("conv-123")
    end

    test "returns empty list regardless of options" do
      assert {:ok, []} = Noop.get_conversation_history("conv-123", limit: 50, offset: 10)
      assert {:ok, []} = Noop.get_conversation_history("conv-123", before: "msg-100")
      assert {:ok, []} = Noop.get_conversation_history("conv-123", order: :asc)
    end
  end

  describe "count_messages/1" do
    test "returns zero count" do
      assert {:ok, 0} = Noop.count_messages("conv-123")
    end
  end

  describe "search_messages/3" do
    test "returns empty list for any query" do
      assert {:ok, []} = Noop.search_messages("conv-123", "hello")
      assert {:ok, []} = Noop.search_messages("conv-123", "world", limit: 10)
    end
  end

  describe "delete_conversation_history/1" do
    test "returns zero count" do
      assert {:ok, 0} = Noop.delete_conversation_history("conv-123")
    end
  end

  describe "behavior compliance" do
    test "implements all callbacks from HistoryStore behavior" do
      callbacks = Messaging.Behaviors.HistoryStore.behaviour_info(:callbacks)

      # Verify all callbacks are implemented
      assert {:store_message, 1} in callbacks
      assert {:get_conversation_history, 2} in callbacks
      assert {:count_messages, 1} in callbacks
      assert {:search_messages, 3} in callbacks
      assert {:delete_conversation_history, 1} in callbacks
    end
  end
end
