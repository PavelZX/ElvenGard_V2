defmodule ElvenGard.Services.GenericService do
  @moduledoc """
  TODO: Documentation for ElvenGard.Services.GenericService
  """

  alias ElvenGard.Service

  @callback handle_init() :: {:ok, term} | {:error, term}

  @doc false
  defmacro __using__(opts) do
    parent = __MODULE__
    default_name = Service.default_name(__CALLER__.module)
    name = Keyword.get(opts, :name, default_name)

    quote do
      use GenServer

      @behaviour unquote(parent)
      @before_compile unquote(parent)

      #
      # GenServer implementation
      #

      @doc false
      def start_link(opts) do
        process_name = :"#{unquote(name)}_#{inspect(make_ref())}"
        {:ok, _pid} = GenServer.start_link(__MODULE__, nil, name: process_name)
      end

      @doc false
      def init(_) do
        :pg2.create(unquote(name))
        :ok = :pg2.join(unquote(name), self())
        handle_init()
      end

      #
      # Default implementations
      #

      @doc false
      def handle_init(), do: {:ok, nil}

      defoverridable handle_init: 0

      #
      # Debugging features: remove it
      #

      @doc """
      Debugging purpose.

      TODO: Remove this function
      """
      def get_states() do
        unquote(name)
        |> :pg2.get_members()
        |> Enum.map(&GenServer.call(&1, :get_state))
      end

      def handle_call(:get_state, _from, state) do
        {:reply, state, state}
      end
    end
  end

  @doc false
  defmacro __before_compile__(_env) do
    quote do
      @doc false
      def handle_call(request, from, state) do
        {:reply, handle_call(request, from), state}
      end
    end
  end
end
