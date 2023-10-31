# Build a Real-Time Shopping Cart

## Set Up the Project
Download the base code in https://pragprog.com/titles/sbsockets/real-time-phoenix/.

Copy to this project the following files from the code base downloaded:
from /sneakers_23_cart_base/assets/css/app.css
to /sneakers_23/assets/css/app.css

from /sneakers_23_cart_base/assets/js/cartRenderer.js
to /sneakers_23/assets/js/cartRenderer.js

## Scaffold Your Shopping Cart Channel

### Build a Functional Core
- in lib/sneakers_23/checkout/shopping_cart.ex:
```elixir
defmodule Sneakers23.Checkout.ShoppingCart do
  defstruct items: []

  def new(), do: %__MODULE__{}

  def add_item(cart = %{items: items}, id) when is_integer(id) do
    if id in items do
      {:error, :duplicate_item}
    else
      {:ok, %{cart | items: [id | items]}}
    end
  end

  def remove_item(cart = %{items: items}, id) when is_integer(id) do
    if id in items do
      {:ok, %{cart | items: List.delete(items, id)}}
    else
      {:error, :not_found}
    end
  end

  def item_ids(%{items: items}), do: items

  @base Sneakers23Web.Endpoint
  @salt "shopping cart serialization"
  @max_age 86400 * 7

  def serialize(cart = %__MODULE__{}) do
    {:ok, Phoenix.Token.sign(@base, @salt, cart, max_age: @max_age)}
  end

  def deserialize(serialized) do
    case Phoenix.Token.verify(@base, @salt, serialized, max_age: @max_age) do
      {:ok, data} ->
        items = Map.get(data, :items, [])
        {:ok, %__MODULE__{items: items}}

      e = {:error, _reason} ->
        e
    end
  end
end
```

Now expose the ShoppingCart functions.
- in lib/sneakers_23/checkout.ex:
```elixir
defmodule Sneakers23.Checkout do
  alias __MODULE__.{ShoppingCart}

  defdelegate add_item_to_cart(cart, item), to: ShoppingCart, as: :add_item
  defdelegate cart_item_ids(cart), to: ShoppingCart, as: :item_ids
  defdelegate export_cart(cart), to: ShoppingCart, as: :serialize
  defdelegate remove_item_from_cart(cart, item), to: ShoppingCart, as: :remove_item

  def restore_cart(nil), do: ShoppingCart.new()
  def restore_cart(serialized) do
    case ShoppingCart.deserialize(serialized) do
      {:ok, cart} -> cart
      {:error, _} -> restore_cart(nil)
    end
  end
end
```

We need to generate and store a random identifier in the cookie session.
First we need to generate a cart identifier.
- in lib/sneakers_23/checkout.ex:
```elixir
  @cart_id_length 64
  def generate_cart_id() do
    :crypto.strong_rand_bytes(@cart_id_length)
    |> Base.encode64()
    |> binary_part(0, @cart_id_length)
  end
```

We want our shopping cart to be on every page, including new pages that don't yet exist.
The Plug library allows us to easily create modules that'll execute on all page loads.

- in lib/sneakers_23_web/plugs/cart_id_plug.ex:
```elixir
defmodule Sneakers23Web.CartIdPlug do
  import Plug.Conn

  def init(_), do: []

  def call(conn, _) do
    {:ok, conn, cart_id} = get_cart_id(conn)
    assign(conn, :cart_id, cart_id)
  end

  defp get_cart_id(conn) do
    case get_session(conn, :cart_id) do
      nil ->
        cart_id = Sneakers23.Checkout.generate_cart_id()
        {:ok, put_session(conn, :cart_id, cart_id), cart_id}

      cart_id ->
        {:ok, conn, cart_id}
    end
  end
end
```

It's important to use put_session in order to save the cart ID in the shopper's session. Without this, every refresh would give a new cart ID.

Now add the following JavaScript snnipet.
- in lib/sneakers_23_web/templates/layout/app.html.eex:
```html
  ...
  <body>
    <header>
      <h2>Sneakers23</h2>
    </header>

    <%= render @view_module, @view_template, assigns %>
    
    <%= if assigns[:cart_id] do %>
      <div id="cart-container"></div>
      <script type="text/javascript">
        window.cartId = "<%= @cart_id %>"
      </script>
    <% end %>
    
    <script type="text/javascript" src="<%= Routes.static_path(@conn, "/js/app.js") %>"></script>
  </body>
  ...
```

Add the plug to Router module.
- in lib/sneakers_23_web/router.ex:
```elixir
  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug Sneakers23Web.CartIdPlug
  end
```

Now, start your browser:
`mix phx.server`

and visit `http://localhost:4000`. Open the console tab, type `window.cartId` and press enter. You need to see an id.
If you refresh or open multipe tabs, you will always see the same ID. If you open your browser incognito, you'll see a different ID.

## Build Your Shopping Cart Channel