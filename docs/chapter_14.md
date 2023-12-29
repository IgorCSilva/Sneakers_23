# Single-Page Apps with React
## Hands-On with React

### Set Up the Project
Copy the code from react_example folder to some working directory.

Inside the project, run:
```sh
mix deps.get
npm --prefix assets install
```

### Inspecting the Router
The first thing that we'll look at is how the Home component is separated fromm the rest of the application.(This pate, Home, serves only static content, so it doesn't use a Socket or Channel)

```javascript
export default function Routes() {
  return (
    <Switch>
      <Route path={['/pings', '/count', '/other']}>
        <WebSocketRoutes />
      </Route>
      <Route path='/'>
        <Home />
      </Route>
    </Switch>
  )
}
```

This separation allows the Home page to clean up the real-time resources we're about to set up. Let's look at the slightly more complex WebSocketRoutes component.

```javascript
function WebSocketRoutes() {
  return (
    <Socket>
      <Route path={['/pings', '/count']}>
        <PingChannel topic='ping'>
          <Route path='/pings'>
            <Pings />
          </Route>
          <Route path='/count'>
            <Count />
          </Route>
        </PingChannel>
      </Route>

      <Route path={['/other']}>
        <PingChannel topic='other'>
          <Route path='/other'>
            <Pings topic='other' />
          </Route>
        </PingChannel>
      </Route>
    </Socket>
  )
}
```

Every route inside of this component uses the same Socket. There are two different PingChannel components.

### Build the Socket Component
Open the contexts/Socket.js file and add the following code:

- in assets/js/contexts/Socket.js:
```javascript
import React, { createContext, useEffect, useState } from 'react'
import { Socket as PhxSocket } from 'phoenix'

export const SocketContext = createContext(null) 

export default function Socket({ children }) {
  const [socket, setSocket] = useState(null)

  useEffect(() => {
    setupSocket(socket, setSocket) 

    return () => teardownSocket(socket, setSocket) 
  }, [socket])

  return ( 
    <SocketContext.Provider value={socket}>
      {children}
    </SocketContext.Provider>
  )
}
```

Add theses functions.
```javascript
// This function could be called even if a Phoenix Socket already exists, so we create the Phoenix Socket only if we don't already have one.
function setupSocket(socket, setSocket) {
  if (!socket) {
    console.debug('WebSocket routes mounted, connect Socket')
    const newSocket = new PhxSocket('/socket')
    newSocket.connect()
    setSocket(newSocket)
  }
}

function teardownSocket(socket, setSocket) {
  if (socket) {
    console.debug('WebSocket routes unmounted disconnect Socket', socket)
    socket.disconnect()
    setSocket(null)
  }
}
```

The combination of these two functions completes the life clycle for the Socket component.

### Build the Pings Component

```javascript
import React, { useContext, useEffect, useState } from 'react'
import { PingChannelContext } from '../contexts/PingChannel'

export default function Pings(props) {
  const topic = props.topic || 'ping'
  const [messages, setMessages] = useState([])
  const { onPing, sendPing } = useContext(PingChannelContext) 

  const appendDataToMessages = (data) =>
    setMessages((messages) => [ 
      JSON.stringify(data),
      ...messages
    ])

  useEffect(() => {
    const teardown = onPing((data) => { 
      console.debug('Pings pingReceived', data)
      appendDataToMessages(data)
    })

    return teardown 
  }, [])
```

The Pings component uses the useState React hook to give itself a place to store the messages from the PingChannel. The useContext hook gets the functions from the PingChannelContext, so that the component can communicate with the Channel.

The final part of this component is the interface's JSX.

```javascript
  return (
    <div>
      <h2>Pings: {topic}</h2>

      <p>
        This page displays the PING messages received from the
        server, since this page was mounted. The topic
        for this Channel is {topic}.
      </p>

      <button onClick={
        () => sendPing(appendDataToMessages)
      }>Press to send a ping</button>

      <textarea value={messages.join('\n')} readOnly />
    </div>
  )
```

The button uses sendPing to send data to the Phoenix Channel. The response is then appended to the message list.

### Try Out the Application

Make the following updates.

- in `config/config.exs`:
remove: `pubsub: [name: ReactExample.PubSub, adapter: Phoenix.PubSub.PG2]`
add: `pubsub_server: ReactExample.PubSub`

- in `lib/sneakers_23/application.ex`:
add to the children list: `{Phoenix.PubSub, name: ReactExample.PubSub},`

- in `test/support/conn_case.ex`:
remove: `use Phoenix.ConnTest`
add:
  `import Plug.Conn`
  `import Phoenix.ConnTest`

- in `test/support/channel_case.ex`:
remove: `use Phoenix.ChannelTest`
add:
  `import Phoenix.ChannelTest`
  `import ReactExampleWeb.ChannelCase`

- in `mix.exs`:
remove:
  `{:phoenix, "~> 1.4.7"},`
  `{:phoenix_pubsub, "~> 1.1"},`
add:
  `{:phoenix, "~> 1.5.0"},`
  `{:phoenix_pubsub, "~> 2.0"},`

remove: `compilers: [:phoenix, :gettext] ++ Mix.compilers(),`
add: `compilers: [:phoenix] ++ Mix.compilers(),`

Change the `assets/js/App.js` file name to `assets/js/app.js`.

After updates, run `mix deps.get`.
If necessary, change the node version. In my case I executed `nvm use v16.0.0`.

Start the server: `mix phx.server`
Open the browser: `http://localhost:4000`

Next, open the "WS" section in Chrome's Network Developer Tools.
Initially, you'll notice that the only WebSocket connection is for the phoenix/live_reload URL, which is provided by Phoenix and is not our application's Socket. Next, click on the Pings tab. You will see that a new Phoenix Socket connection is opend in the browser, becaouse we visited a page that requires a Socket connection. Next, click back and forth between Pings and Home. You'll see that the Socket connection is closed when you visit the Home page and opens again when you visit the Pings page.

When you navigate to the Other Pings page, the ping topic is left and the other topic is joined. If you navigate from the Pings to the Counter page no change is made to the Channel.