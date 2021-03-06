defmodule Brotorift.ConnectionSupervisor do
  use DynamicSupervisor

  def start_link(args) do
    DynamicSupervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  def start_connection(mod, handler, socket, transport) do
    DynamicSupervisor.start_child(__MODULE__, {mod, {socket, transport, handler}})
  end

  def init(_args) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
