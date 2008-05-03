:- use_module(library(odbc)).

:- odbc_connect('prolog',_,[alias(sql)]).

load_patient(P):-
    \+recorded(P,fact(demo(_,_,_,_,_),_,_,_),_),
    (
        odbc_query(sql,'select pred, id, author, stamp from fact where patient=~d and not historical'-[P],row(Pred,Id,Who,When)),
        term_to_atom(T,Pred),
        recorda(P,fact(T,Id,Who,When),_),
        fail
    );
    demo(P,Sur,First,Dob,Gender),
    recorda(P,demo(P,Sur,First,Dob,Gender),_).

unload_patient(P):-
    (
        recorded(P,_,L),
        erase(L),
        fail
    );true.

db_retract(P,T,C):-sqlify(C,C2),user(U),recorded(P,fact(T,Id,_,_),L),
    odbc_query(sql,'update fact set deleted_date=now (), deleted_comment=~w, deleted_user=~w where id =~w'-[Id,C2,U]),
    erase(L).

sql_escape([],L2,Final):-L2=Final.
sql_escape([C|L1],L2,Final):- C = '\\',!,append(L2,['\\'],L3),sql_escape(L1,L3,Final).
sql_escape([C|L1],L2,Final):- C = '''',!,append(L2,['''',''''],L3),sql_escape(L1,L3,Final).
sql_escape([C|L1],L2,Final):-append(L2,[C],L3),sql_escape(L1,L3,Final).

sqlify(X,Y):-number(X),!,X=Y.
sqlify(X,Y):-var(X),!,Y=['N','U','L','L'].
sqlify('$null$',['N','U','L','L']).
sqlify(date(Y,M,D),S):- sformat(S,'''~w/~w/~w''',[M,D,Y]).
sqlify(X,Y):-atom(X),atom_chars(X,L),sql_escape(L,[],L2),append(L2,[''''],L3),Y= [''''|L3].
sqlify(X,Y):-is_list(X),sql_escape(X,[],L2),append(L2,[''''],L3),Y= [''''|L3].

db_assert(P,Term):-
    format(chars(S1),'~w',Term),sqlify(S1,S2),user(U),
    odbc_query(sql, 'insert into fact (patient,pred,author) values (~w,~s,~w)'-[P,S2,U]),
    odbc_query(sql, 'select currval(''fact_id_seq''),now ()',row(IdT,When)),
    atom_number(IdT,Id),recorda(P,fact(Term,Id,U,When),_).

db_log(P,Term):-
    format(chars(S1),'~w',Term),sqlify(S1,S2),
    odbc_query(sql, 'insert into fact (patient,pred,deleted_date) values (~w,~s,now())'-[P,S2]).

db(P,T):-recorded(P,fact(T,_,_,_),_L).

db(P,T,Id,Who,When):-recorded(P,fact(T,Id,Who,When),_).

search_demo(QSur,Id,Sur,First,Dob,Gender):-
    atom_codes(QSur,L),sql_escape(L,[],QSurS),
    odbc_query(sql,'select id,surname,name,dob,gender from person where surname ilike ''~s%'''-[QSurS],row(Id,Sur,First,Dob,Gender)).

demo(Id,Sur,First,Dob,Gender):-var(Id),
    sqlify(Sur,Sur2),sqlify(First,First2),sqlify(Dob,Dob2),sqlify(Gender,Gender2),
    odbc_query(sql,'insert into person (surname,name,dob,gender) values (~s,~s,~s,~s)'-[Sur2,First2,Dob2,Gender2],affected(_)),
    odbc_query(sql,'select currval(''person_id_seq'')',row(IdT)),atom_number(IdT,Id).

demo(Id,Sur,First,Dob,Gender):-nonvar(Id),var(Sur),
    odbc_query(sql,'select surname,name,dob,gender from person where id = ~w'-[Id],row(Sur,First,Dob,Gender)).

demo(Id,Sur,First,Dob,Gender):-nonvar(Id),nonvar(Sur),sqlify(Sur,Sur2),sqlify(First,First2),sqlify(Dob,Dob2),sqlify(Gender,Gender2),
    odbc_query(sql,'update person set name=~s,surname=~s, gender=~s, dob=~s where id=~w'-[First2,Sur2,Gender2,Dob2,Id]).

search_history(P,Date1,Date2,Term,Id,Who,When):-
    sqlify(Date1,D1),sqlify(Date2,D2),
    odbc_query(sql,'select pred, id, author, stamp where patient = ~w and stamp > ~s and stamp < ~s'-[P,D1,D2],row(TermS,Id,Who,When)),
    term_to_atom(Term,TermS).

blob(Id,B,Mime):-
    var(Id),nonvar(B),!,
    atom_codes(B,L),sql_escape(L,[],B2),
    patient(P),
    odbc_query(db,'insert into blob (fk_patient,content,mime) values (~w,~s,''~w'')'-[P,B2,Mime]),
    odbc_query(db, 'select currval(''blob_id_seq'')',row(Id)).

blob(Id,B,Mime):-
    nonvar(Id),var(B),var(Mime),!,
    odbc_query(db,'select content, mime from blob where id=~w'-[Id],row(B,Mime)).

search_blob(Q,Id,B,Mime):-
    atom_codes(Q,L),sql_escape(L,[],L2),patient(P),
    odbc_query(db,'select id,content,mime from blob where mime like ''text/%'' and content ilike ''%~s%'' and fk_patient=~w'-[L2,P],row(Id,B,Mime)).