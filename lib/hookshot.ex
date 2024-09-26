defmodule Hookshot do
  @moduledoc """
  The main interface.
  """
  use Supervisor

  require Logger

  alias Hookshot.EventProcessor
  alias Hookshot.Events.EventContext

  alias Hookshot.Events
  alias Hookshot.EventTypes
  alias Hookshot.Subscriptions

  alias Hookshot.Webhooks.Signing
  alias Hookshot.Webhooks.Webhook

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    default_producer_opts = [rate_limiting: [allowed_messages: 60, interval: 60_000]]
    producer_opts =
      :hookshot
      |> Application.get_env(:producer, default_producer_opts)
      |> Keyword.take([:rate_limiting])


    default_processor_opts = [concurrency: 1]
    processor_opts =
      :hookshot
      |> Application.get_env(:processor, default_processor_opts)
      |> Keyword.take([:concurrency])

    children = [
      # {ExRated, [[timeout: 10_000, cleanup_rate: 10_000, persistent: false], [name: :ex_rated]]},
      {Hookshot.Queue, []},
      {EventProcessor, {producer_opts, processor_opts}}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def repo do
    Application.get_env(:hookshot, :repo)
  end

  def json do
    Application.get_env(:hookshot, :json_library)
  end

  def webhook_payload do
    Application.get_env(:hookshot, :payload, Webhook)
  end

  # @doc """
  # Send a fake webhook for testing purposes.
  # """
  # def fake_webbhook(url) do
  #   event_type_map = EventTypes.list_event_types() |> Map.new(&{&1.name, &1})
  #   with [subscription | _] <- Subscriptions.list_subscriptions() do
  #     data = %{"first_name" => Faker.Person.first_name(), "last_name" => Faker.Person.last_name()}
  #     ctx = EventContext.new(subscription.resource_id, :submission, :created, NaiveDateTime.utc_now, data)
  #     event_type = event_type_map["#{ctx.resource}.#{ctx.action}"]

  #     attrs =
  #       ctx
  #       |> Map.from_struct()
  #       |> Map.put(:target, url)

  #     case Events.create_event(event_type, subscription, attrs) do
  #       {:ok, event} ->
  #         Hookshot.Queue.push(event)
  #         {:ok, :webhook_sent}

  #       {:error, error} ->
  #         # todo - log error
  #         Logger.error(inspect(error))
  #         {:error, error}
  #     end
  #   end
  # end

  def send_webhook(%EventContext{} = event_context) do
    event_context
    |> preprocess_event_context()
    |> do_send()
  end

  defp preprocess_event_context(event_context) do
    event_context
  end

  defp do_send(event_context) do
    event_type_map = EventTypes.list_event_types() |> Map.new(&{&1.name, &1})

    event_context.resource_id
    |> Subscriptions.list_subscriptions_for_resource_id()
    |> Enum.each(fn subscription ->
      event_type = event_type_map["#{event_context.resource}.#{event_context.action}"]

      attrs =
        event_context
        |> maybe_add_signature_header(subscription.secret)
        |> Map.from_struct()
        |> Map.put(:target, subscription.target)

      case Events.create_event(event_type, subscription, attrs) do
        {:ok, event} ->
          Hookshot.Queue.push(event)
          {:ok, :webhook_sent}

        {:error, error} ->
          # todo - log error
          Logger.error(inspect(error))
          {:error, error}
      end
    end)
  end

  defp maybe_add_signature_header(%EventContext{} = event_context, nil) do
    # No secret, no header
    event_context
  end

  defp maybe_add_signature_header(%EventContext{signature_header: signature_header, signature_data: nil} = event_context, secret) do
    # If there is no signature data set, but there is a valid secret, then generate the header.
    {header_name, header_content} = Signing.get_signature_header(secret, event_context.data)
    if is_nil(signature_header) do
      {header_name, header_content}
      %{event_context | signature_header: header_name, signature_data: header_content}
    else
      # If the user has passed a custom `signature_header` in, use it.
      %{event_context | signature_header: signature_header, signature_data: header_content}
    end
  end

  defp maybe_add_signature_header(%EventContext{signature_header: signature_header, signature_data: signature_data} = event_context, _secret) do
    if is_nil(signature_header) do
      # The data has already been provided, but no header, so use the default
      %{event_context | signature_header: Signing.header_name(), signature_data: signature_data}
    else
      # The data and the headwer are provided, but no header, so use it
      %{event_context | signature_header: signature_header, signature_data: signature_data}
    end
  end
end
