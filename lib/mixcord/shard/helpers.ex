defmodule Mixcord.Shard.Helpers do
  @moduledoc """
  """

  alias Mixcord.Constants
  alias Mixcord.Rest.Client
  alias Mixcord.Shard.Dispatch

  @num_shards Application.get_env(:mixcord, :num_shards)

  def status_update(pid, {idle, game}) do
    status_json = Poison.encode!(%{game: %{name: game}, idle: idle})
    send(pid, {:status_update, status_json})
  end

  @doc false
  def handle_dispatch(payload, state_map) do
    Dispatch.handle_event(payload)
    state_map.caller.handle_event({payload.t, payload.d}, state_map)
  end

  @doc false
  def state_map(token, caller, shard_num) do
    state = %{
      token: token,
      caller: caller,
      shard_num: shard_num,
      seq: nil,
      session: nil,
      reconnect_attempts: 0,
      last_heartbeat: 0,
      heartbeat_intervals: Enum.map(1..10, fn _ -> 0 end)
    }
    state
  end

  @doc false
  def empty_cache do
    Mixcord.Cache.Supervisor.empty_cache
  end

  @doc false
  def heartbeat_payload(sequence) do
    build_payload(Constants.opcode_from_name("HEARTBEAT"), nil, sequence)
  end

  @doc false
  def identity_payload(state_map) do
    data = %{
      "token" => state_map.token,
      "properties" => %{
        "$os" => "Linux",
        "$browser" => "Mixcord",
        "$device" => "Mixcord",
        "$referrer" => "",
        "$referring_domain" => ""
      },
      "compress" => false,
      "large_threshold" => 250,
      "shard" => [state_map.shard_num, @num_shards]
    }
    build_payload(Constants.opcode_from_name("IDENTIFY"), data)
  end

  @doc false
  def status_update_payload(json) do
    build_payload(Constants.opcode_from_name("STATUS_UPDATE"), json)
  end

  @doc false
  def build_payload(opcode, data, event \\ nil, seq \\ nil) do
    %{"op" => opcode, "d" => data, "s" => seq, "t" => event}
      |> :erlang.term_to_binary
  end

  @doc false
  def heartbeat(pid, interval) do
    Process.send_after(pid, {:heartbeat, interval}, interval)
  end

  @doc false
  def identify(pid) do
    send(pid, :identify)
  end

  @doc false
  def gateway do
    case :ets.lookup(:gateway_url, "url") do
      [] -> get_new_gateway_url
      [{"url", url}] -> url
    end
  end

  defp get_new_gateway_url do
    case Client.request(:get, Constants.gateway, "") do
      {:error, status_code: status_code, message: message} ->
        raise(Mixcord.Error.ApiError, status_code: status_code, message: message)
      {:ok, body: body} ->
        body = Poison.decode!(body)

        url = body["url"] <> "?encoding=etf&v=6"
          |> to_charlist
        :ets.insert(:gateway_url, {"url", url})

        url
    end
  end

  @doc false
  def now do
    DateTime.utc_now
      |> DateTime.to_unix(:milliseconds)
  end

end