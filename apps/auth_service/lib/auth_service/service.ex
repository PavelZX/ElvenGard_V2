defmodule AuthService.Service do
  @moduledoc """
  This service manage authentification and session.
  """

  use ElvenGard.Services.GenericService

  @doc """
  Return an account id if credentials match
  """
  def handle_call({:get_account_id, username, password}, _from, state) do
    # TODO: Call a Database (maybe Mnesia ?)
    if username == "admin" and password == "admin" do
      {:reply, {:ok, 42}, state}
    else
      {:reply, {:error, nil}, state}
    end
  end
end
