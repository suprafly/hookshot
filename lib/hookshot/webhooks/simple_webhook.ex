defmodule Hookshot.Webhooks.SimpleWebhook do
  @moduledoc """
  This is a very simple webhook payload implementation to be used
  as an example. It merely passes the Event's data's payload field.
  """

  @behaviour Hookshot.Webhooks.Payload

  alias Hookshot.Events.Event

  def new(%Event{} = event), do: event.data["payload"]
end
