defmodule LoginServer.Views.AuthView do
  @moduledoc """
  Define all views for a the login

  # TODO: Create an "abstract module" for define defaults renders
  """

  def render(:server_list, params) do
    %{
      :session_id => session_id,
      :server_list => server_list
    } = params

    "NsTeST #{session_id} #{server_list}"
  end
end
