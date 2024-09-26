defmodule Hookshot.Retry do
  @moduledoc """
  Retry logic.


  # [Retry - Exponential Backoff](https://www.contentstack.com/docs/developers/set-up-webhooks/webhook-retry-policy)
  # - Wait 30 seconds, then...
  # Retry Instance,   Next Resend Interval (seconds)
  # 1,  5
  # 2,  25
  # 3,  125
  # 4,  625


  # [Stripe](https://docs.stripe.com/webhooks#behaviors)
  # Retry behavior
  # In live mode, Stripe attempts to deliver a given event to your webhook endpoint for up to 3 days with an exponential back off. In the Events section of the Dashboard, you can view when the next retry will occur.
  # 1 minute, 1 hour, 4 hours, then 14 hours [StackOverflow](https://stackoverflow.com/questions/41449842/will-stripe-api-retry-a-webhook-request-if-my-server-was-unable-to-receive-it)

  # Disable behavior
  # In live and test mode, Stripe attempts to notify you of a misconfigured endpoint by email if the endpoint hasn’t responded with a 2xx HTTP status code for multiple days in a row. The email also states when the endpoint will be automatically disabled.


  # Svix
  # [Retries](https://docs.svix.com/retries)
  # [Best practices](https://www.svix.com/resources/webhook-best-practices/retries/)

  # Retry Schedule
  # - Immediately
  # - 5 seconds
  # - 5 minutes
  # - 30 minutes
  # - 2 hours
  # - 5 hours
  # - 10 hours
  # - 10 hours (in addition to the previous)
  """

  alias Hookshot.Events.Event

  @one_second_in_ms 1_000
  @one_minute_in_ms @one_second_in_ms * 60
  @one_hour_in_ms @one_minute_in_ms * 60

  @schedule_for_five_retries %{
    # 10 seconds
    1 => @one_second_in_ms * 10,

    # 1 hour
    2 => @one_hour_in_ms,

    # 6 hours
    3 => @one_hour_in_ms * 6,

    # 12 hours
    4 => @one_hour_in_ms * 12,

    # 24 hours
    5 => @one_hour_in_ms * 20
  }

  @schedule_for_eight_retries %{
    # 1 second
    1 => @one_second_in_ms,

    # 5 seconds
    2 => @one_second_in_ms * 5,

    # 5 minutes
    3 => @one_minute_in_ms * 5,

    # 30 minutes
    4 => @one_minute_in_ms * 30,

    # 2 hours
    5 => @one_hour_in_ms * 2,

    # 5 hours
    6 => @one_hour_in_ms * 5,

    # 10 hours
    7 => @one_hour_in_ms * 10,

    # 20 hours
    8 => @one_hour_in_ms * 20
  }

  @default_schedules %{
    5 => @schedule_for_five_retries,
    8 => @schedule_for_eight_retries
  }

  def next_retry_ms(%Event{} = event, max_attempts, add_jitter \\ true) do
    retry_schedule = @default_schedules[max_attempts]
    if is_nil(retry_schedule) do
      {:error, :invalid_retry_schedule}
    else
      retry_attempt = event.retries + 1
      if retry_attempt <= max_attempts do
        {:ok, get_retry_ms(retry_schedule, retry_attempt, add_jitter)}
      else
        {:error, :max_retries_reached}
      end
    end
  end

  defp jitter() do
    # If the max is too low, set it to 10 seconds
    # max_ms = if max_ms <= 20, do: 10_000
    Enum.random(10..10_000)
  end

  defp get_retry_ms(retry_schedule, retry_attempt, true) do
    retry_schedule[retry_attempt] + jitter()
  end

  defp get_retry_ms(retry_schedule, retry_attempt, false) do
    retry_schedule[retry_attempt]
  end
end
