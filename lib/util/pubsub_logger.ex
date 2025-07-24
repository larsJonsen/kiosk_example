defmodule PubSubLogger do
  require Logger

  @doc """
  Subscribes to a PubSub topic and logs all messages to the console.
  
  ## Parameters
  - pubsub: The PubSub process name (e.g., MyApp.PubSub)
  - topic: The topic string to subscribe to
  - opts: Optional keyword list with:
    - :prefix - String to prefix log messages with (default: "PubSub")
    - :level - Logger level to use (default: :info)
  
  ## Examples
      iex> PubSubLogger.subscribe_and_log(MyApp.PubSub, "user_events")
      iex> PubSubLogger.subscribe_and_log(MyApp.PubSub, "notifications", prefix: "NOTIF", level: :debug)
  """
  def subscribe_and_log(pubsub, topic, opts \\ []) do
    prefix = Keyword.get(opts, :prefix, "PubSub")
    level = Keyword.get(opts, :level, :info)
    
    # Spawn a process that will subscribe and listen
    pid = spawn(fn -> 
      # Subscribe to the topic in the spawned process
      Phoenix.PubSub.subscribe(pubsub, topic)
      Logger.log(level, "#{prefix}: Subscribed to topic '#{topic}' (PID: #{inspect(self())})")
      message_loop(topic, prefix, level)
    end)
    
    {:ok, pid}
  end

  defp message_loop(topic, prefix, level) do
    receive do
      message ->
        Logger.log(level, "#{prefix} [#{topic}]: #{inspect(message)}")
        message_loop(topic, prefix, level)
    end
  end

  @doc """
  Stops a PubSub logger process.
  
  ## Parameters
  - pid: The process ID returned from subscribe_and_log/3
  
  ## Examples
      iex> {:ok, pid} = PubSubLogger.subscribe_and_log(MyApp.PubSub, "user_events")
      iex> PubSubLogger.stop(pid)
  """
  def stop(pid) do
    if Process.alive?(pid) do
      Process.exit(pid, :kill)
      Logger.info("PubSub logger stopped (PID: #{inspect(pid)})")
      :ok
    else
      Logger.warning("PubSub logger process #{inspect(pid)} is not alive")
      :not_alive
    end
  end
end

# Convenience function for quick usage in IEx
#defmodule IEx.Helpers do
#  def listen_to(pubsub, topic, opts \\ []) do
#    PubSubLogger.subscribe_and_log(pubsub, topic, opts)
#  end
#  
#  def stop_listener(pid) do
#    PubSubLogger.stop(pid)
#  end
#end