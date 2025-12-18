defmodule Messaging.Config.ValidatorTest do
  use ExUnit.Case, async: true

  alias Messaging.Config
  alias Messaging.Config.Validator

  describe "validate!/1" do
    test "accepts valid configuration" do
      config = %Config{
        features: %{
          receipts: true,
          inbox: true,
          scheduled_delivery: true,
          media: true,
          file_ops: true,
          pubsub: true
        },
        storage: %{
          messages: :postgres,
          receipts: :postgres,
          inbox: :postgres,
          history: :postgres,
          blobs: :s3
        },
        scaling: %{
          mode: :single_node,
          job_isolation: false
        },
        jobs: %{
          deliver_realtime: 50,
          scheduled_delivery: 5,
          files: 4,
          heavy_io: 2
        }
      }

      assert ^config = Validator.validate!(config)
    end
  end

  describe "validate/1 - receipts validation" do
    test "fails when receipts enabled but storage is none" do
      config = %Config{
        features: %{receipts: true, inbox: false, scheduled_delivery: false, media: false, file_ops: false, pubsub: false},
        storage: %{messages: :postgres, receipts: :none, inbox: :none, history: :none, blobs: :none},
        scaling: %{mode: :single_node, job_isolation: false},
        jobs: %{deliver_realtime: 50, scheduled_delivery: 0, files: 0, heavy_io: 0}
      }

      assert {:error, errors} = Validator.validate(config)
      assert Enum.any?(errors, &String.contains?(&1, "Receipts feature"))
    end

    test "passes when receipts disabled" do
      config = %Config{
        features: %{receipts: false, inbox: false, scheduled_delivery: false, media: false, file_ops: false, pubsub: false},
        storage: %{messages: :postgres, receipts: :none, inbox: :none, history: :none, blobs: :none},
        scaling: %{mode: :single_node, job_isolation: false},
        jobs: %{deliver_realtime: 50, scheduled_delivery: 0, files: 0, heavy_io: 0}
      }

      assert {:ok, _config} = Validator.validate(config)
    end
  end

  describe "validate/1 - inbox validation" do
    test "fails when inbox enabled but storage is none" do
      config = %Config{
        features: %{receipts: false, inbox: true, scheduled_delivery: false, media: false, file_ops: false, pubsub: false},
        storage: %{messages: :postgres, receipts: :none, inbox: :none, history: :none, blobs: :none},
        scaling: %{mode: :single_node, job_isolation: false},
        jobs: %{deliver_realtime: 50, scheduled_delivery: 0, files: 0, heavy_io: 0}
      }

      assert {:error, errors} = Validator.validate(config)
      assert Enum.any?(errors, &String.contains?(&1, "Inbox feature"))
    end

    test "passes when inbox has valid storage" do
      config = %Config{
        features: %{receipts: false, inbox: true, scheduled_delivery: false, media: false, file_ops: false, pubsub: false},
        storage: %{messages: :postgres, receipts: :none, inbox: :postgres, history: :none, blobs: :none},
        scaling: %{mode: :single_node, job_isolation: false},
        jobs: %{deliver_realtime: 50, scheduled_delivery: 0, files: 0, heavy_io: 0}
      }

      assert {:ok, _config} = Validator.validate(config)
    end
  end

  describe "validate/1 - scheduled delivery validation" do
    test "fails when scheduled_delivery enabled but queue concurrency is 0" do
      config = %Config{
        features: %{receipts: false, inbox: false, scheduled_delivery: true, media: false, file_ops: false, pubsub: false},
        storage: %{messages: :postgres, receipts: :none, inbox: :none, history: :none, blobs: :none},
        scaling: %{mode: :single_node, job_isolation: false},
        jobs: %{deliver_realtime: 50, scheduled_delivery: 0, files: 0, heavy_io: 0}
      }

      assert {:error, errors} = Validator.validate(config)
      assert Enum.any?(errors, &String.contains?(&1, "Scheduled delivery"))
    end

    test "passes when scheduled_delivery has queue configured" do
      config = %Config{
        features: %{receipts: false, inbox: false, scheduled_delivery: true, media: false, file_ops: false, pubsub: false},
        storage: %{messages: :postgres, receipts: :none, inbox: :none, history: :none, blobs: :none},
        scaling: %{mode: :single_node, job_isolation: false},
        jobs: %{deliver_realtime: 50, scheduled_delivery: 5, files: 0, heavy_io: 0}
      }

      assert {:ok, _config} = Validator.validate(config)
    end
  end

  describe "validate/1 - media validation" do
    test "fails when media enabled but blobs storage is none" do
      config = %Config{
        features: %{receipts: false, inbox: false, scheduled_delivery: false, media: true, file_ops: false, pubsub: false},
        storage: %{messages: :postgres, receipts: :none, inbox: :none, history: :none, blobs: :none},
        scaling: %{mode: :single_node, job_isolation: false},
        jobs: %{deliver_realtime: 50, scheduled_delivery: 0, files: 0, heavy_io: 2}
      }

      assert {:error, errors} = Validator.validate(config)
      assert Enum.any?(errors, &String.contains?(&1, "Media feature"))
      assert Enum.any?(errors, &String.contains?(&1, "blobs"))
    end

    test "fails when media enabled but heavy_io queue is 0" do
      config = %Config{
        features: %{receipts: false, inbox: false, scheduled_delivery: false, media: true, file_ops: false, pubsub: false},
        storage: %{messages: :postgres, receipts: :none, inbox: :none, history: :none, blobs: :s3},
        scaling: %{mode: :single_node, job_isolation: false},
        jobs: %{deliver_realtime: 50, scheduled_delivery: 0, files: 0, heavy_io: 0}
      }

      assert {:error, errors} = Validator.validate(config)
      assert Enum.any?(errors, &String.contains?(&1, "Media feature"))
      assert Enum.any?(errors, &String.contains?(&1, "heavy_io"))
    end

    test "passes when media has both blobs storage and queue" do
      config = %Config{
        features: %{receipts: false, inbox: false, scheduled_delivery: false, media: true, file_ops: false, pubsub: false},
        storage: %{messages: :postgres, receipts: :none, inbox: :none, history: :none, blobs: :s3},
        scaling: %{mode: :single_node, job_isolation: false},
        jobs: %{deliver_realtime: 50, scheduled_delivery: 0, files: 0, heavy_io: 2}
      }

      assert {:ok, _config} = Validator.validate(config)
    end
  end

  describe "validate/1 - file ops validation" do
    test "fails when file_ops enabled but files queue is 0" do
      config = %Config{
        features: %{receipts: false, inbox: false, scheduled_delivery: false, media: false, file_ops: true, pubsub: false},
        storage: %{messages: :postgres, receipts: :none, inbox: :none, history: :none, blobs: :none},
        scaling: %{mode: :single_node, job_isolation: false},
        jobs: %{deliver_realtime: 50, scheduled_delivery: 0, files: 0, heavy_io: 0}
      }

      assert {:error, errors} = Validator.validate(config)
      assert Enum.any?(errors, &String.contains?(&1, "File operations"))
    end

    test "passes when file_ops has queue configured" do
      config = %Config{
        features: %{receipts: false, inbox: false, scheduled_delivery: false, media: false, file_ops: true, pubsub: false},
        storage: %{messages: :postgres, receipts: :none, inbox: :none, history: :none, blobs: :none},
        scaling: %{mode: :single_node, job_isolation: false},
        jobs: %{deliver_realtime: 50, scheduled_delivery: 0, files: 4, heavy_io: 0}
      }

      assert {:ok, _config} = Validator.validate(config)
    end
  end

  describe "validate/1 - multi-node validation" do
    test "fails when multi_node mode but messages storage is not postgres" do
      config = %Config{
        features: %{receipts: false, inbox: false, scheduled_delivery: false, media: false, file_ops: false, pubsub: false},
        storage: %{messages: :memory, receipts: :none, inbox: :none, history: :none, blobs: :none},
        scaling: %{mode: :multi_node, job_isolation: false},
        jobs: %{deliver_realtime: 50, scheduled_delivery: 0, files: 0, heavy_io: 0}
      }

      assert {:error, errors} = Validator.validate(config)
      assert Enum.any?(errors, &String.contains?(&1, "Multi-node"))
    end

    test "passes when multi_node with postgres storage" do
      config = %Config{
        features: %{receipts: false, inbox: false, scheduled_delivery: false, media: false, file_ops: false, pubsub: false},
        storage: %{messages: :postgres, receipts: :none, inbox: :none, history: :none, blobs: :none},
        scaling: %{mode: :multi_node, job_isolation: false},
        jobs: %{deliver_realtime: 50, scheduled_delivery: 0, files: 0, heavy_io: 0}
      }

      assert {:ok, _config} = Validator.validate(config)
    end
  end

  describe "validate/1 - multiple errors" do
    test "returns all validation errors" do
      config = %Config{
        features: %{receipts: true, inbox: true, scheduled_delivery: true, media: true, file_ops: true, pubsub: false},
        storage: %{messages: :postgres, receipts: :none, inbox: :none, history: :none, blobs: :none},
        scaling: %{mode: :single_node, job_isolation: false},
        jobs: %{deliver_realtime: 50, scheduled_delivery: 0, files: 0, heavy_io: 0}
      }

      assert {:error, errors} = Validator.validate(config)

      # Should have multiple errors
      assert length(errors) >= 5
      assert Enum.any?(errors, &String.contains?(&1, "Receipts"))
      assert Enum.any?(errors, &String.contains?(&1, "Inbox"))
      assert Enum.any?(errors, &String.contains?(&1, "Scheduled delivery"))
      assert Enum.any?(errors, &String.contains?(&1, "Media"))
      assert Enum.any?(errors, &String.contains?(&1, "File operations"))
    end
  end
end
