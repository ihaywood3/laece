%   web interface module
%   Copyright (C) 2007,2008 Ian Haywood
%
%   This program is free software: you can redistribute it and/or modify
%   it under the terms of the GNU General Public License as published by
%   the Free Software Foundation, either version 3 of the License, or
%   (at your option) any later version.
%
%   This program is distributed in the hope that it will be useful,
%   but WITHOUT ANY WARRANTY; without even the implied warranty of
%   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%   GNU General Public License for more details.
%
%   You should have received a copy of the GNU General Public License
%   along with this program. If not, see <http://www.gnu.org/licenses/>.

:- use_module(library('http/http_session')).
:- use_module(library('http/http_error')).
:- use_module(library('http/http_client')).
:- use_module(library('http/html_write.pl')).

:- multifile reply/2, completion/7, page_avail/3.
:- discontiguous reply/2, completion/7, page_avail/3.

:- consult('db.pl').
:- consult('notes.pl').
:- consult('diagnosis.pl').

log(Level,Message,Params):-
        get_time(Stamp),
        format_time(user_error,'%c',Stamp),
        format(user_error,' [~a] ',Level),
        format(user_error,Message,Params),
        nl(user_error).

server_thread(Port):-
        use_module(library('http/thread_httpd')),
	use_module(library('http/http_error.pl')), % print stacktraces on error
        reload_demographics,
        %reload_contacts,
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
	emacs('/home/ian/laece/web.pl'),
        http_server(reply,[port(8080)]).

reply(Request) :-
        memberchk(path(Path), Request),
        parse_path(Path,PathList),
        once(get_params(Request,Request2)),
        once(get_prolog(Request2,Request3)),
        log(notice,'path ~w',[PathList]),
        catch(reply(Request3,PathList),error(X),log(error,'exception ~w',[X])).

reply(Request, []) :- not(memberchk(patient=_,Request)),
		   !,reply(Request,[laece,nopatient,welcome]).

reply(_, ['file',Filename]):-!,
    mimetype(Suffix,Mimetype),
    sub_atom(Filename,_,_,0,Suffix),
    absolute_file_name(resources(Filename),AbsFname),
    throw(http_reply(file(Mimetype,AbsFname))).

reply(_,['reload','demographics']):-reload_demographics.

reply(Request,[laece,N|Rest]):-
    % authenticate here
    (integer(N) -> atom_number(N2,N);N2=N),
    (N\=nopatient -> load_patient(N2);true),
    R2=[patient=N2|Request],
    ignore(add_data(R2)),
    ignore(print_data(R2)),
    reply(R2,Rest).

  
reply(Request,[welcome]):-
  reply_page(Request,'Welcome',[p(
      'Welcome to Laece. Above this text is the command bar, which is used to control
       laece. To load a patient type part of the firstname and part of surname, e.g. "jo smi" for 
       John Smith, a list of possible patients will appear, select one with the arrow
       keys to load that patient.')],[]).


get_params(Request,Request2):-
    memberchk(method(get),Request),
    memberchk(search(Params),Request),
    append(Request,Params,Request2).

get_params(Request,Request2):-
    memberchk(method(post),Request),
    http_read_data(Request,Params,[]),
    append(Request,Params,Request2).
    
get_params(Request,Request). % fallback option.

get_prolog(Request2,Request3):- % add prolog variables to params list in request.
    memberchk(prolog=P,Request2),
    catch(term_to_atom(TCmd,P),error(syntax_error(_),_),fail),
    append(TCmd,Request2,Request3).

get_prolog(X,X). % fallback option

reply(Request,[completions]):-
    memberchk(widget=W,Request),memberchk(compl_text=S,Request),memberchk(patient=N,Request),
    parse_command(S,L),
    findall(completion(Params,Text,Html,Path),completion(N,L,W,Params,Text,Html,Path),Reply),
    format('Content-Type: text/plain~n~n'),
    print_completion(Reply).

% general routine for recording new terms
add_data(Request):-
  memberchk(add=Term,Request),
  memberchk(patient=N,Request),
  N\=nopatient,
  assert_patient(N,Term).
  
% general routine for printable items
print_data(Request):-
  memberchk(add=Term,Request),
  memberchk(patient=N,Request),
  N\=nopatient,
  assert_patient(N,Term),
  memberchk(toprint=_Print,Request),
  % add to print queue here
  true.
  

% as yet unused warnings mechanism
warnings(N)-->
    {
        findall(wa(Level,L),phrase(warning(N,Level),L,[]),B),
        B\=[],!,sort(B,B2)
    },
    html([h2('Warnings')]),
    warn_p(B2).
warnings(_)-->[].
warn_p([wa(Level,L)|T])-->
    html([p([class=warning+Level],\L)]),warn_p(T).
warn_p([])-->[].


reply_page(Request,Title,MainPart,CurrentPage):-
    memberchk(patient=N,Request),
    once((memberchk(flash=Flash,Request);Flash='')),
    patient_name(N,PatientName),
    (	
             N==nopatient
         ->
	     SectionList=[]
         ; 
	     findall(page(Page,PageName),page_avail(N,Page,PageName),SectionList)
    ),
    reply_html_page(
    [
        title([PatientName,' : ',Title]),
        script([type='text/javascript',src='/laece/file/Base.js'],[]),
        script([type='text/javascript',src='/laece/file/Async.js'],[]),
        script([type='text/javascript',src='/laece/file/Iter.js'],[]),
        script([type='text/javascript',src='/laece/file/DOM.js'],[]),
        script([type='text/javascript',src='/laece/file/Style.js'],[]),
        script([type='text/javascript',src='/laece/file/Signal.js'],[]),
        script([type='text/javascript',src='/laece/file/midas.js'],[]),
        script([type='text/javascript',src='/laece/file/main.js'],[]),
        link([rel=stylesheet,type='text/css',href='/laece/file/main.css',media=all],[]),
        link([rel=stylesheet,type='text/css',href='/laece/file/print.css',media=print],[])
    ],[
	div([id=header],[
        form([action='/laece/'+N+'/newnote',method='post',name='cmdline_form',id='cmdline_form'],
            [
                input([name=cmdline,id=cmd,size=100,class=autocomplete,autocomplete=off],[]),
	  input([name=prolog,type=hidden,value=''],[]),
	  input([name=pat_id,type=hidden,value=N],[])
            ]
        ),
	    p([],ul([id=cmdline_list,class=hidden],[]))

      ]),
	div([id=content],[p([id=sectionlist],\print_sectionlist(N,CurrentPage,SectionList)),p([id=flash],Flash)|MainPart])
    ]).

reply_page(Request,Title,MainPart):-
	reply_page(Request,Title,MainPart,nopage).

print_sectionlist(N,CurrentPage,[H|L])-->print_sectionitem(N,CurrentPage,H),print_sectionlist2(N,CurrentPage,L).
print_sectionlist(_,_,[])-->[].
print_sectionlist2(_,_,[])-->[].
print_sectionlist2(N,CurrentPage,[H|L])-->[' | '],print_sectionitem(N,CurrentPage,H),print_sectionlist2(N,CurrentPage,L).

print_sectionitem(_,CurrentPage,page(CurrentPage,PageName))-->[PageName].
print_sectionitem(N,CurrentPage,page(OtherPage,PageName))-->{CurrentPage\=OtherPage},html([a(href='/laece/patient/'+N+'/'+OtherPage,PageName)]).

print_completion([completion(Params,Text,Html,Path)|Reply]):-
    str_prepare(Text,SText),
    str_prepare(Html,SHtml),
    str_prepare(Path,SPath),
    format('~q|~s|~s|~s~n',[Params,SText,SHtml,SPath]),print_completion(Reply).
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

parse_path(A,L):-name(A,I),phrase(path(L),I).
path(X)-->[0'/],path(X).
path([H])-->path_element(H).
path([H|T])-->path_element(H),[0'/],path(T).
path([])-->[].
path_element(X)-->path_chars(S),{S\=[],name(X,S)}.
path_chars([X|Y])-->[X],{X\=0'/},path_chars(Y).
path_chars([])-->[].

% parse_command(+Cmd,-Tokens)
% splits a command into tokens

parse_command(A,L):-downcase_atom(A,A2),name(A2,I),phrase(words(b,L),I).
words(_,[])-->[].
words(Type,[A|B])-->word(A,Type2),{Type\=Type2,Type2\=w},words(Type2,B).
words(p,[A|B])-->word(A,p),words(p,B).
words(Type,X)-->word(_,w),{Type\=w},words(w,X).
word(A,c)-->chars(S),{S\=[],name(A,S)}.
word(A,d)-->digits(S),{S\=[],name(A,S)}.
word(A,p)-->[S],{is_punct(S),name(A,[S])}.
word(_,w)-->whitespaces.
chars([X|Y])-->char(X),chars(Y).
chars([])-->[].
digits([X|Y])-->digit(X),digits(Y).
digits([])-->[].
char(X)-->[X],{is_char(X)}.
digit(X)-->[X],{is_digit(X)}.
whitespaces-->is_whitespace.
whitespaces-->is_whitespace,whitespaces.
is_char(X) :- X >= 0'a, X =< 0'z, !.
is_char(X) :- X >= 0'A, X =< 0'Z, !.
is_char(0'_).
is_digit(X) :- X >= 0'0, X =< 0'9, !.
is_punct(X) :- memberchk(X,"`~!@#$%^&*()-=+[]\;',./{}|:\"<>?").
is_whitespace-->" ".
is_whitespace-->[9]. % tab


% capital_words(+In,+Out)
% capitalise the first letter of each word of the list


capital_words([X|Rest],[Y|Out]):-X\=32,
    code_type(X,to_lower(Y)),capital_words2(Rest,Out). % capitalise the first letter
capital_words([X|Rest],Out):-X=32,
    capital_words2([X|Rest],Out). 

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


% write a term suitable for being part of a URL
url_term(U,T):-
   var(U),
   with_output_to(codes(C),writeq(T)),
   url_esc(C,C2),
   name(U,C2).

url_term(U,T):-
   var(T),
   name(U,C2),
   url_esc(C,C2),
   name(T2,C),
   term_to_atom(T,T2).

join(List,[Sep],Final):-
  join1(List,Sep,FinalL),name(Final,FinalL).
  
join1([H|T],Sep,L):-
  name(H,L1),
  append(L1,[Sep|L3],L),
  join1(T,Sep,L3).
  
join1([H],_,L):-
  name(H,L).

%% html_forall(+Template,:Goal,+Else,+Separator).
%	
% takes a HTML snipplet as a template and expands it for all solutions of Goal.
% Uses Else if no solutions.
% Puts Separator between each template if more than one solution

html_forall(Template,Goal,Else,Separator)-->
	{findall(Template,Goal,Bag)},
	html_forall1(Bag,Else,Separator).

html_forall1([],Else,_)-->html(Else).
html_forall1([H|T],_,Sep)-->html(H),html_forall2(T,Sep).
html_forall2([],_)-->[].
html_forall2([H|T],Sep)-->html(Sep),html(H),html_forall2(T,Sep).

html_forall(Template,Goal,Else)-->html_forall(Template,Goal,Else,[]).
html_forall(Template,Goal)-->html_forall(Template,Goal,[],[]).

% the MIDAS rich editing component
midas-->
    html([div([id=edit_area_div],[])]).

% a very useful constructs

if(X,Y)-->{ functor(X,'.',_);call(X) }, html(Y).
if(X,_Y)-->{ not(call(X));X=[] }, [].
if(X,Y,_Z)--> { call(X)}, html(Y).
if(X,_Y,Z)--> { not(call(X))}, html(Z).

% FIXME: replace with an actual authentication mechanism
user(ian).








