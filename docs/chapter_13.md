# Hands-On with Phoenix LiveView
In chapter 7 we did a typical web application by passing HTML fragments from the server to the client, and also by passing JSON data to the client. In both solutions, the front end received the Channel's message and modified the interface based on its content.

LiveView changes this paradgm by defining your application's user interface in Elixir code. The interface is automatically kept up to date by sending content differences from server to client.


## Build a LiveView Product Page

### Set Up Your Project

Add the phonenix_live_view library.

- in mix.exs:
```elixir
    {:phoenix_html, "~> 3.3"},
    {:phoenix_live_view, "~> 0.17.3"}
```

Run `mix deps.get`.

Point the phoenix_live_view dependency to the local dependency version, like so:
- in assets/package.json:
```json
  "dependencies": {
    "phoenix": "file:../deps/phoenix",
    "phoenix_html": "file:../deps/phoenix_html",
    "phoenix_live_view": "file:../deps/phoenix_live_view"
  },
```

Run `mix phx.gen.secret 32` to generate a salt.

- in config/config.exs:
```elixir
# Configures the endpoint
config :sneakers_23, Sneakers23Web.Endpoint,
  ...
  # run `mix phx.gen.secret 32` to generate a salt.
  live_view: [signing_salt: "/ajDEEbMUBavA2yTmsZe3dE5xVJ6W35J"]
```

Set up endpoint to know live view.

- in lib/sneakers_23_web/endpoint.ex:
```elixir
  socket "/live", Phoenix.LiveView.Socket,
    websocket: true,
    longpoll: false
```

