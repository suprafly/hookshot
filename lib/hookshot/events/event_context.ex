defmodule Hookshot.Events.EventContext do
  @moduledoc """
  An `EventContext` is a struct that is used to generate `Event`s.

  It contains all of the information coming from an external system
  that will be used to generate the internal `Event` data structure.
  """

  @type resource_id :: UUID.t()
  @type resource :: atom()
  @type action :: atom()
  @type data :: map()
  @type metadata :: map()
  @type occurred_at :: String.t()
  @type signature_header :: String.t()
  @type signature_data :: String.t()

  @type t :: %__MODULE__{
          resource_id: resource_id | nil,
          resource: resource | nil,
          action: action | nil,
          data: data,
          metadata: metadata,
          occurred_at: occurred_at | nil,
          signature_header: signature_header | nil,
          signature_data: signature_data | nil
        }

  defstruct resource_id: nil,
            resource: nil,
            action: nil,
            data: %{},
            occurred_at: nil,
            metadata: %{},
            signature_header: nil,
            signature_data: nil

  def new(resource_id, resource, action, occurred_at, data, metadata \\ %{}, signature_header \\ nil, signature_data \\ nil) do
    %__MODULE__{
      resource_id: resource_id,
      resource: resource,
      action: action,
      data: data,
      occurred_at: occurred_at,
      metadata: metadata,
      signature_header: signature_header,
      signature_data: signature_data
    }
  end
end
