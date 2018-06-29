defmodule Brotorift.RanchProtocol do
  @behaviour :ranch_protocol

  @cs_packet_data 1
  @cs_packet_client_version 2

  # @sc_packet_data 128
  @sc_packet_wrong_version 129

  def start_link(ref, socket, transport, {mod, handler, data_head}) do
    pid = spawn_link(__MODULE__, :init, [{ref, socket, transport, mod, handler, data_head}])
    {:ok, pid}
  end

  def init({ref, socket, transport, mod, handler, data_head}) do
    :ok = :ranch.accept_ack(ref)
    :ok = transport.setopts(socket, active: false)

    {:ok, connection} =
      Brotorift.ConnectionSupervisor.start_connection(mod, handler, socket, transport)

    loop(socket, transport, mod, data_head, connection, false)
  end

  defp loop(socket, transport, mod, data_head, connection, version_checked) do
    with {:ok, <<^data_head::64-little-signed>>} <- transport.recv(socket, 8, :infinity),
         {:ok, <<packet_type::8>>} <- transport.recv(socket, 1, :infinity) do
      read_packet(packet_type, socket, transport, mod, data_head, connection, version_checked)
    else
      _ ->
        close(socket, transport, mod, connection)
    end
  end

  defp read_packet(@cs_packet_client_version, socket, transport, mod, data_head, connection, _version_checked) do
    with {:ok, <<client_version::32-little-signed>>} <- transport.recv(socket, 4, :infinity) do
      server_version = mod.version()
      if client_version != server_version do
        reply = <<data_head::64-little-signed, @sc_packet_wrong_version::8, client_version::32-little-signed, server_version::32-little-signed>>
        transport.send(socket, reply)
        close(socket, transport, mod, connection)
      else
        loop(socket, transport, mod, data_head, connection, true)
      end
    else
      _ ->
        close(socket, transport, mod, connection)
    end
  end

  defp read_packet(@cs_packet_data, socket, transport, mod, _data_head, connection, false) do
    close(socket, transport, mod, connection)
  end
  defp read_packet(@cs_packet_data, socket, transport, mod, data_head, connection, true) do
    with {:ok, <<size::little-32>>} <- transport.recv(socket, 4, :infinity),
         {:ok, data} <- transport.recv(socket, size, :infinity) do
      mod.handle_data(connection, data)
      loop(socket, transport, mod, data_head, connection, true)
    else
      _ ->
        close(socket, transport, mod, connection)
    end
  end

  defp read_packet(_packet_type, socket, transport, mod, _data_head, connection, _version_checked) do
    close(socket, transport, mod, connection)
  end

  def close(socket, transport, mod, connection) do
    mod.stop(connection)
    transport.close(socket)
  end
end
