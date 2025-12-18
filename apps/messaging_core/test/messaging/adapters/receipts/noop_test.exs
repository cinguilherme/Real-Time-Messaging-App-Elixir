defmodule Messaging.Adapters.Receipts.NoopTest do
  use ExUnit.Case, async: true

  alias Messaging.Adapters.Receipts.Noop

  describe "record_delivery/2" do
    test "returns :ok without storing anything" do
      assert :ok = Noop.record_delivery("msg-123", "user-456")
    end
  end

  describe "record_read/2" do
    test "returns :ok without storing anything" do
      assert :ok = Noop.record_read("msg-123", "user-456")
    end
  end

  describe "get_receipts/1" do
    test "returns empty list" do
      assert {:ok, []} = Noop.get_receipts("msg-123")
    end
  end

  describe "get_receipts_by_status/2" do
    test "returns empty list for any status" do
      assert {:ok, []} = Noop.get_receipts_by_status("msg-123", :delivered)
      assert {:ok, []} = Noop.get_receipts_by_status("msg-123", :read)
    end
  end

  describe "behavior compliance" do
    test "implements all callbacks from ReceiptsStore behavior" do
      callbacks = Messaging.Behaviors.ReceiptsStore.behaviour_info(:callbacks)

      # Verify all callbacks are implemented
      assert {:record_delivery, 2} in callbacks
      assert {:record_read, 2} in callbacks
      assert {:get_receipts, 1} in callbacks
      assert {:get_receipts_by_status, 2} in callbacks
    end
  end
end
