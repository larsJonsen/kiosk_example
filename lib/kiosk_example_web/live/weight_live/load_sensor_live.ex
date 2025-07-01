defmodule KioskExampleWeb.LoadSensorLive do
  use KioskExampleWeb, :live_view

  import KioskExampleWeb.Components.Button

  
  def mount(_params, _session, socket) do
    # Subscribe to sensor updates
    if connected?(socket) do
      Phoenix.PubSub.subscribe(:my_pubsub, "scale")
      Phoenix.PubSub.subscribe(:my_pubsub, "dose")
    end
    
    # Get initial value
    initial_value = LoadSensorServer.get_current_value()
    {:ok, socket
          |>assign(:load_value, initial_value)
          |>assign(:stable, false)
          |>assign(:ss, 0.0)
          |>assign(:status, :start)
          |>assign(:net_weight, 0.0)
          |>assign(:ctrl_down, false)}
  end
  
  def handle_info({:load_updated, %{value: new_value, stable: stable, ss: ss}}, socket) do
    {:noreply, assign(socket, [load_value: new_value, stable: stable, ss: ss])}
  end

  def handle_info({:dose, %{status: status, net_weight: net_weight}}, socket) do 
    #IO.inspect(status, label: "Status")
    {:noreply, assign(socket, [status: status, net_weight: net_weight])}
  end

  def handle_event("tare", _value, socket) do
    LoadSensorServer.tare()
    {:noreply, socket}
  end

  def handle_event("dose", _value, socket) do
    DosingServer.start_dosing(:dose, 3)
    {:noreply, socket}
  end

  def handle_event("stop", _value, socket) do
    DosingServer.stop_dosing(:dose)
    {:noreply, socket}
  end

  def handle_event("keydown", %{"key" => "Control"}, socket) do
    {:noreply, assign(socket, :ctrl_down, true)}
  end
    
  def handle_event("keydown", %{"key" => "t"}, socket) do
    if socket.assigns.ctrl_down do  # Same logic as the tare button
    LoadSensorServer.tare()
    end
    {:noreply, socket}
  end

  def handle_event("keydown", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("keyup", %{"key" => "Control"}, socket) do
    {:noreply, assign(socket, :ctrl_down, false)}
  end

  def handle_event("keyup", _params, socket) do
      {:noreply, socket}
  end

  def my_round(x,n) do
   x |> Decimal.from_float |> Decimal.round(n)
  end

  #   <.button variant="default" color="danger"> {@ss}  <./button>

  def render(assigns) do
    ~H"""
    <div class="load-sensor-display" phx-window-keydown="keydown" phx-window-keyup="keyup">
      <h2>Load Sensor Reading</h2>
  
      <div class="sensor-value">
        <p style="font-size:15em; ">
        <%= round(@load_value) %>
        </p>
        <.my_button variant="default" color="secondary" phx-click="tare">  Tare (Ctrl+T)  </.my_button>
       <.my_button :if={not @stable} variant="default" color="danger" >   {@ss}   </.my_button>
       <.my_button :if={@stable} variant="default" color="success" >   {@ss}  </.my_button>
        <p style="font-size:15em; ">
        <%= round(@net_weight) %>
        </p>
        <.my_button variant="default" color="success" phx-click="dose">  {@status}  </.my_button>
        <.my_button variant="default" color="danger" phx-click="stop">  Stop  </.my_button>
      </div>
    </div>
    """
  end
end