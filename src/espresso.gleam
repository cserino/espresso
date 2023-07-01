//// This is the base module for starting the http server. It also does things
//// like retrieve the system port and halts but the main thing is the start
//// function.

import espresso/router.{Router, get, to_routes, websocket}
import espresso/system.{exit, get_port}
import espresso/websocket.{Nothing}
import gleam/erlang/process
import cowboy/cowboy
import gleam/io
import gleam/list
import gleam/otp/actor
import espresso/response.{send}

/// Starts the server with a router and returns the pid of the process.
/// 
/// ## Example 
/// 
/// ```gleam
/// import espresso
/// import espresso/request.{Request}
/// import espresso/response.{send}
/// import espresso/router.{get}
///
/// pub fn main() {
///   let router =
///     router.new()
///     |> get("/", fn(_req: Request(BitString, assigns, session)) { send(202, "Main Route") })
///
///   espresso.start(router)
/// }
/// ```
/// 
pub fn start(r: Router(req, assigns, session, res)) {
  let port = get_port()
  case cowboy.start(cowboy.router(to_routes(r)), on_port: port) {
    Ok(_) -> process.sleep_forever()
    Error(_) -> exit(1)
  }
}

external type DoNotLeak

external fn raw_send(websocket.Pid, message) -> DoNotLeak =
  "erlang" "send"

pub fn main() {
  let assert Ok(room) = actor.start([], handle_chatroom)
  let router =
    router.new()
    |> get(
      "/",
      fn(_req) {
        send(
          200,
          "
  <!DOCTYPE html>
  <html>
    <body>
      <h3>Hello gleam</h3>
      <ul id='messages'>
      </ul>
      <form id='send'>
        <label>Message: <input type='text' name='message' /></label>
        <button type='submit'>Send</button>
      </form>
      <script type=\"text/javascript\">
      const $messages = document.querySelector('#messages');
      const $send = document.querySelector('#send');

      function appendMessage(message) {
        const el = document.createElement('li');
        el.innerText = message;
        $messages.appendChild(el);
      }

      const ws = new WebSocket('ws://sakura.local:4343/ws');

      ws.addEventListener('open', function(event) {
        console.log('open', event);
      });
      ws.addEventListener('message', function(event) {
        console.log('message', event);
        appendMessage(event.data);
      });

      $send.addEventListener('submit', function(event) {
        event.preventDefault();
        const formData = new FormData($send);
        const message = formData.get('message');
        ws.send(message);
      });

      console.log('ws', ws);
      </script>
    </body>
  </html>
  ",
        )
        |> response.set_header("content-type", "text/html")
      },
    )
    |> websocket(
      "/ws",
      fn(state) {
        case state {
          websocket.Subscribe(pid) -> {
            process.send(room, Add(pid))
            raw_send(pid, websocket.Text("Hello"))
            Nothing
          }

          websocket.Text(text) -> {
            process.send(room, Broadcast("> " <> text))
            Nothing
          }

          _ -> {
            Nothing
          }
        }

        io.debug(state)
        Nothing
      },
    )
  start(router)
}

type Chat {
  Add(websocket.Pid)
  Broadcast(String)
}

fn handle_chatroom(chat: Chat, chatters: List(websocket.Pid)) {
  case chat {
    Add(pid) -> actor.Continue([pid, ..chatters])
    Broadcast(msg) -> {
      list.map(chatters, fn(chatter) { raw_send(chatter, websocket.Text(msg)) })
      actor.Continue(chatters)
    }
  }
}
