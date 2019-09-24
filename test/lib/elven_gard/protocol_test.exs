defmodule ElvenGard.ProtocolTest do
  use ExUnit.Case

  describe "Protocol raise error if:" do
    test "encode/2 is not defined" do
      needle = ~r"function encode/2 required by behaviour"

      assert_raise RuntimeError, needle, fn ->
        defmodule ProtocolWithoutEncode do
          use ElvenGard.Protocol

          def decode(x, _c), do: x
        end
      end
    end

    test "decode/2 is not defined" do
      needle = ~r"function decode/2 required by behaviour"

      assert_raise RuntimeError, needle, fn ->
        defmodule ProtocolWithoutDecode do
          use ElvenGard.Protocol

          def encode(x, _c), do: x
        end
      end
    end
  end
end
