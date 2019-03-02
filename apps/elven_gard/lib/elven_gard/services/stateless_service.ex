defmodule ElvenGard.Services.StatelessService do
  @moduledoc """
  TODO: Documentation for ElvenGard.Services.StatelessService
  """

  alias ElvenGard.Service

  @doc false
  defmacro __using__(opts) do
    default_name = Service.default_name(__CALLER__.module)
    name = Keyword.get(opts, :name, default_name)

    quote do
      use GenServer

      @doc """
      Starts the Service
      """
      def start_link(opts) do
        process_name = :"#{unquote(name)}_#{inspect(make_ref())}"
        {:ok, _pid} = GenServer.start_link(__MODULE__, nil, name: process_name)
      end

      def init(_) do
        :pg2.create(unquote(name))
        :ok = :pg2.join(unquote(name), self())
        {:ok, nil}
      end
    end
  end
end
