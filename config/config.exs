# General application configuration
import Config

config :hookshot,
  # repo: MyApp.Repo,
  json_library: Jason,
  # payload: Hookshot.Webhooks.SimpleWebhook,
  event_types: [
    submission: [:created, :updated, :deleted]
  ],
  producer: [
    rate_limiting: [
      allowed_messages: 60,
      interval: 60_000
    ],
  ],
  processor: [
    # concurrency: 5
    concurrency: 1
  ]
