defmodule Brotorift.RanchProtocol do
  @behaviour :ranch_protocol

  @cs_packet_data 1
  @cs_packet_client_version 2
  @cs_heartbeat 3

  # @sc_packet_data 128
  @sc_packet_wrong_version 129
  @sc_heartbeat 130

  def start_link(ref, socket, transport, {mod, handler, data_head, hb_timeout}) do
    pid = spawn_link(__MODULE__, :init, [{ref, socket, transport, mod, handler, data_head, hb_timeout}])
    {:ok, pid}
  end

  def init({ref, socket, transport, mod, handler, data_head, hb_timeout}) do
    :ok = :ranch.accept_ack(ref)
    :ok = transport.setopts(socket, active: false, keepalive: true, send_timeout: 10000)

    {:ok, connection} =
      Brotorift.ConnectionSupervisor.start_connection(mod, handler, socket, transport)

    loop(socket, transport, mod, data_head, connection, hb_timeout, false)
  end

  defp loop(socket, transport, mod, data_head, connection, hb_timeout, version_checked) do
    with {:ok, <<^data_head::32-little-signed>>} <- transport.recv(socket, 4, hb_timeout),
         {:ok, <<packet_type::8>>} <- transport.recv(socket, 1, hb_timeout) do
      read_packet(packet_type, socket, transport, mod, data_head, connection, hb_timeout, version_checked)
    else
      _ ->
        close(socket, transport, mod, connection)
    end
  end

  defp read_packet(@cs_packet_client_version, socket, transport, mod, data_head, connection, hb_timeout, _version_checked) do
    with {:ok, <<client_version::32-little-signed>>} <- transport.recv(socket, 4, hb_timeout) do
      server_version = mod.version()
      if client_version != server_version do
        reply = <<@sc_packet_wrong_version::8, client_version::32-little-signed, server_version::32-little-signed>>
        transport.send(socket, reply)
        close(socket, transport, mod, connection)
      else
        loop(socket, transport, mod, data_head, connection, hb_timeout, true)
      end
    else
      _ ->
        close(socket, transport, mod, connection)
    end
  end
  defp read_packet(@cs_packet_data, socket, transport, mod, _data_head, connection, _hb_timeout, false) do
    close(socket, transport, mod, connection)
  end
  defp read_packet(@cs_packet_data, socket, transport, mod, data_head, connection, hb_timeout, true) do
    with {:ok, <<size::little-32>>} <- transport.recv(socket, 4, hb_timeout),
         {:ok, data} <- transport.recv(socket, size, hb_timeout) do
      mod.handle_data(connection, data)
      loop(socket, transport, mod, data_head, connection, hb_timeout, true)
    else
      _ ->
        close(socket, transport, mod, connection)
    end
  end
  defp read_packet(@cs_heartbeat, socket, transport, mod, data_head, connection, hb_timeout, true) do
    reply = <<@sc_heartbeat::8>>
    transport.send(socket, reply)
    loop(socket, transport, mod, data_head, connection, hb_timeout, true)
  end
  defp read_packet(_packet_type, socket, transport, mod, _data_head, connection, _hb_timeout, _version_checked) do
    close(socket, transport, mod, connection)
  end

  def close(socket, transport, mod, connection) do
    mod.stop(connection)
    transport.close(socket)
  end
end
