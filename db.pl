% database module

:- initialization mutex_create(db_general).

reload_demographics:-
    consult(db('demo.qlf')).

% convience functions

demo(N,Firstname,Lastname,Dob):-
    demo(N,Firstname,Lastname,Dob,_Address,_Postcode,_Telephone,_Medicare,_DVA,_CRN).
    
demo(N,Firstname,Lastname,Dob,Address,Postcode,Telephone):-
    demo(N,Firstname,Lastname,Dob,Address,Postcode,Telephone,_Medicare,_DVA,_CRN).
    
    

completion(_OldPatient,[SFirstname,SLastname],cmdline,noop,'open ~a ~a'-[Firstname,Lastname],
    '<span class="compl_stem">Open patient</span> ~a ~a'-[Firstname,Lastname],
    '/patient/~a/main'-[NewPatient]):-
    demo(NewPatient,Firstname,Lastname,_Dob),sub_atom(Firstname,0,_,_,SFirstname),sub_atom(Lastname,0,_,_,SLastname).

completion(OldPatient,[SLastname,',',SFirstname],cmdline,noop,Text,Html,Path):-
    completion(OldPatient,[SFirstname,SLastname],cmdline,noop,Text,Html,Path).


reload_contacts:-
    with_mutex(db_general,load_files(db('contacts.pl'),[])).
    
% save_contacts
% hilariosuly slow dumping of changed data to text file.
% However underlying to ever be big enough to make a difference.
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
    sub_atom(N,_,2,0,Suffix),
    absolute_file_name(db(Suffix),Dirname),
    (not(exists_directory(Dirname))->make_directory(Dirname)),
    absolute_file_name(db(Suffix/N),Filename),
    open_patient_file(N,Filename,Now).
    
open_patient_file(N,Filename,Now):- % old file
    exists_file(Filename),!,
    open(Filename,update,Fileno),
    catch(read_patient_file(N,Fileno),read_error(X,Pos),read_exc(X,Fileno,Pos)),
    asserta(pat_loaded(N,Now,Fileno)).
    
open_patient_file(N,Filename,Now):- % new file
    open(Filename,write,Fileno),
    asserta(pat_loaded(N,Now,Fileno)).

read_patient_file(N,Fileno):-
    repeat,
    stream_property(Fileno,position(Pos)),
    catch(read_term(Fileno,p(User,Date,Term)),X,throw(read_error(X,Pos))),
    asserta(p(N,User,Date,Term)),
    fail.