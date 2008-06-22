%   core module
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

:- use_module(src('web.pl')).
:- use_module(src('db.pl')).
	      
:- multifile reply/2, completion/7, page_avail/3,command/3.
:- discontiguous reply/2, completion/7, page_avail/3, command/3.
:- dynamic help/3,debug/2.
% settings
settings:consult(src('settings.pl')).

% clinical modules
:- consult(src('notes.pl')).
:- consult(src('diagnosis.pl')).

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
        use_module(library('http/http_error.pl')), % print stacktraces on error
        asserta(':-'(debug(Message,Params),log(debug,Message,Params))),
        reload_demographics,
        load_help,
        %reload_contacts,
        guitracer,
        http_server(reply,[port(8080)]).

% convience function
e(A):-
	concat_atom([A,'.pl'],B),
	absolute_file_name(src(B),C),
	emacs(C).
:- op(200,fy,e).

reply(Request) :-
        memberchk(path(Path), Request),
        parse_path(Path,PathList),
        once(get_params(Request,Request2)),
        once(get_prolog(Request2,Request3)),
        log(notice,'path ~w',[PathList]),
        catch(reply(Request3,PathList),error(X),log(error,'exception ~q',[X])).

reply(Request, []) :- not(memberchk(patient=_,Request)),
		   !,reply(Request,[laece,nopatient,welcome]).

reply(_, [file|Path]):-!,
    concat_atom(Path,'/',Filename),
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
  memberchk(patient=N,Request),
  N\=nopatient,
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

% completions for demographics 


completion(_OldPatient,[SFirstname,SLastname],cmdline,[],submit_now,
    '<span class="compl_stem">Open patient</span> ~s ~s'-[Firstname3,Lastname3],
    '/laece/~a/diagnoses'-[NewPatient]):-
        demo(NewPatient,Firstname,Lastname,_Dob),
        sub_atom(Firstname,0,_,_,SFirstname),
        sub_atom(Lastname,0,_,_,SLastname),
        name(Firstname,Firstname2),
        name(Lastname,Lastname2),
        capital_words(Firstname2,Firstname3),
        capital_words(Lastname2,Lastname3).

completion(OldPatient,[SLastname,',',SFirstname],cmdline,noop,Text,Html,Path):-
    completion(OldPatient,[SFirstname,SLastname],cmdline,noop,Text,Html,Path).


% logic for basic commands
completion(_N,[Cmd],cmdline,noop,submit_now,Html,Path):-
	command(Name,Html,Path),
	atom(Name),
	sub_atom(Name,0,_,_,Cmd).

completion(_N,[Cmd1],cmdline,noop,submit_now,Html,Path):-
	command([Name1|_],Html,Path),
	sub_atom(Name1,0,_,_,Cmd1).

completion(_N,[Cmd1,Cmd2],cmdline,noop,submit_now,Html,Path):-
	command([Name1,Name2|_],Html,Path),
	sub_atom(Name1,0,_,_,Cmd1),
	sub_atom(Name2,0,_,_,Cmd2).

completion(_N,[Cmd1,Cmd2,Cmd3],cmdline,noop,submit_now,Html,Path):-
	command([Name1,Name2,Name3|_],Html,Path),
	sub_atom(Name1,0,_,_,Cmd1),
	sub_atom(Name2,0,_,_,Cmd2),
	sub_atom(Name3,0,_,_,Cmd3).

command(licence,'licence - display GNU licence','/file/laece/Copying.html').
command(help,'help <i>[topic]</i> - show help page, can add specific topic','/file/laece/index.html').

% help system

completion(_N,[help,T],cmdline,noop,submit_now,'<span class="compl_stem">Help</span> '+Topic,'/file/laece/'+File):-
	help(Topic,File),
	sub_atom(Topic,0,_,_,T).

load_help:-
	absolute_file_name(resources('laece/*.html'),Pattern),
	expand_file_name(Pattern,Files),
	load_help_files(Files).

load_help_files([File|T]):-
	file_base_name(File,BaseFile),
	file_name_extension(Stem,html,BaseFile),
	downcase_atom(Stem,Topic),
	asserta(help(Topic,BaseFile)),
	load_help_files(T).
load_help_files([]).



















