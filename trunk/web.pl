
:- use_module(library('http/http_session')).
:- use_module(library('http/http_error')).
:- use_module(library('http/http_client')).
:- use_module(library('http/html_write.pl')).

:- multifile patient_command/3, patient_reply/3, completion/7, mainpage/5, warning/4.
:- discontiguous patient_command/3, patient_reply/3, completion/7, mainpage/5, warning/4.

:- consult('db.pl').
:- consult('meds.pl').

log(Level,Message,Params):-
        get_time(Stamp),
        format_time(user_error,'%c',Stamp),
        format(user_error,' [~a] ',Level),
        format(user_error,Message,Params),
        nl(user_error).

server_thread(Port):-
        use_module(library('http/thread_httpd')),
        reload_demographics,
        reload_contacts,
        http_server(reply,[port(Port)]),
        asserta(debug(_,_)),
        http_current_worker(Port,Thread),
        thread_join(Thread,_).

server_xpce:-
        use_module(library('http/xpce_httpd')),
        asserta(':-'(debug(Message,Params),log(debug,Message,Params))),
        reload_demographics,
        %reload_contacts,
        guitracer,
        http_server(reply,[port(8080)]).

reply(Request) :-
        memberchk(path(Path), Request),
        parse_path(Path,PathList),
        log(notice,'path ~w',[PathList]),
        catch(reply(Request,PathList),error(X),log(error,'exception ~w',[X])).

reply(Request, []) :- !,reply(Request,['patient','nopatient','main']).

reply(_, ['file',Filename]):-!,
    mimetype(Suffix,Mimetype),
    sub_atom(Filename,_,_,0,Suffix),
    absolute_file_name(resources(Filename),AbsFname),
    throw(http_reply(file(Mimetype,AbsFname))).

reply(_,['reload','demographics']):-reload_demographics.

reply(Request,['patient',N|Rest]):-
    % authenticate here
    (integer(N) -> atom_number(N2,N);N2=N),
    load_patient(N2),
    ignore((get_params(Request,Params),patient_process(N2,Params,Reply))),
    patient_reply(N2,Rest,Reply).

get_params(Request,Params):-
    memberchk(method(get),Request),
    memberchk(search(Params),Request).

get_params(Request,Params):-
    memberchk(method(post),Request),
    http_read_data(Request,Params,[]).

patient_process(N,Params,Reply):-
    memberchk(cmdline_data=Cmd,Params),
    catch(term_to_atom(TCmd,Cmd),error(syntax_error(_),_),fail),
    patient_command(N,TCmd,Reply),!.


patient_process(N,Params,Reply):-
    memberchk(widget=W,Params),memberchk(compl_text=S,Params),
    downcase_atom(S,S2),
    parse_command(S2,L),
    findall(completion(Term,Text,Html,Path),completion(N,L,W,Term,Text,Html,Path),Reply).
    

patient_command(_,noop,_).

patient_reply(_N,['completions'],Reply):-!,
    format('Content-Type: text/plain~n~n'),
    print_completion(Reply).


patient_reply(N,['main'],Reply):-!,
    ignore(Reply=''), % set reply to empty string if it's still unbound
    findall(mp(Priority,Width,L),phrase(mainpage(N,Priority,Width),L,[]),B),
    sort(B,B2), % using standard order of terms, i.e. by Priority
    patient_page(N,'Main',[p([class=result],Reply),\main_div(B2)]).

main_div([mp(_,Width,L)|T])-->
    html([div([style='width: '+Width+'ex;',class='main_page'],[\L])]),main_div(T).
main_div([])-->[].

mainpage(N,10,40)-->{N\=nopatient},warnings(N).

mainpage(nopatient,10,100)-->
  html('Welcome to laece. Above this text is the command bar, which is used to control laece. To load a patient type part of the
  firstname and part of surname, e.g. "jo smi" for John Smith, a list of possible patients will appear, select one with the arrow
  keys to load that patient.').

warnings(N)-->
    {
        findall(wa(Level,L),phrase(warning(N,Level),L,[]),B),
        B\=[],sort(B,B2)
    },
    html([h2('Warnings')]),
    warn_p(B2).
warn_p([wa(Level,L)|T])-->
    html([p([class="warning"+Level],[\L])]),warn_p(T).
warn_p([])-->[].

patient_page(N,Title,MainPart):-
    patient_name(N,T),
    reply_html_page(
    [
        title([T,': ',Title]),
        script([type='text/javascript',src='/file/Base.js'],[]),
        script([type='text/javascript',src='/file/Async.js'],[]),
        script([type='text/javascript',src='/file/Iter.js'],[]),
        script([type='text/javascript',src='/file/DOM.js'],[]),
        script([type='text/javascript',src='/file/Style.js'],[]),
        script([type='text/javascript',src='/file/Signal.js'],[]),
        script([type='text/javascript',src='/file/midas.js'],[]),
        script([type='text/javascript',src='/file/main.js'],[]),
        link([rel=stylesheet,type='text/css',href='/file/main.css',media=all],[]),
        link([rel=stylesheet,type='text/css',href='/file/print.css',media=print],[])
    ],[
        form([action='/patient/'+N+'/main',method='post',name='cmdline_form',id='cmdline_form'],
            [
                input([name=cmdline,id=cmd,size=100,class=autocomplete,autocomplete=off],[]),
                input([name=pat_id,type=hidden,value=N],[])
            ]
        ),hr([])|MainPart
    ]).

print_completion([completion(Data,Text,Html,Path)|Reply]):-
    str_prepare(Text,SText),
    str_prepare(Html,SHtml),
    str_prepare(Path,SPath),
    format('~w|~s|~s|~s~n',[Data,SText,SHtml,SPath]),print_completion(Reply).
print_completion([]).

str_prepare(T-L,S):-format(string(S),T,L).
str_prepare(S,S):-string(S).
str_prepare(A,S):-atom(A),string_to_atom(S,A).
str_prepare(A+B,S):-str_prepare(A,A1),str_prepare(B,B1),string_concat(A1,B1,S).

mimetype('.css','text/css').
mimetype('.js','text/javascript').
mimetype('.html','text/html').
mimetype('.pl','text/plain').
mimetype('.png','image/png').

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
code_typ(X,alpha):-memberchk(X,"abcdefghijklmnopqrstvwxyz_ABCDEFGHIJKLMNOPQRSTUVWXYZ").
code_typ(X,punct):-memberchk(X,"+-,/;'[]\\=`~{}|:<>?!@#$%^&*()\"").%"
code_match(X,Y):-code_typ(X,T),code_typ(Y,T).


% capital_words(+In,+Out)
% capitalise the first letter of each word of the list


capital_words([X|Rest],[Y|Out]):-
    code_type(X,to_lower(Y)),capital_words2(Rest,Out). % capitalise the first letter

capital_words2([X|R1],[X|R2]):-X\=32,
    capital_words2(R1,R2).
capital_words2([32,109,97,99,X|R1],[32,77,97,99,Y|R2]):-X\=32,!, % mac -> Mac
    code_type(X,to_lower(Y)),capital_words2(R1,R2).
capital_words2([32,109,99,X|R1],[32,77,99,Y|R2]):-X\=32,!, % mc -> Mc
    code_type(X,to_lower(Y)),capital_words2(R1,R2).
capital_words2([32,111,39,X|R1],[32,79,39,Y|R2]):-X\=32,!, % o' -> O'
    code_type(X,to_lower(Y)),capital_words2(R1,R2).
capital_words2([32,X|R1],[32,Y|R2]):-
    code_type(X,to_lower(Y)),capital_words2(R1,R2).
capital_words2([],[]).

% the MIDAS rich editing component
midas-->
    html([div([id=edit_area_div],[])]).

% FIXME: replace with an actual authentication mechanism
user(ian).