# HTTP and JSON

**Problem**: You need to serve or consume web APIs from Prolog.

## Core API

### JSON — library(http/json)

| Predicate | Purpose |
|---|---|
| `json_read_dict(Stream, Dict)` | Read JSON from a stream into a dict |
| `json_read_dict(Stream, Dict, Options)` | Read with options (e.g., `tag(Tag)`, `value_string_as(atom)`) |
| `json_write_dict(Stream, Dict)` | Write a dict as JSON to a stream |
| `json_write_dict(Stream, Dict, Options)` | Write with options (e.g., `width(W)` for pretty-printing) |
| `atom_json_dict(Atom, Dict, Options)` | Convert between a JSON atom/string and a dict |

### HTTP Server — library(http/thread_httpd), library(http/http_dispatch)

| Predicate | Purpose |
|---|---|
| `http_server(Dispatch, Options)` | Start an HTTP server (e.g., `[port(8080)]`) |
| `http_handler(Path, Goal, Options)` | Register a handler for a URL path |
| `http_read_json_dict(Request, Dict)` | Read JSON body from an HTTP request |
| `reply_json_dict(Dict)` | Send a JSON response with correct Content-Type |
| `reply_json_dict(Dict, Options)` | Send with options (e.g., `status(201)`) |
| `http_stop_server(Port, [])` | Stop a running server |

### HTTP Client — library(http/http_open)

| Predicate | Purpose |
|---|---|
| `http_open(URL, Stream, Options)` | Open a URL as a stream (GET by default) |
| `http_post(URL, Data, Reply, Options)` | POST data and read the reply |
| `http_get(URL, Reply, Options)` | GET a URL and read the reply |

## JSON Processing

```prolog
:- use_module(library(http/json)).

%% Read JSON from a file
read_config(Config) :-
    setup_call_cleanup(
        open('config.json', read, Stream),
        json_read_dict(Stream, Config),
        close(Stream)
    ).

%% Write JSON (pretty-printed)
write_result(Result) :-
    setup_call_cleanup(
        open('result.json', write, Stream),
        json_write_dict(Stream, Result, [width(80)]),
        close(Stream)
    ).

%% Convert between JSON string and dict (no file/stream needed)
?- atom_json_dict('{"name":"Alice","age":30}', D, []).
% D = _{age:30, name:"Alice"}.

?- atom_json_dict(Atom, _{x: 1, y: 2}, []), write(Atom).
% {"x":1,"y":2}
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

### REST Endpoint with Multiple Methods

```prolog
:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_json)).
:- use_module(library(http/http_parameters)).

:- dynamic item/2.   % item(Id, Data)

:- http_handler(root(items), handle_items, []).
:- http_handler(root(items/Id), handle_item(Id), []).

%% GET /items — list all items
handle_items(Request) :-
    member(method(get), Request),
    !,
    findall(_{id: Id, data: D}, item(Id, D), Items),
    reply_json_dict(_{items: Items}).

%% POST /items — create a new item
handle_items(Request) :-
    member(method(post), Request),
    http_read_json_dict(Request, Body),
    get_dict(id, Body, Id),
    get_dict(data, Body, Data),
    assertz(item(Id, Data)),
    reply_json_dict(_{status: created, id: Id}, [status(201)]).

%% GET /items/:id — get one item
handle_item(Id, Request) :-
    member(method(get), Request),
    (   item(Id, Data)
    ->  reply_json_dict(_{id: Id, data: Data})
    ;   reply_json_dict(_{error: "not found"}, [status(404)])
    ).
```

## HTTP Client

```prolog
:- use_module(library(http/http_open)).
:- use_module(library(http/json)).

%% GET JSON from a URL
fetch_json(URL, Dict) :-
    setup_call_cleanup(
        http_open(URL, Stream,
                  [request_header('Accept'='application/json')]),
        json_read_dict(Stream, Dict),
        close(Stream)
    ).

%% POST JSON to a URL
post_json(URL, Payload, Response) :-
    atom_json_dict(Body, Payload, []),
    setup_call_cleanup(
        http_open(URL, Stream,
                  [ method(post),
                    post(atom(application/json, Body)),
                    request_header('Accept'='application/json')
                  ]),
        json_read_dict(Stream, Response),
        close(Stream)
    ).
```

**When to use**: Building REST APIs, consuming external APIs, reading/writing JSON config or data files.

**Pitfall**: Always use `setup_call_cleanup/3` with streams to avoid resource leaks on exceptions.

---

**See also**: [Dicts](dicts.md) (JSON is represented as dicts in SWI-Prolog), [Threading](threading.md) (the HTTP server dispatches requests across threads), [Dynamic Predicates](dynamic-predicates.md) (server-side state management for REST endpoints), [Option Lists](option-lists.md) (HTTP options follow the option list convention).
