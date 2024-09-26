defmodule Hookshot.Subscriptions.Subscription do
  use Ecto.Schema
  import Ecto.Changeset

  alias Hookshot.EventTypes
  alias Hookshot.Webhooks.Signing

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  @foreign_key_type Ecto.UUID
  schema "hookshot_subscriptions" do
    # This is a unique key that is provided by the user of the library.
    field :resource_id, :string

    # The destination url
    field :target, :string

    field :secret, Hookshot.Ecto.Encrypted

    field :status, Ecto.Enum, values: [:active, :inactive, :flagged], default: :active
    field :flagged_reason, :string

    field :event_types, {:array, :string}

    timestamps()
  end

  def create_changeset(subscription, attrs) do
    subscription
    |> cast(attrs, [:resource_id, :target, :event_types])
    |> put_change(:secret, Signing.generate_secret())
    |> validate_required([:resource_id, :target, :event_types])
    |> validate_event_types()
    |> validate_format(:target, ~r/^https/, message: "must be an https url")
    |> validate_length(:secret, min: 16, max: 64)
  end

  def update_changeset(subscription, attrs) do
    subscription
    |> cast(attrs, [:status, :flagged_reason, :target, :event_types, :secret])
    |> validate_required([:target, :event_types])
    |> validate_event_types()
    |> validate_format(:target, ~r/^https/, message: "must be an https url")
    |> validate_length(:secret, min: 16, max: 64)
  end

  def validate_changes(subscription, attrs) do
    subscription
    |> cast(attrs, [:resource_id, :target, :event_types, :secret])
    |> validate_required([:resource_id, :target, :event_types])
    |> validate_event_types()
    |> validate_format(:target, ~r/^https/, message: "must be an https url")
    |> validate_length(:secret, min: 16, max: 64)
  end

  @doc false
  defp validate_event_types(changeset) do
    changeset
    |> validate_change(:event_types, fn field, values ->
        Enum.reduce(values, [], fn value, acc ->
          case EventTypes.get_event_type(value) do
            {:ok, _event_type} ->
              acc
            {:error, _error} ->
              [{field, "#{value} is an invalid event_type"} | acc]
          end
        end)
      end)
    |> validate_length(:event_types, min: 1)
  end
end
