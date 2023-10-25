defmodule Sneakers23Web.ProductChannelTest do
  use Sneakers23Web.ChannelCase, async: true
  alias Sneakers23Web.{Endpoint, ProductChannel}
  alias Sneakers23.Inventory.{CompleteProduct, Server, DatabaseLoader}

  describe "notify_product_released/1" do
    test "the size selector for the product is broadcast" do
      {inventory, _data} = Test.Factory.InventoryFactory.complete_products()
      [_, product] = CompleteProduct.get_complete_products(inventory)

      topic = "product:#{product.id}"
      Endpoint.subscribe(topic)
      ProductChannel.notify_product_released(product)

      assert_broadcast "released", %{size_html: html}
      assert html =~ "size-container__entry"
      Enum.each(product.items, fn item ->
        assert html =~ ~s(value="#{item.id}")
      end)
    end

    test "the update is sent to the client", %{test: test_name} do
      {_, %{p1: p1}} = Test.Factory.InventoryFactory.complete_products()

      # Turn mode shared to enable communication between test and Server processes.
      Ecto.Adapters.SQL.Sandbox.mode(Sneakers23.Repo, {:shared, self()})
      {:ok, pid} = Server.start_link(name: test_name, loader_mod: DatabaseLoader)

      Sneakers23Web.Endpoint.subscribe("product:#{p1.id}")

      Sneakers23.Inventory.mark_product_released!(p1.id, pid: pid)
      assert_received %Phoenix.Socket.Broadcast{event: "released"}
    end
  end
end
