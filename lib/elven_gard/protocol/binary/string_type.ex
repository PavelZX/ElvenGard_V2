defmodule ElvenGard.Protocol.Binary.StringType do
  @moduledoc """
  Define a custom string type (utf8) for game protocols
  """

  use ElvenGard.Type

  alias ElvenGard.TypeOptionError

  @impl ElvenGard.Type
  @spec encode(String.t(), list) :: bitstring
  def encode(str, _opts) do
    <<str::binary>>
  end

  @impl ElvenGard.Type
  @spec decode(bitstring, list) :: {String.t(), bitstring}
  def decode(bin, opts) do
    bits = Keyword.get(opts, :bits)
    bytes = Keyword.get(opts, :bytes)

    if bits == nil and bytes == nil do
      raise TypeOptionError, "you must specify a size in bytes/bits for a string"
    end

    size = if bits != nil, do: Kernel.trunc(bits / 8), else: bytes

    <<
      str::binary-size(size),
      rest::binary
    >> = bin

    {str, rest}
  end
end
