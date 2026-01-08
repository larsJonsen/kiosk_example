defmodule DoseSupervisor do
  use Supervisor

  def start_link(args \\ []) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  def stop() do
    Supervisor.stop(__MODULE__)
  end

  @impl Supervisor
  def init(_args) do
   Supervisor.init(children(), strategy: :one_for_one)
  end


  defp children() do
    [
      %{
        id: Dosing,
        start: {Dosing, :start_link, [ ]}
      },
      %{
        id: Valve,
        start: {Valve, :start_link, [ ]}
      },
      %{
        id: Scale,
        start: {Scale, :start_link,
        [ %{pubsub: KioskExample.PubSub, sensor: [:sensor_1]}]}
      },
      %{
        id: LoadSensor_1,
        start: {Proxy, :start_link,
          [ %{
              addo_pin: 17,
              adsk_pin: 22,
              scale: -102.2123125,
              offset: 8_303_686.6875,
              name: :sensor_1,
              mother: Scale
            }
          ]}
        }
    ]
  end
end