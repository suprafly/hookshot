defmodule Hookshot.Events.Event do
  use Ecto.Schema

  import Ecto.Changeset

  alias Hookshot.EventTypes.EventType
  alias Hookshot.Subscriptions.Subscription

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  @foreign_key_type Ecto.UUID
  schema "hookshot_events" do
    field :status, Ecto.Enum, values: [:pending, :completed, :failed], default: :pending
    field :retries, :integer, default: 0

    field :data, Hookshot.Ecto.EncryptedMap
    field :metadata, Hookshot.Ecto.EncryptedMap

    field :target, :string

    # An optional field - if present it will be sent as a header
    field :signature_header, :string
    field :signature_data, :string

    field :occurred_at, :naive_datetime
    field :send_after, :naive_datetime

    # add(:type, references(:hookshot_event_types, column: :type, type: :string), null: false)
    belongs_to :event_type, Hookshot.EventTypes.EventType,
      foreign_key: :type,
      references: :name,
      type: :string

    # add(:subscription_id, references(:hookshot_subscriptions), null: false)
    belongs_to :subscription, Hookshot.Subscriptions.Subscription

    timestamps()
  end

  def create_changeset(event, %EventType{} = event_type, %Subscription{} = subscription, attrs) do
    event
    |> cast(attrs, [:data, :metadata, :target, :occurred_at, :signature_header, :signature_data])
    |> validate_required([:data, :occurred_at, :target])
    |> put_assoc(:event_type, event_type)
    |> put_assoc(:subscription, subscription)
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [:status, :retries, :send_after])
  end

  def default_signature_header do
    "Signature"
  end
end
