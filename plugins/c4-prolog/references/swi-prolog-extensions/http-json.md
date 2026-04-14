# HTTP and JSON

**Problem**: You need to serve or consume web APIs.

## JSON Processing

```prolog
:- use_module(library(http/json)).

% Read JSON from a file
read_config(Config) :-
    open('config.json', read, Stream),
    json_read_dict(Stream, Config),
    close(Stream).

% Write JSON
write_result(Result) :-
    open('result.json', write, Stream),
    json_write_dict(Stream, Result),
    close(Stream).
```

## HTTP Server

```prolog
:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_json)).

:- http_handler(root(hello), handle_hello, []).

handle_hello(Request) :-
    http_read_json_dict(Request, Input),
    get_dict(name, Input, Name),
    format(atom(Greeting), "Hello, ~w!", [Name]),
    reply_json_dict(_{greeting: Greeting}).

start_server(Port) :-
    http_server(http_dispatch, [port(Port)]).
```

## HTTP Client

```prolog
:- use_module(library(http/http_open)).
:- use_module(library(http/json)).

fetch_json(URL, Dict) :-
    setup_call_cleanup(
        http_open(URL, Stream, [request_header('Accept'='application/json')]),
        json_read_dict(Stream, Dict),
        close(Stream)
    ).
```

---

**See also**: [Dicts](dicts.md) (JSON is represented as dicts in SWI-Prolog), [Threading](threading.md) (the HTTP server dispatches requests across threads).
