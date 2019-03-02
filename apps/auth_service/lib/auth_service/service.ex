defmodule AuthService.Service do
  @moduledoc """
  This service manage authentification and session.
  """

  use ElvenGard.Services.GenericService

  @doc """
  Init state
  """
  def handle_init(), do: {:ok, []}

  @doc """
  Return an account id if credentials match
  """
  def handle_call({:get_account_id, username, password}, _from) do
    # TODO: Call a Database (maybe Mnesia ?)
    if username == "admin" and password == "admin" do
      {:ok, 42}
    else
      {:error, nil}
    end
  end

  @doc """
  Register a new session
  """
  def handle_call({:create_session, username, password}, _from, state) do
    session_id = :rand.uniform(35635)

    data = %{
      username: username,
      password: password,
      session_id: session_id,
      created_at: System.system_time()
    }

    new_state = [data | state]
    {:reply, {:ok, session_id}, new_state}
  end
end
