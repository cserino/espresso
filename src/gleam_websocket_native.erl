% Originally from this stackoverflow post, modified to work with espresso gleam modules.
% https://stackoverflow.com/questions/66682534/how-to-connect-cowboy-erlang-websocket-to-webflow-io-generated-webpage
-module(gleam_websocket_native).
-export([init/2, websocket_init/1, websocket_handle/2, websocket_info/2, module_name/0]).

module_name() ->
    ?MODULE.

init(Req, Handler) ->
    %Perform websocket setup
    {cowboy_websocket, Req, Handler}.

websocket_init(Handler) ->
    Handler({subscribe, self()}),
    {ok, Handler}.

websocket_handle({text, Msg}, Handler) ->
    case Handler({text, Msg}) of
        {reply, Value} -> {reply, {text, Value}, Handler};
        {ping, Value} -> {reply, {pong, Value}, Handler};
        {pong, Value} -> {reply, {ping, Value}, Handler};
        nothing -> {ok, Handler};
        {close, Value} -> {reply, {close, Value}, Handler}
    end;

%Ignore
websocket_handle(_Other, Handler) ->
    {ok, Handler}.

websocket_info({text, Text}, Handler) ->
    {reply, {text, Text}, Handler};

websocket_info(_Other, Handler) ->
    {ok, Handler}.
