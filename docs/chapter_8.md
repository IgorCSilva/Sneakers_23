# Break Your Application with Acceptance Tests

## Break Your App Like a User

### Page Related Actions

Run:
```
mix ecto.reset
mix run -e "Sneakers23Mock.Seeds.seed!()"
iex -S mix phx.server
```

Now, open `http://localhost:4000` and you will see "coming soon" products.
Next execute:
```
iex(1)> Sneakers23.Inventory.mark_product_released!(1)
```

The size selector will appear.
Go to another website in the same tab. After that, go back to the sneakers23 store. I everything worked correctly, you will see that the web page says "coming soon" instead of showing the size selector, that is a bug. This bug doesn't affect all browsers, such as Safari.
One way to fix this bug is to tell the browser to not cache the page.

- in lib/sneakers_23_web/controllers/product_controller.ex:
```elixir
  def index(conn, _params) do
    {:ok, products} = Sneakers23.Inventory.get_complete_products()

    conn
    |> assign(:products, products)
    |> put_resp_header("Cache-Control", "no-store, must-revalidate")
    |> render("index.html")
  end
```

### Internet Related Actions

we'll execute a test case to ensure that users can reconnect to the store when they become disconnected.

Run:
```
mix ecto.reset
mix run -e "Sneakers23Mock.Seeds.seed!()"
iex -S mix phx.server
```

Now, open `http://localhost:4000` and you will see "coming soon" products.
Then, type ctrl+c, type a and then enter to shutdown the server.

Next restart the server:
```
iex -S mix phx.server

iex(1)> Sneakers23.Inventory.mark_product_released!(1)
```

Here, some possibility is that you don't see the front end change. This could happen if you executed mark_product_released/1 during the few seconds of delay of reconnection process.
One strategy to solve the issue of missing messages during a disconnection es to send the most up-to-date data when a Channel loads. This would solve both the caching issue and missing messages issue that we've seen in this chapter, at the cost of additional processing by the server. This strategy is not implemented in this book.

## Break Your App Like a Server

### Simulate Database Downtime

Run:
```
mix ecto.reset
mix run -e "Sneakers23Mock.Seeds.seed!()"
iex -S mix phx.server
```

Now, open `http://localhost:4000` and you will see "coming soon" products.

Stop the database typing ctrl+c in database shell.
Refresh the page several times. At this point you can refresh the page without issue.

Try release a product, that will fail:
`iex(1)> Sneakers23.Inventory.mark_product_released!(1)`

Restart the database:
`docker-compose up`

Try release a product again:
`iex(1)> Sneakers23.Inventory.mark_product_released!(1)`

The page must be change in real-time.

### Kill BEAM Processes with Observer


If you run the command :observer.start below and it not work, follow this steps to show observer window:

obs.: It depends the way you install the erlang in your machine.

Uninstall erlang: asdf uninstall erlang 25.0
Install library: apt-get -y install libwxgtk-webview3.0-gtk3-dev (link for others OS: https://github.com/asdf-vm/asdf-erlang#before-asdf-install)
Reinstall erlang: asdf install erlang 25.0

Run:
```
mix ecto.reset
mix run -e "Sneakers23Mock.Seeds.seed!()"
iex -S mix phx.server

iex(1)> :observer.start
```

With the observer window opened, go to Applications tab and kill the Sneakers23.Inventory process.

Next, try release a product:
`iex(2)> Sneakers23.Inventory.mark_product_released!(1)`

All must be work correctly.

## Automate Acceptance Tests with Hound

### Configure Hound

Install chromedriver.

Ubuntu:
```
wget https://chromedriver.storage.googleapis.com/2.41/chromedriver_linux64.zip
unzip chromedriver_linux64.zip
```

Run the chromedriver:
`./chromedriver`


- in mix.exs:
```elixir
    {:plug_cowboy, "~> 2.5"},
    {:hound, "~> 1.1.1"}
```

Run `mix deps.get`.

Now, place the following code as the final plug definintion in the Endpoint module.
- in lib/sneakers_23_web/endpoint.ex:
```elixir
if Application.compile_env(:sneakers_23, :sql_sandbox) do
    plug Phoenix.Ecto.SQL.Sandbox
  end
```

Allow our application's HTTP server to run in test mode. It's necessary because our acceptance tests will be executing against the running server.

- in config/test.exs:
```elixir
config :sneakers_23, Sneakers23Web.Endpoint,
  http: [port: 4002],
  server: true
```

Our tests will execute without a browser continuously opening and closing.

- in config/test.exs:
```elixir
# Instruct Hound to use ChromeDriver.
config :hound, driver: "chrome_driver", browser: "chrome_headless"
```

Tell our application to use SQL sandbox:
- in config/test.exs:
```elixir
# Tell to use SQL sandbox.
config :sneakers_23, sql_sandbox: true
```

Start Hound for tests:
- in test/test_helper.exs:
```elixir
Application.ensure_all_started(:hound)
ExUnit.start()
```

Let's write a test.
- in test/acceptance/home_page_test.exs:
```elixir
defmodule Acceptance.HomePageTest do
  use ExUnit.Case, async: false
  use Hound.Helpers

  setup do
    Hound.start_session()
    :ok
  end

  test "the page loads" do
    navigate_to("http://localhost:4002")
    assert page_title() == "Sneaker23"
  end
end
```

### Write Automated Acceptance Tests

Currently, the global inventory process loads its state at startup, and we do not have a way to change the loaded inventory. We will need to add a function to the bottom of the Inventory.Server module.

- in lib/sneakers_23/inventory/server.ex:
```elixir
  if Mix.env() == :test do
    def handle_call({:test_set_inventory, inventory}, _from, _old) do
      {:reply, {:ok, inventory}, inventory}
    end
  end
```

- in test/acceptance/product_page_test.exs:
```elixir
defmodule Acceptance.ProductPageTest do
  use Sneakers23.DataCase, async: false
  use Hound.Helpers

  alias Sneakers23.{Inventory, Repo}

  setup do
    # This allows the requests that are executed by the browser to use the test database without errors appearing.
    metadata = Phoenix.Ecto.SQL.Sandbox.metadata_for(Repo, self())
    Hound.start_session(metadata: metadata)

    {inventory, _data} = Test.Factory.InventoryFactory.complete_products()
    {:ok, _} = GenServer.call(Inventory, {:test_set_inventory, inventory})

    :ok
  end

  # Any content changes on the page are from live updates and not from a page load.
  test "the page updates when a product is released" do
    navigate_to("http://localhost:4002")

    [coming_soon, available] = find_all_elements(:css, ".product-listing")

    assert inner_text(coming_soon) =~ "coming soon..."
    assert inner_text(available) =~ "coming soon..."

    # Release the shoe.
    {:ok, [_, product]} = Inventory.get_complete_products()
    Inventory.mark_product_released!(product.id)

    # The second shoe will have a size-container and no coming soon test.
    assert inner_text(coming_soon) =~ "coming soon..."
    refute inner_text(available) =~ "coming soon..."

    refute inner_html(coming_soon) =~ "size-container"
    assert inner_html(available) =~ "size-container"
  end

  test "the page updates when a product reduces inventory" do
    {:ok, [_, product]} = Inventory.get_complete_products()
    Inventory.mark_product_released!(product.id)

    navigate_to("http://localhost:4002")

    [item_1, _item_2] = product.items

    assert [item_1_button] = find_all_elements(:css, ".size-container__entry[value='#{item_1.id}']")

    assert outer_html(item_1_button) =~ "size-container__entry--level-low"
    refute outer_html(item_1_button) =~ "size-container__entry--level-out"

    # Make the item be out of stock.
    new_item_1 = Map.put(item_1, :available_count, 0)
    opts = [previous_item: item_1, current_item: new_item_1]
    Sneakers23Web.notify_item_stock_change(opts)

    refute outer_html(item_1_button) =~ "size-container__entry--level-low"
    assert outer_html(item_1_button) =~ "size-container__entry--level-out"
  end
end

```

It's possible to not use a global process in our tests by creating a Plug similar to the SQL Sandbox that we set up previously.