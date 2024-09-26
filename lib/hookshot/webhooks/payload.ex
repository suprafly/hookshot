defmodule Hookshot.Webhooks.Payload do
  @moduledoc """
  A `Payload` is a behaviour that defines a `new/1` callback that formats a webhook payload.
  """
  alias Hookshot.Events.Event

  @callback new(event :: Event.t()) :: payload :: map()
end
