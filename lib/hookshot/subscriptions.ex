defmodule Hookshot.Subscriptions do
  @moduledoc """
  Subscriptions.
  """
  import Ecto.Query, warn: false

  alias Hookshot.Subscriptions.Subscription

  def list_subscriptions do
    Subscription
    |> Hookshot.repo().all()
  end

  def list_subscriptions_for_resource_id(resource_id) do
    (from s in Subscription, where: s.resource_id == ^resource_id)
    |> Hookshot.repo().all()
  end

  def get_subscription!(id) do
    Hookshot.repo().get!(Subscription, id)
  end

  def get_subscription_for_resource_id(resource_id) do
    (from s in Subscription, where: s.resource_id == ^resource_id)
    |> Hookshot.repo().one()
    |> case do
      nil -> {:error, :not_found}
      subscription -> {:ok, subscription}
    end
  end

  def create_subscription(attrs) do
    %Subscription{}
    |> Subscription.create_changeset(attrs)
    |> Hookshot.repo().insert()
  end

  def update_subscription(%Ecto.Changeset{} = subscription_changeset) do
    subscription_changeset |> Hookshot.repo().update()
  end

  def update_subscription(id, attrs) do
    id
    |> get_subscription!()
    |> Subscription.update_changeset(attrs)
    |> update_subscription()
  end

  def disable_subscription(id, reason) do
    id
    |> get_subscription!()
    |> Subscription.update_changeset(%{status: :flagged, flagged_reason: reason})
    |> Hookshot.repo().update()
  end
end
