defmodule Messaging.Adapters.Blobs.NoopTest do
  use ExUnit.Case, async: true

  alias Messaging.Adapters.Blobs.Noop

  describe "put/3" do
    test "returns fake URL without storing data" do
      assert {:ok, url} = Noop.put("test-key", <<1, 2, 3>>)
      assert url =~ "noop://storage/test-key"
    end

    test "accepts options but ignores them" do
      assert {:ok, url} = Noop.put("test-key", <<1, 2, 3>>, content_type: "image/jpeg", acl: :public_read)
      assert url =~ "noop://storage/test-key"
    end
  end

  describe "get/1" do
    test "returns not_found error" do
      assert {:error, :not_found} = Noop.get("test-key")
    end
  end

  describe "delete/1" do
    test "returns :ok without doing anything" do
      assert :ok = Noop.delete("test-key")
    end
  end

  describe "exists?/1" do
    test "returns false for any key" do
      assert {:ok, false} = Noop.exists?("test-key")
      assert {:ok, false} = Noop.exists?("another-key")
    end
  end

  describe "presigned_url/2" do
    test "returns fake presigned URL" do
      assert {:ok, url} = Noop.presigned_url("test-key")
      assert url =~ "noop://storage/test-key"
      assert url =~ "presigned=true"
    end

    test "accepts options but ignores them" do
      assert {:ok, url} = Noop.presigned_url("test-key", expires_in: 3600)
      assert url =~ "noop://storage/test-key"
    end
  end

  describe "behavior compliance" do
    test "implements all callbacks from BlobStore behavior" do
      callbacks = Messaging.Behaviors.BlobStore.behaviour_info(:callbacks)

      # Verify all callbacks are implemented
      assert {:put, 3} in callbacks
      assert {:get, 1} in callbacks
      assert {:delete, 1} in callbacks
      assert {:exists?, 1} in callbacks
      assert {:presigned_url, 2} in callbacks
    end
  end
end
