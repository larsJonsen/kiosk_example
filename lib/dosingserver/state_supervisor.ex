defmodule StateSupervisor do
  use Supervisor

  def start_link(args \\ []) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  def stop() do
    Supervisor.stop(__MODULE__)
  end

  @impl Supervisor
  def init(_args) do
   Supervisor.init(children(), strategy: :rest_for_one)
  end

  defp children() do
    [
      %{
        id: State,
        start: {State, :start_link, [ ]}
      }
    ]
  end

  def start_dose do
    Supervisor.child_spec(__MODULE__,%{
       id: DoseSupervisor,
       start: {DoseSupervisor, :start_link, [ ]}
     })
    with {:ok, pid} <- Supervisor.start_child(__MODULE__,DoseSupervisor) do
      {:ok, pid} 
      else
        {:error, :already_present} ->
          Supervisor.restart_child(__MODULE__,DoseSupervisor)
        {:error, reason} ->
         {:error, reason} 
    end
  end

  def stop_dose do
    Supervisor.terminate_child(__MODULE__,DoseSupervisor)
  end




end