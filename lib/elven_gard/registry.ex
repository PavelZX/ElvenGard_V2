defmodule ElvenGard.Registry do
  @moduledoc false

  use GenServer

  #
  # GenServer implementation
  #

  @doc false
  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc false
  @impl true
  def init(:ok) do
    :mnesia.start()
    {:ok, nil}
  end
end
