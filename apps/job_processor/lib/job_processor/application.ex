defmodule JobProcessor.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Load feature configuration
    config = Messaging.Config.Loader.load!()

    children = build_children(config)

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: JobProcessor.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp build_children(config) do
    [
      # Start Oban only if any job queues are configured
      (if needs_oban?(config) do
        {Oban, build_oban_config(config)}
      end)
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp needs_oban?(config) do
    config.jobs.deliver_realtime > 0 or
      config.jobs.scheduled_delivery > 0 or
      config.jobs.files > 0 or
      config.jobs.heavy_io > 0
  end

  defp build_oban_config(config) do
    base_config = Application.fetch_env!(:job_processor, Oban)
    queues = build_queues(config)

    Keyword.put(base_config, :queues, queues)
  end

  defp build_queues(config) do
    []
    |> maybe_add_queue(:deliver_realtime, config.jobs.deliver_realtime)
    |> maybe_add_queue(:scheduled_delivery, config.jobs.scheduled_delivery)
    |> maybe_add_queue(:files, config.jobs.files)
    |> maybe_add_queue(:heavy_io, config.jobs.heavy_io)
  end

  defp maybe_add_queue(queues, _name, 0), do: queues

  defp maybe_add_queue(queues, name, concurrency) when concurrency > 0 do
    Keyword.put(queues, name, concurrency)
  end
end
