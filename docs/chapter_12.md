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
For cases where hibernation doesn't make as much sense, like for processes that receive messages frequently, you can use manual garbage collection to clean up memory as needed.
We can use :erlang.garbage_collect/0 to trigger garbage collection for the process that invoked the function.

You can trigger garbage collection for every process:
```
iex
iex(1)> Process.list() |> Enum.each(&:erlang.garbage_collect/1)
:ok
```

### Adjust How Often Garbage Collection Happens
You can set BEAM flag ERL_FULLSWEEP_AFTER that changes the value of minor garbage collections necessary to do a major garbage collection from 65535 to whatever value you'd like.
You can set this value by using the following syntax:
`-env ERL_FULLSWEEP_AFTER 20`

The trade-off exists. Garbage collection prevents a process from respnding to messages, so you could end up blocking processes more often, but 20 works well for the most applications that have long-running processes.

## Inspect a Running Application
In this section, wee're going to look at tolls for inspecting running applications and how to use them. You'll need to have a way to log into a running server to use the tolls listed in this section. If you are using Mix Release or Distillery to package your production application, then you can use the remote_console command to connect to your running server. If you do not have access to a running server, then you'll need to use collected metrics to debug performance problems.

### Tools for System Inspection
You can use Process.info/1 to collection information about a process. Let's open an iex session to try it out.

```
iex
iex(1)> Process.info(self())
[
  current_function: {Process, :info, 1},
  initial_call: {:proc_lib, :init_p, 5},
  status: :running,
  message_queue_len: 0,
  links: [],
  dictionary: [
    "$initial_call": {IEx.Evaluator, :init, 4},
    iex_history: %IEx.History{queue: {[], []}, size: 0, start: 1},
    "$ancestors": [#PID<0.74.0>],
    elixir_checker_info: {#PID<0.107.0>, nil},
    iex_evaluator: #Reference<0.3432810403.3861905410.49506>,
    iex_server: #PID<0.74.0>
  ],
  trap_exit: false,
  error_handler: :error_handler,
  priority: :normal,
  group_leader: #PID<0.66.0>,
  total_heap_size: 1974,
  heap_size: 1598,
  stack_size: 47,
  reductions: 2752,
  garbage_collection: [
    max_heap_size: %{error_logger: true, kill: true, size: 0},
    min_bin_vheap_size: 46422,
    min_heap_size: 233,
    fullsweep_after: 65535,
    minor_gcs: 7
  ],
  suspending: []
]
```

The Process.info/1 function provides useful information such as:
- message_queue_len: The number of messages waiting to be handled by this process.
- total_heap_size: The amount of heap memory that this process is using.
- reductions: Represents the amount of work this process has performed.
- current_function: The function currently being executed by this process.

### Basics of observer_cli
observer_cli is a terminal-based library that provides important and relevant information about a running system.
observer_cli opens to a home screen of a paginated list of all processes.

### Local Demo of observer_cli

Create a new project and add the observer_cli dependency to it.
`mix new observer_tools`
`cd observer_tools`

```elixir
  defp deps do
    [
      {:observer_cli, "~> 1.7.3"}
    ]
  end
```

Run `mix deps.get` and then start a session with `iex -S mix`.

```
iex(1)> defmodule Test do def recurse(), do: recurse() end
iex(2)> Enum.each((1..2), fn _ -> Task.async(&Test.recurse/0) end)
iex(3)> :observer_cli.start
```

You'll see the observer_cli home screen once you run the observer_cli.start/0 function.

Press r + enter to sort the process list by reduction count. When you do this, the top two heavily utilized processes appear.
Press 1 + enter to view process details for the first process listed on the screen.
This lets you know how CPU and memory usage change during a small window of time.
observer_cli is a useful tool to include in any Elixir application. You should include a tool like observer_cli or recon library early on in your project.