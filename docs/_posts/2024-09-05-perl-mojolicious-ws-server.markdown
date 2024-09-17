---
layout: post
title:  "Perl: building a websocket server with Mojolicious"
date:   2024-09-17 08:15:29 -0000
categories: perl websocket mojolicious
---

![banner](/assets/images/2024-09-05-perl-mojolicious-ws-server/banner.png)

# introduction

In this article, we'll build a real-time stock price monitor using [Mojolicious](https://www.mojolicious.org/), a modern web framework for [Perl](https://www.perl.org/). This project demonstrates the power of [WebSockets](https://en.wikipedia.org/wiki/WebSocket) for real-time communication in web applications. We'll simulate stock prices for popular companies like `APPL`, `GOOGLE`, and `AMZN`, updating the prices on the web page as they change.

## prerequisites

- Perl installed on your system.
- Mojolicious installed. You can install it using CPAN:

```
cpan Mojolicious
```

# understanding WebSockets

[WebSockets](https://en.wikipedia.org/wiki/WebSocket) provide a full-duplex communication channel over a single, long-lived connection between a client (e.g., a web browser) and a server. Unlike the traditional request-response model of HTTP, [WebSockets](https://en.wikipedia.org/wiki/WebSocket) allow the server to push data to the client as soon as it becomes available, enabling real-time updates without the need for continuous polling.

In the context of our real-time stock price monitor, WebSockets are ideal because they allow us to:

- **Push updates instantly**: As soon as a stock price changes, the server can immediately send the update to all connected clients.
- **Reduce latency**: Since the connection is persistent, there's no need to repeatedly open and close connections, minimizing the delay in delivering updates.
- **Optimize resource usage**: By maintaining a single connection, WebSockets reduce the overhead of HTTP requests, making the application more efficient.

## how WebSockets Work

![websockets](/assets/images/2024-09-05-perl-mojolicious-ws-server/websockets.png)

1. **Connection Establishment**: The client sends a WebSocket handshake request to the server. If the server supports [WebSockets](https://en.wikipedia.org/wiki/WebSocket), it responds with a handshake acknowledgment, and a persistent connection is established.
2. **Data Exchange**: Both the client and server can send and receive messages over the WebSocket connection. This bi-directional communication allows the server to push updates to the client without waiting for a request.
3. **Connection Closure**: The connection remains open until either the client or server closes it. This persistent nature is what makes [WebSockets](https://en.wikipedia.org/wiki/WebSocket) particularly suitable for real-time applications.

# setting up the project

First, let's generate the [Mojolicious](https://www.mojolicious.org/) application:

```
$ mojo generate app StockMonitor
  [mkdir] /Users/tiagomelo/develop/perl/articles/stock_monitor/script
  [write] /Users/tiagomelo/develop/perl/articles/stock_monitor/script/stock_monitor
  [chmod] /Users/tiagomelo/develop/perl/articles/stock_monitor/script/stock_monitor 744
  [mkdir] /Users/tiagomelo/develop/perl/articles/stock_monitor/lib
  [write] /Users/tiagomelo/develop/perl/articles/stock_monitor/lib/StockMonitor.pm
  [exist] /Users/tiagomelo/develop/perl/articles/stock_monitor
  [write] /Users/tiagomelo/develop/perl/articles/stock_monitor/stock_monitor.yml
  [mkdir] /Users/tiagomelo/develop/perl/articles/stock_monitor/lib/StockMonitor/Controller
  [write] /Users/tiagomelo/develop/perl/articles/stock_monitor/lib/StockMonitor/Controller/Example.pm
  [mkdir] /Users/tiagomelo/develop/perl/articles/stock_monitor/t
  [write] /Users/tiagomelo/develop/perl/articles/stock_monitor/t/basic.t
  [mkdir] /Users/tiagomelo/develop/perl/articles/stock_monitor/public
  [write] /Users/tiagomelo/develop/perl/articles/stock_monitor/public/index.html
  [mkdir] stock_monitor/public/assets
  [mkdir] /Users/tiagomelo/develop/perl/articles/stock_monitor/templates/layouts
  [write] /Users/tiagomelo/develop/perl/articles/stock_monitor/templates/layouts/default.html.ep
  [mkdir] /Users/tiagomelo/develop/perl/articles/stock_monitor/templates/example
  [write] /Users/tiagomelo/develop/perl/articles/stock_monitor/templates/example/welcome.html.ep
```

This command creates a basic directory structure for your [Mojolicious](https://www.mojolicious.org/) application.

We're safe to remove files that we won't use:

```
rm -f lib/StockMonitor/Controller/Example.pm 
rm -rf templates/example/
```

## dir structure

```
StockMonitor/
├── lib/
│   └── StockMonitor/
│       ├── Controller/
│       │   └── Stock.pm
│       └── StockMonitor.pm
├── public/
├── script/
│   └── stock_monitor
├── templates/
│   └── stock/
│       └── index.html.ep
└── t/
```

- `lib/StockMonitor/StockMonitor.pm`: Main application file where we define routes.
- `lib/StockMonitor/Controller/Stock.pm`: Controller for stock data and WebSocket communication.
- `templates/stock/index.html.ep`: Template for the front end of our application.

# main application file

`lib/StockMonitor/StockMonitor.pm`:

```
# Copyright (c) 2024 Tiago Melo. All rights reserved.
# Use of this source code is governed by the MIT License that can be found in
# the LICENSE file.

package StockMonitor;
use Mojo::Base 'Mojolicious', -signatures;

# This method will run once at server start
sub startup ($self) {

  # Router
  my $r = $self->routes;

  # WebSocket route for real-time updates
  $r->websocket('/stock_updates')->to('stock#updates');

  # Normal route to serve the main page
  $r->get('/')->to('stock#index');
}

1;
```

- **Inheritance**: Inherits from Mojolicious, providing access to its features.
- **`startup` method**: Runs when the server starts, configuring the application's routes.
- **Routes**:
    - **WebSocket Route**: `/stock_updates` invokes the updates action in the `Stock` controller for real-time stock data.
    - **HTTP Route**: `/` invokes the index action in the `Stock` controller to render the main page.

This setup directs incoming requests to the appropriate controller actions, enabling both real-time and standard HTTP functionality.

# the controller

The heart of our application lies in the controller, where we'll handle the logic for [WebSocket](https://en.wikipedia.org/wiki/WebSocket) communication and simulate stock price updates.

`lib/StockMonitor/Controller/Stock.pm`:

```
# Copyright (c) 2024 Tiago Melo. All rights reserved.
# Use of this source code is governed by the MIT License that can be found in
# the LICENSE file.

package StockMonitor::Controller::Stock;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::IOLoop;

# Action to render the main page
sub index {
  my $self = shift;
  $self->render(template => 'stock/index');
}

# WebSocket action to handle real-time updates
sub updates {
  my $self = shift;

  # Get the stock ticker from the query parameter
  my $ticker = $self->param('ticker') || 'APPL';

  # Set up a timer to simulate stock price updates
  my $timer = Mojo::IOLoop->recurring(2 => sub {
    my $price = 100 + rand(50);  # Simulate a random stock price
    $self->send({json => {ticker => $ticker, price => sprintf("%.2f", $price)}});
  });

  # Clean up when WebSocket is closed
  $self->on(finish => sub {
    Mojo::IOLoop->remove($timer);
  });
}

1;
```

- `index` action: Renders the main page of our application.
    - as referenced in `lib/StockMonitor/StockMonitor.pm`: `$r->get('/')->to('stock#index');`
- `updates` action: Handles [WebSockets](https://en.wikipedia.org/wiki/WebSocket) connections. It simulates stock prices by sending random price updates every 2 seconds for the selected ticker.
    - as referenced in `lib/StockMonitor/StockMonitor.pm`: `$r->websocket('/stock_updates')->to('stock#updates');`

# main page

The front-end of our application is an HTML file with JavaScript to handle [WebSocket](https://en.wikipedia.org/wiki/WebSocket) communication and update the stock price in real time.

`templates/stock/index.html.ep`:

```
<!DOCTYPE html>
<html>
  <head>
    <title>Real-Time Stock Price Monitor</title>
    <script>
      let socket;

      function connectToTicker() {
        const ticker = document.getElementById('ticker').value;

        // Close existing socket if open
        if (socket && socket.readyState === WebSocket.OPEN) {
          socket.close();
        }

        // Create a new WebSocket connection with the selected ticker
        socket = new WebSocket("<%= url_for('stock_updates')->to_abs %>?ticker=" + ticker);

        // Handle incoming messages
        socket.onmessage = function(event) {
          const data = JSON.parse(event.data);
          document.getElementById('price').innerText = data.price;
          document.getElementById('ticker-display').innerText = data.ticker;
        };

        socket.onopen = function() {
          console.log('WebSocket connection opened for', ticker);
        };

        socket.onclose = function() {
          console.log('WebSocket connection closed');
        };

        socket.onerror = function(error) {
          console.error('WebSocket error:', error);
        };
      }

      window.onload = function() {
        connectToTicker();
      };
    </script>
  </head>
  <body>
    <h1>Real-Time Stock Price Monitor</h1>
    <p>Select a stock ticker:</p>
    <select id="ticker" onchange="connectToTicker()">
      <option value="APPL">APPL</option>
      <option value="GOOGLE">GOOGLE</option>
      <option value="AMZN">AMZN</option>
      <option value="MSFT">MSFT</option>
    </select>
    <p>Current Price for <span id="ticker-display">APPL</span>: $<span id="price">-</span></p>
  </body>
</html>

```

- The HTML page connects to the WebSocket endpoint and displays the stock price.
- Users can select different stock tickers from the dropdown menu, which updates the [WebSocket](https://en.wikipedia.org/wiki/WebSocket) connection to receive updates for the chosen ticker.

# running the application

With the application logic and front-end in place, we can now run our [Mojolicious](https://www.mojolicious.org/) application:

```
$ morbo script/stock_monitor 
Web application available at http://127.0.0.1:3000
```

Visit `http://localhost:3000` in your browser to see the real-time stock price monitor in action. You can select different stock tickers and watch the simulated prices update in real time:

![stock monitor](/assets/images/2024-09-05-perl-mojolicious-ws-server/stockMonitor.gif)

# conclusion

This project demonstrates how to build a real-time stock price monitor using [Mojolicious](https://www.mojolicious.org/), leveraging [WebSockets](https://en.wikipedia.org/wiki/WebSocket) for instant data updates. While this example uses simulated data, the same principles can be applied to build a more complex and realistic application. With [Mojolicious](https://www.mojolicious.org/) straightforward syntax and powerful features, creating real-time web applications in [Perl](https://www.perl.org/) becomes an enjoyable experience.

# download the source

Here: [https://github.com/tiagomelo/stock_monitor](https://github.com/tiagomelo/stock_monitor)