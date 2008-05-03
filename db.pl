% database module

:- initialization mutex_create(db_general).

reload_demographics:-
    with_mutex(db_general,consult(db('demo.qlf'))).

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

completion(_OldPatient,[SFirstname,SLastname],cmdline,noop,'open ~s ~s'-[Firstname3,Lastname3],
    '<span class="compl_stem">Open patient</span> ~s ~s'-[Firstname3,Lastname3],
    '/patient/~a/main'-[NewPatient]):-
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
    
:- dynamic person/8.

load_contacts_mutex :- 
  retractall(person(_Id,_Name,_Address,_Suburb,_Phone,_Fax,_Email,_Specialty)),
  absolute_file_name(db('contacts.pl'),File),
  open(File, read, Stream), 
  read(Stream, T0), 
  load_contacts(T0, Stream),
  close(Stream).

load_contacts(end_of_file, _) :- !. 
load_contacts(person(Id,Name,Address,Suburb,Phone,Fax,Email,Specialty),Stream) :- !, 
  assert(person(Id,Name,Address,Suburb,Phone,Fax,Email,Specialty)), 
  read(Stream, T2), 
  load_contacts(T2, Stream). 
load_contacts(Term, Stream) :- 
  format(user_error, 'Bad term: ~p~n', [Term]), 
  read(Stream, T2), 
  load_contacts(T2, Stream).
    
% save_contacts
% hilariously slow dumping of changed data to text file.
% However underlying data unlikely to ever be big enough that anyone would care
save_contacts:-
    with_mutex(db_general,save_contacts_mutex).
save_contacts_mutex:-
    absolute_file_name(db('contacts.pl'),Fname),
    open(Fname,write,F),
    writeall(F,person(_Id,_Name,_Address,_Suburb,_Phone,_Fax,_Email)),
    close(F).
    
    
writeall(F,Term):-call(Term),write_canonical(F,Term),fail.
writeall(_F,_Term).

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
    stream_property(Fileno,position(Pos)),
    catch(read_term(Fileno,Term,[]),X,Term=read_error(X,Pos)).

% save patient data
assert_patient(N,Data):-
    get_time(Now),user(User),
    with_mutex(db_general,assert_patient_mutex(N,Now,User,Data)).

assert_patient_mutex(N,Now,User,Data):-
    pat_loaded(N,_,Fileno),
    format(Fileno,'p(~f,~w,~w).~n',[Now,User,Data]),
    flush_output(Fileno),
    asserta(p(N,Now,User,Data)).