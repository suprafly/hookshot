defmodule Hookshot.EventTypes.EventType do
  @moduledoc """
  Event Types.
  """
  use Ecto.Schema

  @primary_key {:name, :string, autogenerate: false}
  schema "hookshot_event_types" do
    # Nothing else here, this is just a primary key string table
  end
end
