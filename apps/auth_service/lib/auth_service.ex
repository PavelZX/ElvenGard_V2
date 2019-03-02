defmodule AuthService do
  @moduledoc """
  Documentation for AuthService.
  """

  use Application

  def start(_type, _args) do
    # List all child processes to be supervised
    children = [
      Supervisor.child_spec({AuthService.Service, []}, id: make_ref()),
      Supervisor.child_spec({AuthService.Service, []}, id: make_ref()),
      Supervisor.child_spec({AuthService.Service, []}, id: make_ref())
    ]

    opts = [strategy: :one_for_one, name: AuthService.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
