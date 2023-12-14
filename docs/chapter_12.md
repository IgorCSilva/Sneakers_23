# Manage Real-Time Resources

## Elixir's Scheduler Design

### How Work is Executed
We'll spin up a number of processes that execute the recursive function, so that each scheduler is busy.

```
iex

iex(1)> defmodule Test do def recurse(), do: recurse() end
iex(2)> :observer.start
iex(3)> schedulers = :erlang.system_info(:schedulers_online)
iex(4)> Enum.each((1..schedulers), fn _ -> Task.async(&Test.recurse/0) end)
iex(5)> Enum.map((1..10000), & &1 + &1) |> Enum.sum()
```

## Manage Your Application's Memory Effectively
### Process Hibernation Helps Prevent Bloat

One of the easiest ways to trigger garbage collection is to put a long-running process into a hibernated state. Hibernation releases the call stack and immediately garbage collects the process.

Let's create a simple process that allocates memory and gets stuck in a spot where garbage collection is not automatically triggered.

Create a new mix project:
`mix new memory`
`cd memory`

Replace the `lib/memory.ex` file with the following code:
```elixir
defmodule Memory do
  use GenServer
  
  def init([]) do
    {:ok, []}
  end
  
  def handle_call({:allocate, chars}, _from, state) do
    data = Enum.map((1..chars), fn _ -> "a" end)
    {:reply, :ok, [data | state]}
  end
  
  def handle_call(:clear, _from, _state) do
    {:reply, :ok, []}
  end
  
  def handle_call(:noop, _from, state) do
    {:reply, :ok, state}
  end
end
```

Start the process using `iex -S mix`.

```
iex(1)> {:ok, pid} = GenServer.start_link(Memory, [])
{:ok, #PID<0.186.0>}
iex(2)> :erlang.process_info(pid, :memory)           
{:memory, 2768}
iex(3)> GenServer.call(pid, {:allocate, 4_000})      
:ok
iex(4)> :erlang.process_info(pid, :memory)           
{:memory, 176232}
iex(5)> GenServer.call(pid, :clear)                  
:ok
iex(6)> :erlang.process_info(pid, :memory)
{:memory, 176232}
iex(7)> Enum.each((1..100), fn _ -> GenServer.call(pid, :noop) end)
:ok
iex(8)> :erlang.process_info(pid, :memory)                         
{:memory, 176232}
iex(9)> :erlang.garbage_collect(pid)
true
iex(10)> :erlang.process_info(pid, :memory)
{:memory, 2768}
```

We first start a new process and it initialize with 2768 bytes.

Let's add a :clear_hibernate function to the bottom of memory.ex.

```
  def handle_call(:clear_hibernate, _from, _state) do
    {:reply, :ok, [], :hibernate}
  end
```

Then, run:

```
iex(1)> {:ok, pid} = GenServer.start_link(Memory, [])
{:ok, #PID<0.161.0>}
iex(2)> :erlang.process_info(pid, :memory)
{:memory, 2768}
iex(3)> GenServer.call(pid, {:allocate, 4_000})
:ok
iex(4)> :erlang.process_info(pid, :memory)     
{:memory, 230416}
iex(5)> GenServer.call(pid, :clear_hibernate)  
:ok
iex(6)> :erlang.process_info(pid, :memory)   
{:memory, 1224}
```

### Manually Collect Garbage as Needed