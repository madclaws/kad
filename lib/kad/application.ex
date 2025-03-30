defmodule Kad.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {DynamicSupervisor, name: Kad.DynamicSupervisor, strategy: :one_for_one}
    ]

    opts = [strategy: :one_for_one, name: Kad.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
