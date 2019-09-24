defmodule ElvenGard.Protocol.Textual do
  @moduledoc """
  TODO: Documentation for ElvenGard.Protocol.Textual
  """

  alias ElvenGard.FieldTypeError
  alias ElvenGard.Protocol
  alias ElvenGard.Structures.{Client, PacketDefinition}

  @aliases [
    integer: ElvenGard.Protocol.Textual.IntegerType,
    float: ElvenGard.Protocol.Textual.FloatType,
    string: ElvenGard.Protocol.Textual.StringType
  ]

  @doc """

  """
  @callback textual_decode(data :: binary, client :: Client.t()) ::
              String.t()
              | [String.t(), ...]
              | {Protocol.packet_header(), String.t()}
              | [{Protocol.packet_header(), String.t()}, ...]

  @doc false
  defmacro __using__(model: model, separator: separator) do
    parent = __MODULE__
    expanded_model = Macro.expand(model, __CALLER__)
    defs = expanded_model.fetch_definitions()

    check_types!(defs)

    quote do
      @behaviour unquote(parent)

      use ElvenGard.Protocol

      require Logger

      @impl true
      def aliases() do
        unquote(@aliases)
      end

      ## Principal decoder
      @impl true
      def decode(data, %Client{} = client) do
        data
        |> textual_decode(client)
        |> post_textual_decode()
      end

      @doc false
      @spec post_textual_decode(
              String.t()
              | [String.t(), ...]
              | {Protocol.packet_header(), String.t()}
              | [{Protocol.packet_header(), String.t()}, ...]
            ) ::
              {Protocol.packet_header(), map} | [{Protocol.packet_header(), map}, ...]
      defp post_textual_decode(x) when is_tuple(x), do: final_decode(x)
      defp post_textual_decode([x | _] = y) when is_tuple(x), do: Enum.map(y, &final_decode/1)

      defp post_textual_decode(x) when is_binary(x),
        do: x |> normalize_args() |> post_textual_decode()

      defp post_textual_decode([x | _] = y) when is_binary(x),
        do: y |> Enum.map(&normalize_args/1) |> post_textual_decode()

      ## Define sub decoders
      Enum.each(unquote(model).fetch_definitions(), fn packet ->
        name = packet.name
        fields = Macro.escape(packet.fields)
        sep = unquote(separator) |> Macro.escape()

        Module.eval_quoted(
          __MODULE__,
          quote do
            defp final_decode({unquote(name), params}) do
              sp_params = String.split(params, unquote(sep))

              # TODO: Maybe check if len(sp_params) == len(fields)

              data = Enum.zip(sp_params, unquote(fields))
              args = parse_args(data, %{})
              {unquote(name), args}
            end
          end
        )
      end)

      ## Default sub decoder
      defp final_decode({name, params}) do
        m = unquote(model)

        Logger.debug(fn ->
          "Can't decode packet with header #{name}: not defined in model #{m}"
        end)

        {name, params}
      end

      @doc false
      @spec normalize_args(String.t()) :: {Protocol.packet_header(), String.t()}
      defp normalize_args(str) do
        # Detaches the packet header from parameters
        case String.split(str, unquote(separator), parts: 2) do
          [header] -> {header, ""}
          val -> List.to_tuple(val)
        end
      end

      @doc false
      @spec parse_args(list({String.t(), FieldDefinition.t()}), map) :: map
      defp parse_args([], params), do: params

      defp parse_args([{data, field} | tail], params) do
        %{
          name: name,
          type: type,
          opts: opts
        } = field

        real_type = Keyword.get(unquote(@aliases), type, type)

        val = real_type.decode(data, opts)
        parse_args(tail, Map.put(params, name, val))
      end
    end
  end

  #
  # Privates functions
  #

  @doc false
  @spec check_types!([PacketDefinition.t()]) :: :ok
  defp check_types!(defs) do
    for def <- defs, field <- def.fields do
      name = field.name
      type = field.type
      real_type = Keyword.get(@aliases, type, type)

      check_type!(real_type, name, def.name)
    end

    :ok
  end

  @doc false
  @spec check_type!(atom, atom, term) :: term
  defp check_type!(type, name, def_name) do
    unless Keyword.has_key?(type.__info__(:functions), :decode) do
      raise FieldTypeError, field_type: type, field_name: name, packet_name: def_name
    end
  end
end
