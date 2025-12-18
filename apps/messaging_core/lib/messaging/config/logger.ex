defmodule Messaging.Config.Logger do
  @moduledoc """
  Logs feature configuration summary at boot time.
  """

  require Logger
  alias Messaging.Config

  @doc """
  Logs a formatted summary of the loaded configuration.
  """
  @spec log_boot_summary(Config.t()) :: :ok
  def log_boot_summary(%Config{} = config) do
    Logger.info("⚙️  Feature Configuration Loaded")
    Logger.info("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

    log_features(config.features)
    log_storage(config.storage)
    log_scaling(config.scaling)
    log_jobs(config.jobs)

    Logger.info("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    :ok
  end

  # Private functions

  defp log_features(features) do
    Logger.info("Features:")
    Logger.info("  #{status_icon(true)} Messages (core)")
    Logger.info("  #{status_icon(features.receipts)} Receipts (per-user tracking)")
    Logger.info("  #{status_icon(features.inbox)} Inbox (offline queue)")
    Logger.info("  #{status_icon(features.scheduled_delivery)} Scheduled delivery")
    Logger.info("  #{status_icon(features.media)} Media processing")
    Logger.info("  #{status_icon(features.file_ops)} File operations")
    Logger.info("  #{status_icon(features.pubsub)} PubSub broadcasts")
  end

  defp log_storage(storage) do
    Logger.info("Storage:")
    Logger.info("  Messages: #{storage.messages}")
    Logger.info("  Receipts: #{storage.receipts}")
    Logger.info("  Inbox: #{storage.inbox}")
    Logger.info("  History: #{storage.history}")
    Logger.info("  Blobs: #{storage.blobs}")
  end

  defp log_scaling(scaling) do
    Logger.info("Scaling:")
    Logger.info("  Mode: #{scaling.mode}")
    Logger.info("  Job Isolation: #{scaling.job_isolation}")
  end

  defp log_jobs(jobs) do
    Logger.info("Job Queues:")

    if jobs.deliver_realtime > 0 do
      Logger.info("  deliver_realtime: #{jobs.deliver_realtime}")
    end

    if jobs.scheduled_delivery > 0 do
      Logger.info("  scheduled_delivery: #{jobs.scheduled_delivery}")
    end

    if jobs.files > 0 do
      Logger.info("  files: #{jobs.files}")
    end

    if jobs.heavy_io > 0 do
      Logger.info("  heavy_io: #{jobs.heavy_io}")
    end
  end

  defp status_icon(true), do: "✓"
  defp status_icon(false), do: "✗"
end
