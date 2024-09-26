defmodule Hookshot.Webhooks.Signing do
  @moduledoc """
  Handles webhhok signing and secrets.
  """

  def header_name do
    "X-Signature"
  end

  def get_signature_header(secret, data) when is_map(data) do
    # https://dashbit.co/blog/how-we-verify-webhooks
    ts = System.system_time(:second)
    with {:ok, json} <- Hookshot.json().encode(data),
         {:ok, signature} <- signature(secret, ts, json) do
      {header_name(), "t=#{ts},v1=#{signature}"}
    else
      _ -> nil
    end
  end

  def generate_secret(bytes \\ 32) do
    bytes |> :crypto.strong_rand_bytes() |> Base.encode64()
  end

  def signature!(secret, ts, json) do
    :crypto.mac(:hmac, :sha256, secret, "#{ts}.#{json}") |> Base.encode16(case: :lower)
  end

  def signature(secret, ts, json) do
    {:ok, :crypto.mac(:hmac, :sha256, secret, "#{ts}.#{json}") |> Base.encode16(case: :lower)}
  end

  def verify(secret, ts, json, v1) do
    v1 == signature!(secret, ts, json)
  end
end
