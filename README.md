# Hookshot

![hookshot](hookshot_01.jpeg)

## Overview

Hookshot is a robust framework for enabling webhooks in your Phoenix app. It leverages Broadway for event ingestion.


## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `hookshot` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:hookshot, "~> 0.1.0"}
  ]
end
```

## Setup

First generate an encryption key and set is as the env var, `HOOKSHOT_ENCRYPTION_KEY`,

```
mix hookshot.gen.encryption_key
I4E3fpY2QtNg3K7t9YeToKSfTz/2w/NS8xexkBW4tmQ=
```

Then set this, as an environment variable,

```
export HOOKSHOT_ENCRYPTION_KEY  =I4E3fpY2QtNg3K7t9YeToKSfTz/2w/NS8xexkBW4tmQ=
```

Update the `config/config.exs` for `Hookshot`, making sure to remember to add your own `:repo` module.

```
config :hookshot,
  repo: MyApp.Repo,
  json_library: Jason,
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
```

Next, generate the migrations for `Hookshot`,

```
mix hookshot.gen.migrations

mix ecto.migrate
```

Now you must seed the event types, which are created from the config values you defined above,

```
mix hookshot.seed.event_types
```

Finally, add `Hookshot` to your `application.ex` in the `start/2` call,

```
def start(_type, _args) do
  children = [
    MyAppWeb.Telemetry,
    MyApp.Repo,
    {Phoenix.PubSub, name: MyApp.PubSub},
    {Finch, name: MyApp.Finch},
    MyAppWeb.Endpoint,

    # Add Hookshot here
    {Hookshot, []},
  ]

  opts = [strategy: :one_for_one, name: MyApp.Supervisor]
  Supervisor.start_link(children, opts)
end
```

## Custom Webhook Payloads

By default `Hookshot.Webhooks.Webhook` defines the strcucture of a webhook payload. If you want to define your own, you can simply implement the `Hookshot.Webhooks.Payload` behaviour, and then set it in your config,

```
config :hookshot,
  payload: MyApp.CustomWebhookPayload,
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/hookshot>.

