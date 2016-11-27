defmodule Wmata.Worker do
  use GenServer

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def get_station_info(pid, station) do
    GenServer.call(pid, {:station, station})
  end

  ## Server Callbacks

  def init(:ok) do
    {:ok, %{}}
  end

  def handle_call({:station, station}, _from, state) do
    case station_info_of(station) do
      {:ok, next_train} ->
        new_state = update_state(state, station)
        {:reply, format_next_train(next_train), new_state}
      _ ->
        {:reply, :error, state}
    end
  end

  ## Helper Functions
  def station_info_of(station_code) do
    url_for(station_code)
    |> HTTPoison.get(api_key(), ssl_option())
    |> parse_response
  end

  defp url_for(station_code) do
    station_code = URI.encode(station_code)
    "https://api.wmata.com/StationPrediction.svc/json/GetPrediction/#{station_code}"
  end

  defp parse_response({:ok, %HTTPoison.Response{body: body, status_code: 200}}) do
    body |> JSON.decode! |> get_next_train
  end

  defp parse_response(_) do
    :error
  end

  defp get_next_train(json) do
    try do
      next_train = json["Trains"] |> List.first
      {:ok, next_train}
    rescue
      _ -> :error
    end
  end

  defp api_key do
    [{"api_key", "4f3b58f7cca542ec97c1221da5a60fd0"}]
  end

  defp ssl_option do
    [ssl: [versions: [:"tlsv1.2"]]]
  end

  defp update_state(old_state, station) do
    case Map.has_key?(old_state, station) do
      true ->
        Map.update!(old_state, station, &(&1 + 1))
      false ->
        Map.put_new(old_state, station, 1)
    end
  end

  defp format_next_train(next_train) do
    "The next train from #{next_train["LocationName"]} boards in #{next_train["Min"]} mins, headed to #{next_train["Destination"]}"
  end
end
