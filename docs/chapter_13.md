# Hands-On with Phoenix LiveView
In chapter 7 we did a typical web application by passing HTML fragments from the server to the client, and also by passing JSON data to the client. In both solutions, the front end received the Channel's message and modified the interface based on its content.

LiveView changes this paradgm by defining your application's user interface in Elixir code. The interface is automatically kept up to date by sending content differences from server to client.


## Build a LiveView Product Page