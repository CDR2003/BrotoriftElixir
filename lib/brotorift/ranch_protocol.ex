defmodule Brotorift.RanchProtocol do
  use GenServer

  @behaviour :ranch_protocol

  def start_link(ref, socket, transport, {mod, handler}) do
    pid = :proc_lib.spawn_link(__MODULE__, :init, [{ref, socket, transport, mod, handler}])
    {:ok, pid}
  end

  def init({ref, socket, transport, mod, handler}) do
    #IO.puts("Starting protocol")

    :ok = :ranch.accept_ack(ref)
    :ok = transport.setopts(socket, [{:active, :once}])
    {:ok, connection} = Brotorift.ConnectionSupervisor.start_connection(mod, handler, socket, transport)
    :gen_server.enter_loop(__MODULE__, [], {socket, transport, mod, connection})

    loop(socket, transport, mod, connection)
  end

  defp loop(socket, transport, mod, connection) do
    {:ok, size} = transport.recv(socket, 4, 5000)
    case transport.recv(socket, size, 5000) do
      {:ok, data} ->
        transport.send(socket, data)
        mod.handle_data(connection, data)
      _ ->
        :ok = transport.close(socket)
    end
  end

  # def handle_info({:tcp, socket, data}, {socket, transport, mod, connection}) do
  #   transport.send(socket, data)
  #   mod.handle_data(connection, data)
  #   {:noreply, {socket, transport, mod, connection}}
  # end

  def handle_info({:tcp_closed, socket}, {socket, transport, mod, connection}) do
    mod.stop(connection)
    transport.close(socket)
    {:stop, :normal, {socket, transport, mod, connection}}
  end
end
