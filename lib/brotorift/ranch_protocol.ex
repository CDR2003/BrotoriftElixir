defmodule Brotorift.RanchProtocol do
  @behaviour :ranch_protocol

  def start_link(ref, socket, transport, {mod, handler, data_head}) do
    pid = spawn_link(__MODULE__, :init, [{ref, socket, transport, mod, handler, data_head}])
    {:ok, pid}
  end

  def init({ref, socket, transport, mod, handler, data_head}) do
    #IO.puts("Starting protocol")

    :ok = :ranch.accept_ack(ref)
    :ok = transport.setopts(socket, [active: :false])
    {:ok, connection} = Brotorift.ConnectionSupervisor.start_connection(mod, handler, socket, transport)

    loop(socket, transport, mod, data_head, connection)
  end

  defp loop(socket, transport, mod, data_head, connection) do
    case transport.recv(socket, 8, :infinity) do
      {:ok, header_data} ->
        <<header_content::64-little-signed>> = header_data
        if header_content == data_head do
          case transport.recv(socket, 4, :infinity) do
            {:ok, size_data} ->
              <<size::little-32>> = size_data
              case transport.recv(socket, size, :infinity) do
                {:ok, data} ->
                  mod.handle_data(connection, data)
                  loop(socket, transport, mod, data_head, connection)
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
        else
          mod.stop(connection)
          transport.close(socket)
        end
      _ ->
        mod.stop(connection)
        transport.close(socket)
    end
  end
end
