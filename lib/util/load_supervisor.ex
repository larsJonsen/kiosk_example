defmodule LoadSupervisor do

  use Supervisor

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl Supervisor
  def init(_args) do
    children = [
      {Phoenix.PubSub,  name: :my_pubsub},
     %{
        id: LoadSensor,
        start: {HX712Server, :start_link, [[addo_pin: 17, adsk_pin: 22, 
        scale: -102.2123125, offset: 8303686.6875, name: :sensor_1]]}
      },
      %{
        id: Scale,
        start: {LoadSensorServer, :start_link, [[pubsub: :my_pubsub, sensor: [:sensor_1]]]}
      }
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end

end

