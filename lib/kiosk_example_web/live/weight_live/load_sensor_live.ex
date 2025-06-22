defmodule KioskExampleWeb.LoadSensorLive do
  use KioskExampleWeb, :live_view
  
  def mount(_params, _session, socket) do
    # Subscribe to sensor updates
    if connected?(socket) do
      Phoenix.PubSub.subscribe(:my_pubsub, "scale")
    end
    
    # Get initial value
    initial_value = LoadSensorServer.get_current_value()
    {:ok, socket
          |>assign(:load_value, initial_value)
          |>assign(:ctrl_down, false)}
  end
  
  def handle_info({:load_updated, new_value}, socket) do
    {:noreply, assign(socket, :load_value, new_value)}
  end

  def handle_event("tare", _value, socket) do
  LoadSensorServer.tare()
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


  def render(assigns) do
    ~H"""
    <div class="load-sensor-display" phx-window-keydown="keydown" phx-window-keyup="keyup">
      <h2>Load Sensor Reading</h2>
      <div class="sensor-value">
        <p style="font-size:15em; ">
        <%= @load_value %>
      </p>
      <.button phx-click="tare">  Tare (Ctrl+T)   </.button>
      </div>
    </div>
    """
  end
end