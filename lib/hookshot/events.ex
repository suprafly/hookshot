defmodule Hookshot.Events do
  @moduledoc """
  Events
  """
  import Ecto.Query, warn: false

  alias Hookshot.Events.Event

  def list_events() do
    Hookshot.repo().all(Event)
  end

  def list_pending_events(max_retries \\ 5) do
    (from event in Event,
      where: (event.status == :pending) and (event.retries < ^max_retries))
    |> join(:left, [event], subscription in assoc(event, :subscription), as: :subscription)
    |> preload([event, subscription], [subscription: subscription])
    |> Hookshot.repo().all()
  end

  def create_event(event_type, subscription, attrs) do
    %Event{}
    |> Event.create_changeset(event_type, subscription, attrs)
    |> Hookshot.repo().insert()
  end

  def get_event!(id) do
    Hookshot.repo().get!(Event, id)
  end

  def update_event(%Event{} = event, attrs) do
    event
    |> Event.changeset(attrs)
    |> Hookshot.repo().update()
  end

  # defp max_retries do
  #   5
  # end
end
