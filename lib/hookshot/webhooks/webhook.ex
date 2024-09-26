defmodule Hookshot.Webhooks.Webhook do
  @moduledoc """
  A `Webhook` is a struct that holds the data which is formatted from an `Event`s.

  It is the struct-version of the payload data that is actually sent to the client.
  """

  @behaviour Hookshot.Webhooks.Payload

  alias Hookshot.Events.Event

  @type resource :: String.t()
  @type event :: String.t()
  @type data :: map()
  @type metadata :: map()
  @type occurred_at :: String.t()

  @type t :: %__MODULE__{
          resource: resource,
          event: event,
          occurred_at: occurred_at | nil,
          data: data,
          metadata: metadata,
        }

  @derive Jason.Encoder
  defstruct resource: nil,
            event: nil,
            occurred_at: nil,
            data: %{},
            metadata: %{}

  def new(%Event{} = event) do
    %__MODULE__{
      resource: get_resource(event.type),
      event: event.type,
      occurred_at: event.occurred_at,
      data: event.data,
      metadata: event.metadata
    }
    |> Map.from_struct()
  end

  defp get_resource(event_type) do
    event_type
    |> String.split(".")
    |> List.first()
  end
end
