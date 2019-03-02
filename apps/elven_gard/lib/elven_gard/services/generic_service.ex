defmodule ElvenGard.Services.GenericService do
  @moduledoc """
  TODO: Documentation for ElvenGard.Services.GenericService
  """

  alias ElvenGard.Service
  alias ElvenGard.Services.{StatefullService, StatelessService}

  @doc false
  defmacro __using__(opts) do
    default_name = Service.default_name(__CALLER__.module)
    name = Keyword.get(opts, :name, default_name)

    # `:stateless` or `:statefull`
    state_type = Keyword.get(opts, :state_type, :stateless)
    # `:unique` or `:shared` (only if statefull)
    state_mode = Keyword.get(opts, :state_mode, :unique)

    apply(__MODULE__, state_type, [name, state_mode])
  end

  @doc false
  def stateless(name, _) do
    quote do
      use StatelessService, name: unquote(name)
    end
  end

  @doc false
  def statefull(name, state_mode) do
    quote do
      use StatefullService,
        name: unquote(name),
        state_mode: unquote(state_mode)
    end
  end
end
