word(A,c)-->chars(S),{S\=[],name(A,S)}.
word(A,d)-->digits(S),{S\=[],name(A,S)}.
word(A,p)-->[S],{is_punct(S),name(A,[S])}.
word(_,w)-->whitespaces.
words(_,[])-->[].
words(Type,[A|B])-->word(A,Type2),{Type\=Type2,Type2\=w},words(Type2,B).
words(p,[A|B])-->word(A,p),words(p,B).
words(Type,X)-->word(_,w),{Type\=w},words(w,X).
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


