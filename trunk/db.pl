%   database module
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

:- initialization catch(mutex_create(db_general),error(permission_error(mutex, create, db_general), context(mutex_create/1, _)),true).

reload_demographics:-
    with_mutex(db_general,consult(db('demo.pl'))).

% convience functions

demo(N,Firstname,Lastname,Dob):-
    demo(N,Firstname,Lastname,Dob,_Address,_Postcode,_Telephone,_Medicare,_DVA,_CRN).
    
demo(N,Firstname,Lastname,Dob,Address,Postcode,Telephone):-
    demo(N,Firstname,Lastname,Dob,Address,Postcode,Telephone,_Medicare,_DVA,_CRN).
    
patient_name(nopatient,'No patient loaded'):-!.
patient_name(N,T):-
    demo(N,Firstname,Lastname,_Dob),
    name(Firstname,Firstname2),
    name(Lastname,Lastname2),
    capital_words(Firstname2,Firstname3),
    capital_words(Lastname2,Lastname3),
    format(atom(T),'~s ~s (~a)',[Firstname3,Lastname3,N]).

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


load_contacts:-
    with_mutex(db_general,load_contacts_mutex).
    
:- dynamic contact/2.

load_contacts_mutex :- 
  absolute_file_name(db('contacts.pl'),File),
  open(File, read, Stream), 
  read(Stream, T0), 
  load_contacts(T0, Stream),
  close(Stream).

load_contacts(end_of_file, _) :- !. 
load_contacts(contact(Date,Contact),Stream) :- !, 
  assert(contact(Date,Contact)), 
  read_safe(Stream, T2), 
  load_contacts(T2, Stream). 
load_contacts(Term, Stream) :- 
  format(user_error, 'Bad term: ~p~n', [Term]), 
  read(Stream, T2), 
  load_contacts(T2, Stream).
    
% save_contact(+Contact).

save_contact(Contact):-
    with_mutex(db_general,save_contact_mutex(Contact)).
save_contact_mutex(Contact):-
    absolute_file_name(db('contacts.pl'),Fname),
    open(Fname,append,F),
    get_time(Now),
    format(F,'contact(~f,~q).~n',[Now,Contact]),
    close(F).
    
load_patient(nopatient).

load_patient(N):-
    get_time(Now),
    with_mutex(db_general,load_patient_mutex(N,Now)).

load_patient_mutex(N,Now):- % already open
    retract(pat_loaded(N,_LastAccess,Fileno)),!, 
    asserta(pat_loaded(N,Now,Fileno)).
    
load_patient_mutex(N,Now):- % open patient file
    ignore(remove_expired(Now)),
    sub_atom(N,_,2,0,Suffix),
    absolute_file_name(db(Suffix),Dirname),
    (not(exists_directory(Dirname))->make_directory(Dirname);true),
    absolute_file_name(db(Suffix/N),Filename),
    open_patient_file(N,Filename,Now).
    
remove_expired(Now):-
    pat_loaded(N,Time,Fileno),
    Diff is Now-Time,
    Diff > 3600, % one hour
    retract(pat_loaded(N,Time,Fileno)),
    close(Fileno),
    retractall(p(N,_,_,_)),
    fail.
    
open_patient_file(N,Filename,Now):- % old file
    exists_file(Filename),!,
    open(Filename,read,Fileno),
    read_safe(Fileno,Term),
    process_term(Now,Filename,N,Fileno,Term,none).
    
open_patient_file(N,Filename,Now):- % new file
    open(Filename,write,Fileno),
    log(notice,'opeing new file ~a for patient ~a',[Filename,N]),
    asserta(pat_loaded(N,Now,Fileno)).

% end of file, no errors
process_term(Now,Filename,N,Fileno,end_of_file,none):-
    close(Fileno),
    debug('~a: completed file read',[Filename]),
    open(Filename,append,Fileno2),
    asserta(pat_loaded(N,Now,Fileno2)).

% end of file with an error, so rewind to overwrite 
process_term(Now,Filename,N,Fileno,end_of_file,OldPos):-OldPos\=none,
    close(Fileno),
    debug('~a: completed file read',[Filename]),
    debug('~a: backtracking to ~w due to previous error',[Filename,OldPos]),
    open(Filename,update,Fileno2),
    set_stream_position(Fileno2,OldPos),
    asserta(pat_loaded(N,Now,Fileno2)).

% got some data
process_term(Now,Filename,N,Fileno,p(Date,User,Data),_):-
    asserta(p(N,Date,User,Data)),
    read_safe(Fileno,T2),
    process_term(Now,Filename,N,Fileno,T2,none).

% uh oh, an error
process_term(Now,Filename,N,Fileno,read_error(Error,OldPos),none):-
    log(warn,'~a: Read error: ~w, skipping',[Filename,Error]),
    read_safe(Fileno,T2),
    process_term(Now,Filename,N,Fileno,T2,OldPos).
    
% Aaargh! two errors in a row
process_term(_Now,Filename,_N,_Fileno,read_error(Error,_Pos),OldPos):-OldPos\=none,
    log(error,'~a: FILE CORRUPTED: Multiple read errors (~w), stopping read',[Filename,Error]).
    
    
% a handy read function that doesn't throw exceptions
read_safe(Fileno,Term):-
    catch(read_term(Fileno,Term,[]),X,(stream_property(Fileno,position(Pos)),Term=read_error(X,Pos))).

% save patient data
assert_patient(N,Data):-
    get_time(Now),user(User),
    with_mutex(db_general,assert_patient_mutex(N,Now,User,Data)).

assert_patient_mutex(N,Now,User,Data):-
    pat_loaded(N,_,Fileno),
    format(Fileno,'p(~f,~q,~q).~n',[Now,User,Data]),
    flush_output(Fileno),
    asserta(p(N,Now,User,Data)).
