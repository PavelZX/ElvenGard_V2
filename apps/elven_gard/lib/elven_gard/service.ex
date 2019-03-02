defmodule ElvenGard.Service do
  @moduledoc """
  Documentation for ElvenGard.Service

  If more performance is needed for inter-node communication, see:
  https://github.com/discordapp/manifold
  """

  @type call_return :: {:ok, term} | {:error, term}

  @doc """
  Returns the default name for a service using a module name
  """
  @spec default_name(atom) :: atom
  def default_name(module) do
    module
    |> Module.split()
    |> Enum.at(0)
    |> Macro.underscore()
    |> String.to_atom()
  end

  @doc """
  Get the closest process registered on a group and `call` it
  """
  @spec call(atom, term) :: call_return
  def call(name, data) do
    name
    |> :pg2.get_closest_pid()
    |> GenServer.call(data)
  end

  @doc """
  Get the closest process registered on a group and `cast` it
  """
  @spec cast(atom, term) :: term
  def cast(name, data) do
    name
    |> :pg2.get_closest_pid()
    |> GenServer.cast(data)
  end

  @doc """
  Pick a random process registered on a group and `call` it
  """
  @spec random_call(atom, term) :: call_return
  def random_call(name, data) do
    name
    |> :pg2.get_members()
    |> Enum.random()
    |> GenServer.call(data)
  end

  @doc """
  Pick a random process registered on a group and `cast` it
  """
  @spec random_cast(atom, term) :: term
  def random_cast(name, data) do
    name
    |> :pg2.get_members()
    |> Enum.random()
    |> GenServer.cast(data)
  end
end
