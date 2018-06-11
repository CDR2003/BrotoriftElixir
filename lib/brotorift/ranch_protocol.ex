defmodule Brotorift.RanchProtocol do
  @behaviour :ranch_protocol

  def start_link(ref, socket, transport, {mod, handler}) do
    pid = spawn_link(__MODULE__, :init, [{ref, socket, transport, mod, handler}])
    {:ok, pid}
  end

  def init({ref, socket, transport, mod, handler}) do
    #IO.puts("Starting protocol")

    :ok = :ranch.accept_ack(ref)
    :ok = transport.setopts(socket, [active: :false])
    {:ok, connection} = Brotorift.ConnectionSupervisor.start_connection(mod, handler, socket, transport)

    loop(socket, transport, mod, connection)
  end

  defp loop(socket, transport, mod, connection) do
    case transport.recv(socket, 4, :infinity) do
      {:ok, size_data} ->
        <<size::little-32>> = size_data
        case transport.recv(socket, size, :infinity) do
          {:ok, data} ->
            mod.handle_data(connection, data)
            loop(socket, transport, mod, connection)
          {:error, :closed} ->
            mod.stop(connection)
            transport.close(socket)
          _ ->
            mod.stop(connection)
            transport.close(socket)
        end
      {:error, :closed} ->
        mod.stop(connection)
        transport.close(socket)
      _ ->
        mod.stop(connection)
        transport.close(socket)
    end
  end
end
