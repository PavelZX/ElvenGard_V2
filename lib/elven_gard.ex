defmodule ElvenGard do
  @moduledoc """
  Documentation for ElvenGard.
  """

  use Application

  def start(_type, _args) do
    # List all child processes to be supervised
    children = [
      {ElvenGard.Registry, []}
    ]

    opts = [strategy: :one_for_one, name: ElvenGard.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
