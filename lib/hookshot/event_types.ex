defmodule Hookshot.EventTypes do
  @moduledoc """
  Event Types.
  """
  import Ecto.Query, warn: false

  alias Hookshot.EventTypes.EventType

  def list_event_types do
    EventType
    |> Hookshot.repo().all()
  end

  def list_event_type_names do
    list_event_types() |> Enum.map(& &1.name)
  end

  def list_event_types_for_resource(resource) do
    (from et in EventType, where: ilike(et.name, ^"%#{resource}%"))
    |> Hookshot.repo().all()
  end

  def create_event_type(resource, action) do
    %EventType{name: "#{resource}.#{action}"}
    |> Hookshot.repo().insert()
  end

  def get_event_type!(resource, action) do
    get_event_type!("#{resource}.#{action}")
  end

  def get_event_type!(event_type_str) do
    Hookshot.repo().get!(EventType, event_type_str)
  end

  def get_event_type(resource, action) do
    get_event_type("#{resource}.#{action}")
  end

  def get_event_type(event_type_str) do
    (from et in EventType, where: et.name == ^event_type_str)
    |> Hookshot.repo().one()
    |> case do
      nil -> {:error, :not_found}
      event_type -> {:ok, event_type}
    end
  end
end
