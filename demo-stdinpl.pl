#!/usr/bin/swipl -s
% Demonstration on how to use the GTK-server with Gnu PROLOG by STDIN.
% Tested with Gnu PROLOG 1.2.16 on Linux Slackware 9.1 and WindowsXP.
%
% June 3, 2004 by Peter van Eerten.
% Revised at july 24, 2004.
%
% Run with gprolog. Compile with 'gplc demo.pl'.
% Revised for GTK-server 1.2 October 7, 2004
% Revised for GTK-server 1.3 December 6, 2004
%
%------------------------------------------------------------------------
% Revised at november 1, 2006:
%   - Changed to generic READ predicate
%   - Buffering set to LINE
%   - Removed spaces at the beginning of the strings sent to GTK-server
%
% Tested with GNU Prolog 1.2.19 and GTK-server 2.1.2 in Zenwalk Linux 3.0
%------------------------------------------------------------------------

:- use_module(library(unix)).
:- use_module(library(memfile)).

:- dynamic widget_store/2.

init:-
  pipe(Childread,Pout),
  pipe(Pin,Childwrite),
  fork(Pid),
  (   Pid == child
  ->  close(Pout),close(Pin),
      %close(0),close(1),
      dup(Childread,0),dup(Childwrite,1),
      % Start server in STDIN mode
      exec('gtk-server'('stdin','post=.','cfg=/home/ian/perm/gtk-server.cfg','log'))
  ;   close(Childread),close(Childwrite),
      set_stream(Pout,buffer(line)),
      set_stream(Pout,alias(gtk_out)),
      set_stream(Pin,alias(gtk_in)),
      % Initialize GTK
      gtk(init,[null,null])
  ).

special(null,'NULL').
special(wait,'WAIT').
special(false,0).
special(true,1).
special(gtk_shadow_in,1).
special(g_string,16).

gtk_write(Stream,X):-number(X),!,write(Stream,X).
gtk_write(Stream,X):-special(X,Y),!,write(Stream,Y).
gtk_write(Stream,X):-!,write(Stream,'"'),write(Stream,X),write(Stream,'"').

% This is the concatenate predicate
cat([], _).
cat([H|T], Stream):-
    write(Stream, ' '),
    gtk_write(Stream, H),
    cat(T, Stream).

% Concatenate list and communicate
gtk(Command, List, Result):-
    new_memory_file(Handle),
    open_memory_file(Handle, write, Stream),
    write(Stream,'gtk_'),
    write(Stream,Command),
    cat(List, Stream),
    close(Stream),
    memory_file_to_atom(Handle, Text),
    free_memory_file(Handle),
    write(gtk_out, Text), write(gtk_out, '\n'),
    % Read info
    read(gtk_in, Result).

gtk(Command, List):-
  gtk(Command, List, _).

widget(X,Y):-widget_store(X,Y),!.

widget(X,Y):-gtk(server_glade_widget,[X],Y),asserta(widget_store(X,Y)),!.

main:-
    % Load glade interface
    gtk(server_glade_file,['perm.glade']),
    connect_events,
    % show main window
    widget(main_window,X),
    gtk(widget_show_all,[X]),
    % Main
    do_event.

do_event:-
    gtk(server_callback,[wait], EVENT),
    handle_event(EVENT),
    do_event.

handle_event(W-E):-
    event(W,E),!.

handle_event(EVENT):-
    write('Unknown event: '),
    write(EVENT),nl.

connect_events:-
    clause(event(W,E),_),
    widget(W,X),
    sformat(Y,'~w-~w',[W,E]),
    gtk(server_connect,[X,E,Y]),
    fail.

connect_events.

event(main_window,delete_event):-
    write('exiting...'),nl,
    % Exit GTK
    gtk(exit,[0]),
    % Exit Prolog
    halt.

%:-  init,
%    main.