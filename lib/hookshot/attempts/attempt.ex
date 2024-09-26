defmodule Hookshot.Attempts.Attempt do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  @foreign_key_type Ecto.UUID
  schema "hookshot_attempts" do
    field :status, Ecto.Enum, values: [:succeeded, :failed]

    field :response_status_code, :integer
    field :within_time_frame, :boolean

    belongs_to :event, Hookshot.Events.Event
    belongs_to :subscription, Hookshot.Subscriptions.Subscription

    field :request_sent_at, :naive_datetime
    field :response_received_at, :naive_datetime

    timestamps()
  end

  def create_changeset(attempt, event, subscription, attrs) do
    attempt
    |> cast(attrs, [:status, :response_status_code, :within_time_frame, :request_sent_at, :response_received_at])
    |> validate_required([:status, :response_status_code, :within_time_frame, :request_sent_at, :response_received_at])
    |> put_assoc(:event, event)
    |> put_assoc(:subscription, subscription)
  end
end
