defmodule LoginServer.Interfaces do
  @moduledoc """
  Documentation for LoginServer.Interfaces.
  """

  alias ElvenGard.Service

  @doc """
  Get an Account id from a username and a password
  """
  @spec get_account_id(String.t(), String.t()) :: Service.call_return()
  def get_account_id(username, password) do
    Service.random_call(:auth_service, {:get_account_id, username, password})
  end

  @doc """
  Create a session id
  """
  @spec create_session(String.t(), String.t()) :: Service.call_return()
  def create_session(username, password) do
    Service.random_call(:auth_service, {:create_session, username, password})
  end
end
