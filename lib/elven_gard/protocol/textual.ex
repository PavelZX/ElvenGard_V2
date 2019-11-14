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
  Same as c:ElvenGard.Protocol.encode/2
  """
  @callback textual_encode(data :: term, client :: Client.t()) :: binary

  @doc """
  Split a packet with the given delimitor and parse it
  """
  @callback textual_decode(data :: binary, client :: Client.t()) ::
              String.t()
              | [String.t(), ...]
              | {Protocol.packet_header(), String.t()}
              | [{Protocol.packet_header(), String.t()}, ...]

  @doc """
  Callback called when a decode fails

  The result of this function will be returned by the c:textual_decode/2 which failed
  """
  @callback handle_decode_fail(Protocol.packet_header(), map, atom) :: {:error, any}

  @doc false
  defmacro __using__(opts) do
    model = Keyword.fetch!(opts, :model)
    separator = Keyword.fetch!(opts, :separator)
    trim = Keyword.get(opts, :trim, true)

    parent = __MODULE__
    expanded_model = Macro.expand(model, __CALLER__)
    defs = expanded_model.fetch_definitions()

    check_types!(defs)

    quote do
      @behaviour unquote(parent)

      use ElvenGard.Protocol

      require Logger

      @before_compile unquote(parent)

      #
      # Protocol behaviour
      #

      @impl ElvenGard.Protocol
      def aliases() do
        unquote(@aliases)
      end

      @impl ElvenGard.Protocol
      def encode(data, %Client{} = client) do
        textual_encode(data, client)
      end

      @impl ElvenGard.Protocol
      def decode(data, %Client{} = client) do
        data
        |> textual_decode(client)
        |> post_textual_decode()
      end

      #
      # Protocol.Textual default behaviour
      #

      @impl unquote(__MODULE__)
      def handle_decode_fail(header, params, model) do
        hname = header |> inspect() |> String.trim("\"")

        Logger.debug(
          "Can't parse packet #{hname}/#{length(params)}: " <>
            "not defined in model #{inspect(model)}"
        )

        {:error, nil}
      end

      defoverridable handle_decode_fail: 3

      #
      # Generate parser for the textual protocol
      #

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

      defp post_textual_decode([]), do: []

      ## Define sub decoders

      Enum.each(unquote(model).fetch_definitions(), fn packet ->
        header = packet.name
        fields = Macro.escape(packet.fields)

        Module.eval_quoted(
          __MODULE__,
          quote do
            defp parse_packet_tuple({unquote(header), params})
                 when length(params) == length(unquote(fields)) do
              data = Enum.zip(params, unquote(fields))
              args = parse_args(data, %{})

              {unquote(header), args}
            end
          end
        )
      end)

      defp parse_packet_tuple({header, params}) do
        handle_decode_fail(header, params, unquote(model))
      end

      ## Helpers

      @doc false
      @spec final_decode({Protocol.packet_header(), [any, ...]}) :: any
      defp final_decode({header, params}) do
        sep = unquote(separator) |> Macro.escape()
        sep_params = String.split(params, sep, trim: unquote(trim))

        parse_packet_tuple({header, sep_params})
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

  @doc false
  defmacro __before_compile__(env) do
    unless Module.defines?(env.module, {:textual_encode, 2}) do
      raise """
      function textual_encode/2 required by behaviour #{inspect(__MODULE__)} is not implemented \
      (in module #{inspect(env.module)}).

      Example:
        @impl #{inspect(__MODULE__)}
        def textual_encode(data, _client), do: data
      """
    end

    unless Module.defines?(env.module, {:textual_decode, 2}) do
      raise """
      function textual_decode/2 required by behaviour #{inspect(__MODULE__)} is not implemented \
      (in module #{inspect(env.module)}).

      Example:
        @impl #{inspect(__MODULE__)}
        def textual_decode(data, _client) do
          String.split(data, "\\n", trim: true)
        end
      """
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
