
:- use_module(library('http/http_session')).
:- use_module(library('http/http_error')).
:- use_module(library('http/http_client')).

%:- consult('db.pl').
/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

	?- server.

Now direct your browser to http://localhost:3000/
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

log(Level,Message,Params):-
        get_time(Stamp),
        format_time(user_error,'%c',Stamp),
        format(user_error,' [~w] ',Level),
        format(user_error,Message,Params),
        nl(user_error).

server_thread(Port):-
        use_module(library('http/thread_httpd')),
	http_server(reply,[port(Port)]),
        asserta(debug(_,_)),
        http_current_worker(Port,Thread),
        thread_join(Thread,_).
        
server_xpce(Port):-
        use_module(library('http/xpce_httpd')),
        asserta(':-'(debug(Message,Params),log(debug,Message,Params))),
        guitracer,
        http_server(reply,[port(Port)]).

reply(Request) :-
	memberchk(path(Path), Request),
        parse_path(Path,PathList),
        log(notice,'path ~w',[PathList]),
	catch(reply(Request,PathList),error(X),log(error,'exception ~w',[X])).

reply(Request, []) :- !,reply(Request,['nopatient','main']).
reply(_, ['file',Filename]):-!,
    mimetype(Suffix,Mimetype),
    sub_atom(Filename,_,_,0,Suffix),
    absolute_file_name(resources(Filename),AbsFname),
    throw(http_reply(file(Mimetype,AbsFname))).
    
reply(Request,['patient',N|Rest]):-
    % authenticate here
    load_patient(N),
    ignore((get_params(Request,Params),patient_process(N,Params,Reply))),
    patient_reply(N,Rest,Reply).
    
reply(_Request,['nopatient'|Rest]):-
    patient_reply(nopatient,Rest,_Reply).

get_params(Request,Params):-
    memberchk(method(get),Request),
    memberchk(search(Params),Request).
    
get_params(Request,Params):-
    memberchk(method(post),Request),
    http_read_data(Request,Params,[]).
    
patient_process(N,Params,Reply):-
    memberchk(cmd=Cmd,Params),
    atom_to_term(Cmd,TCmd,_),
    patient_command(N,TCmd,Reply).

patient_process(N,Params,Reply):-
    memberchk(search=S,Params),
    parse_command(S,L),
    findall(search_command(N,L,Term,Text),search_result(Term,Text),Reply).
    

patient_reply(_,['search'],Reply):-!,
    format('Content-Type: text/plain~n~n'),
    search_results(Reply).
    
    
search_results(X):-var(X).
search_results([]).
search_results([search_result(Term,Text)|T]):-format('~w|~a~n',[Term,Text]),search_results(T).

mimetype('.css','text/css').
mimetype('.js','text/javascript').
mimetype('.html','text/html').
mimetype('.pl','text/plain').

% parse_path(+Path,-Output)
% splits the path into chunks based on /

parse_path(A,L):-name(A,I),parse_path(I,S,S,L).
parse_path([47|T],[],[],I):-parse_path(T,S3,S3,I).
parse_path([47|T],[],S2,I):-S2\=[],name(A,S2),I=[A|X],parse_path(T,S3,S3,X).
parse_path([C|T],S1,S2,I):-C\=47,S1=[C|X],parse_path(T,X,S2,I).
parse_path([],[],[],[]).
parse_path([],[],S2,I):-S2\=[],name(A,S2),I=[A].

% parse_command(+Cmd,-Tokens)
% splits a command into tokens

parse_command(A,L):-name(A,I),parse_command(I,S,S,L).
parse_command([W|T],[],[],I):-whitespace(W),parse_command(T,S3,S3,I).
parse_command([W|T],[],S2,I):-whitespace(W),S2\=[],name(A,S2),I=[A|X],parse_command(T,S3,S3,X).
parse_command([C|T],[],[],I):- \+whitespace(C),parse_command(T,X,[C|X],I).
parse_command([C2|T],X,[C1|S2],I):-code_match(C1,C2),X=[C2|X2],parse_command(T,X2,[C1|S2],I).
parse_command([C2|T],[],[C1|S2],I):- \+code_match(C1,C2), \+whitespace(C1),
    name(A,[C1|S2]),I=[A|X2],parse_command(T,X,[C2|X],X2).
parse_command([],[],[],[]).
parse_command([],[],S2,I):-S2\=[],name(A,S2),I=[A].

whitespace(X):-memberchk(X," \t\r\n").
code_typ(X,number):-memberchk(X,"0123456789.").
code_typ(X,alpha):-memberchk(X,"abcdefghijklmnopqrstvwxyz_ABCDEFGHJKLMNOPQRSTUVWXYZ").
code_typ(X,punct):-memberchk(X,"+-,/;'[]\\=`~{}|:<>?!@#$%^&*()\"").%"
code_match(X,Y):-code_typ(X,T),code_typ(Y,T).



