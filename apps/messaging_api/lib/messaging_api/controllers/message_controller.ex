defmodule MessagingApi.MessageController do
  use Phoenix.Controller, formats: [:json]

  import Ecto.Query
  alias Messaging.{Repo, Messages}
  alias Messaging.Schemas.Message

  def create(conn, params) do
    # Extract message parameters
    message_params = %{
      conversation_id: params["conversation_id"],
      sender_id: params["sender_id"],
      body: params["body"],
      idempotency_key: params["idempotency_key"],
      scheduled_at: params["scheduled_at"]
    }

    # Get next sequence number for this conversation
    next_seq = get_next_sequence(message_params.conversation_id)
    message_params = Map.put(message_params, :seq, next_seq)

    case Messages.create_message(message_params) do
      {:ok, message} ->
        # TODO: Enqueue Oban job for delivery here
        # For now, we'll just return the message as queued

        conn
        |> put_status(:created)
        |> json(%{
          message_id: message.id,
          status: "queued",
          seq: message.seq,
          conversation_id: message.conversation_id,
          inserted_at: message.inserted_at
        })

      {:error, changeset} ->
        errors = format_errors(changeset)
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Failed to create message", details: errors})
    end
  end

  def list(conn, %{"conversation_id" => conversation_id}) do
    messages =
      Message
      |> where([m], m.conversation_id == ^conversation_id)
      |> order_by([m], asc: m.seq)
      |> Repo.all()

    formatted_messages = Enum.map(messages, fn msg ->
      %{
        id: msg.id,
        conversation_id: msg.conversation_id,
        sender_id: msg.sender_id,
        seq: msg.seq,
        body: msg.body,
        status: msg.status,
        sent_at: msg.sent_at,
        delivered_at: msg.delivered_at,
        read_at: msg.read_at,
        inserted_at: msg.inserted_at
      }
    end)

    json(conn, %{messages: formatted_messages, count: length(formatted_messages)})
  end

  def mark_read(conn, %{"id" => message_id}) do
    case Repo.get(Message, message_id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Message not found"})

      message ->
        case Messages.update_message(message, %{
          status: :read,
          read_at: DateTime.utc_now()
        }) do
          {:ok, updated_message} ->
            # TODO: Broadcast read event via PubSub

            conn
            |> put_status(:ok)
            |> json(%{
              message_id: updated_message.id,
              status: "read",
              read_at: updated_message.read_at
            })

          {:error, changeset} ->
            errors = format_errors(changeset)
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: "Failed to mark as read", details: errors})
        end
    end
  end

  def mark_delivered(conn, %{"id" => message_id}) do
    case Repo.get(Message, message_id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Message not found"})

      message ->
        case Messages.update_message(message, %{
          status: :delivered,
          delivered_at: DateTime.utc_now()
        }) do
          {:ok, updated_message} ->
            # TODO: Broadcast delivered event via PubSub

            conn
            |> put_status(:ok)
            |> json(%{
              message_id: updated_message.id,
              status: "delivered",
              delivered_at: updated_message.delivered_at
            })

          {:error, changeset} ->
            errors = format_errors(changeset)
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: "Failed to mark as delivered", details: errors})
        end
    end
  end

  # Private functions

  defp get_next_sequence(conversation_id) do
    query = from m in Message,
      where: m.conversation_id == ^conversation_id,
      select: max(m.seq)

    case Repo.one(query) do
      nil -> 1
      max_seq -> max_seq + 1
    end
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
