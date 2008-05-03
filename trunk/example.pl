:- use_module(library('http/thread_httpd')).
:- use_module(library('http/http_dispatch')).
:- use_module(library('http/html_write')).

server(Port) :-
        http_server(http_dispatch, [port(Port)]).

:- http_handler('/', root, []).
:- http_handler('/hello/world', hello_world, []).

root(_Request) :-
        reply_html_page([ title('Demo server')
                        ],
                        [ p(a(href('hello/world'), hello))
                        ]).

hello_world(_Request) :-
        reply_html_page([ title('Hello World')
                        ],
                        [ h1('Hello World'),
                          p('This is my first page')
                        ]).