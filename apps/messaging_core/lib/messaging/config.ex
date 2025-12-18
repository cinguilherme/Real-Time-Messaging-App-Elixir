defmodule Messaging.Config do
  @moduledoc """
  Configuration structure for feature flags and system settings.
  """

  @type t :: %__MODULE__{
          features: features(),
          storage: storage(),
          scaling: scaling(),
          jobs: jobs()
        }

  @type features :: %{
          receipts: boolean(),
          inbox: boolean(),
          scheduled_delivery: boolean(),
          media: boolean(),
          file_ops: boolean(),
          pubsub: boolean()
        }

  @type storage :: %{
          messages: :postgres | :memory,
          receipts: :postgres | :none,
          inbox: :postgres | :redis | :none,
          history: :postgres | :none,
          blobs: :s3 | :local | :none
        }

  @type scaling :: %{
          mode: :single_node | :multi_node,
          job_isolation: boolean()
        }

  @type jobs :: %{
          deliver_realtime: non_neg_integer(),
          scheduled_delivery: non_neg_integer(),
          files: non_neg_integer(),
          heavy_io: non_neg_integer()
        }

  defstruct features: %{
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
end
