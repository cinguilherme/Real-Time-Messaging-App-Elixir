defmodule MessagingApi.UserSocket do
  use Phoenix.Socket

  # Channels will be added here later
  # channel "conv:*", MessagingApi.ConversationChannel
  # channel "msg:*", MessagingApi.MessageChannel

  @impl true
  def connect(_params, socket, _connect_info) do
    {:ok, socket}
  end

  @impl true
  def id(_socket), do: nil
end
