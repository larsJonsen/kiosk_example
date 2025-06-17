defmodule KioskExampleWeb.LoadSensorLive do
  use KioskExampleWeb, :live_view
  
  def mount(_params, _session, socket) do
    # Subscribe to sensor updates
    if connected?(socket) do
      Phoenix.PubSub.subscribe(:my_pubsub, "scale")
    end
    
    # Get initial value
    initial_value = LoadSensorServer.get_current_value()
    
    {:ok, assign(socket, :load_value, initial_value)}
  end
  
  def handle_info({:load_updated, new_value}, socket) do
    {:noreply, assign(socket, :load_value, new_value)}
  end
  
  def render(assigns) do
    ~H"""
    <div class="load-sensor-display">
      <h2>Load Sensor Reading</h2>
      <div class="sensor-value">
        <p style="font: size 2in;%;">
        <%= @load_value %>
      </p>
      </div>
    </div>
    """
  end
end