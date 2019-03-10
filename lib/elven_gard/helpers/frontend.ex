defmodule ElvenGard.Helpers.Frontend do
  @moduledoc """
  TODO: Documentation for ElvenGard.Helpers.Frontend
  """

  alias ElvenGard.Structures.Client

  @type conn_error :: atom | binary | bitstring
  @type handle_ok :: {:ok, Client.t()}
  @type handle_error :: {:error, term, Client.t()}
  @type handle_return :: handle_ok | handle_error
  @type state :: Client.t()

  @callback handle_init(args :: list) :: {:ok, term} | {:error, term}
  @callback handle_connection(socket :: identifier, transport :: atom) :: handle_return
  @callback handle_disconnection(client :: Client.t(), reason :: term) :: handle_return
  @callback handle_message(client :: Client.t(), message :: binary) :: handle_return
  @callback handle_error(client :: Client.t(), error :: conn_error) :: handle_return
  @callback handle_halt_ok(client :: Client.t(), args :: term) :: handle_return
  @callback handle_halt_error(client :: Client.t(), error :: conn_error) :: handle_return

  @doc false
  defmacro __using__(opts) do
    parent = __MODULE__
    caller = __CALLER__.module
    port = Keyword.get(opts, :port, 3000)
    encoder = Keyword.get(opts, :packet_encoder)
    handler = Keyword.get(opts, :packet_handler)
    final_opts = Keyword.put(opts, :port, port)

    # Check is there is any encoder
    unless encoder do
      raise "Please, specify a packet_encoder for #{caller}"
    end

    # Check is there is any handler
    unless handler do
      raise "Please, specify a packet_handler for #{caller}"
    end

    quote do
      use GenServer

      alias ElvenGard.Helpers.FrontendProtocol
      alias ElvenGard.Structures.Client

      @behaviour unquote(parent)

      @doc false
      def start_link(args) do
        GenServer.start_link(__MODULE__, unquote(final_opts), name: __MODULE__)
      end

      @doc false
      @impl true
      def init(opts) do
        ranch_opts = [port: Keyword.get(opts, :port, 3000)]

        # TODO: Use `protocol_opts` later for ranch options
        # cf. https://ninenines.eu/docs/en/ranch/1.7/manual/ranch.'start_listener'/
        {:ok, _protocol_opts} = handle_init(opts)

        {:ok, pid} =
          :ranch.start_listener(
            __MODULE__,
            :ranch_tcp,
            ranch_opts,
            __MODULE__,
            opts
          )
      end

      unquote(protocol_implementation(final_opts))
      unquote(default_implementations())
    end
  end

  @doc false
  @spec protocol_implementation(list) :: term
  defp protocol_implementation(opts) do
    quote do
      unquote(protocol_prelude(opts))
      unquote(protocol_handlers(opts))
      unquote(protocol_ending(opts))
    end
  end

  @doc false
  @spec protocol_prelude(list) :: term
  defp protocol_prelude(opts) do
    encoder = Keyword.get(opts, :packet_encoder)

    quote do
      @doc false
      def start_link(ref, socket, transport, _protocol_options) do
        opts = [
          ref,
          socket,
          transport
        ]

        pid = :proc_lib.spawn_link(__MODULE__, :init, opts)
        {:ok, pid}
      end

      @doc false
      def init(ref, socket, transport) do
        with :ok <- :ranch.accept_ack(ref),
             :ok = transport.setopts(socket, [{:active, true}]),
             {:ok, client} <- handle_connection(socket, transport) do
          final_client = %Client{client | encoder: unquote(encoder)}
          :gen_server.enter_loop(__MODULE__, [], final_client, 10_000)
        end
      end
    end
  end

  @doc false
  @spec protocol_handlers(list) :: term
  defp protocol_handlers(opts) do
    encoder = Keyword.get(opts, :packet_encoder)
    handler = Keyword.get(opts, :packet_handler)

    quote do
      @impl true
      def handle_info({:tcp, socket, data}, %Client{} = client) do
        # TODO: Manage errors on `handle_message`: don't execute the encoder
        {:ok, tmp_state} = handle_message(client, data)

        payload = unquote(encoder).complete_decode(data, tmp_state)

        case do_handle_packet(payload, tmp_state) do
          {:cont, final_client} ->
            {:noreply, final_client}

          {:halt, {:ok, args}, final_client} ->
            do_halt_ok(final_client, args)

          {:halt, {:error, reason}, final_client} ->
            do_halt_error(final_client, reason)

          x ->
            raise """
            #{unquote(handler)}.handle_packet/2 have to return `{:cont, client}`, \
            `{:halt, {:ok, :some_args}, client}`, or `{:halt, {:error, reason}, client} `. \
            Returned: #{inspect(x)}
            """
        end
      end

      @impl true
      def handle_info({:tcp_closed, _socket}, %Client{} = client) do
        {:ok, new_state} = handle_disconnection(client, :normal)
        {:stop, :normal, new_state}
      end

      @impl true
      def handle_info({:tcp_error, _socket, reason}, %Client{} = client) do
        {:ok, new_state} = handle_error(client, reason)
        {:stop, reason, new_state}
      end

      @impl true
      def handle_info(:timeout, %Client{} = client) do
        {:ok, new_state} = handle_error(client, :timeout)
        {:stop, :normal, new_state}
      end
    end
  end

  @doc false
  @spec protocol_ending(list) :: term
  defp protocol_ending(opts) do
    handler = Keyword.get(opts, :packet_handler)

    quote do
      @spec do_handle_packet(list | list(list), Client.t()) ::
              {:cont, __MODULE__.state()}
              | {:halt, {:ok, term}, __MODULE__.state()}
              | {:halt, {:error, __MODULE__.conn_error()}, __MODULE__.state()}
      defp do_handle_packet([[_header | _params] | _rest] = packet_list, client) do
        Enum.reduce_while(packet_list, {:cont, client}, fn packet, {_, client} ->
          res = do_handle_packet(packet, client)
          {elem(res, 0), res}
        end)
      end

      defp do_handle_packet([_header | _params] = packet, client) do
        unquote(handler).handle_packet(packet, client)
      end

      defp do_handle_packet(x, _client) do
        raise """
        Unable to handle packet #{inspect(x)}.
        Please check that your decoder returns a list in the form of [header, \
        param1, param2, ...]
        """
      end

      @spec do_halt_ok(Client.t(), term) :: {:stop, :normal, Client.t()}
      defp do_halt_ok(%Client{} = client, args) do
        final_client =
          client
          |> handle_halt_ok(args)
          |> close_socket(:normal)

        {:stop, :normal, final_client}
      end

      @spec do_halt_error(Client.t(), term) :: {:stop, :normal, Client.t()}
      defp do_halt_error(%Client{} = client, reason) do
        final_client =
          client
          |> handle_halt_error(reason)
          |> close_socket(reason)

        {:stop, :normal, final_client}
      end

      @spec close_socket(__MODULE__.handle_return(), term) :: Client.t()
      defp close_socket({:ok, %Client{} = client}, reason), do: do_close_socket(client, reason)

      defp close_socket({:error, _, %Client{} = client}, reason),
        do: do_close_socket(client, reason)

      @spec do_close_socket(Client.t(), term) :: Client.t()
      defp do_close_socket(%Client{} = client, reason) do
        %Client{
          socket: socket,
          transport: transport
        } = client

        {:ok, final_client} = handle_disconnection(client, reason)
        transport.close(socket)
        final_client
      end
    end
  end

  @doc false
  @spec default_implementations() :: term
  defp default_implementations() do
    quote do
      def handle_init(_args), do: {:ok, nil}
      def handle_connection(socket, transport), do: Client.new(socket, transport)
      def handle_disconnection(client, _reason), do: client
      def handle_message(client, _message), do: client
      def handle_error(client, _reason), do: client
      def handle_halt_ok(client, _args), do: client
      def handle_halt_error(client, _reason), do: client

      defoverridable handle_init: 1,
                     handle_connection: 2,
                     handle_disconnection: 2,
                     handle_message: 2,
                     handle_error: 2,
                     handle_halt_ok: 2,
                     handle_halt_error: 2
    end
  end
end
