whitespace-->" ".
whitespace-->[9]. % tab
whitespaces-->whitespace.
whitespaces-->whitespace,whitespaces.
word(A,c)-->chars(S),{S\=[],name(A,S)}.
word(A,d)-->digits(S),{S\=[],name(A,S)}.
word(A,p)-->[S],{is_punct(S),name(A,[S])}.
words([A])-->word(A,_).
words([A])-->word(A,_),whitespaces.
words([A|B])-->word(A,_),whitespaces,words(B).
words([A,B|C])-->word(A,X),word(B,Y),{X\=Y},words(C).
wordslist(X)-->whitespaces,words(X).
wordslist(X)-->words(X).
chars([X|Y])-->char(X),chars(Y).
chars([])-->[].
digits([X|Y])-->digit(X),digits(Y).
digits([])-->[].
char(X)-->[X],{is_char(X)}.
digit(X)-->[X],{is_digit(X)}.

is_char(X) :- X >= 0'a, X =< 0'z, !.
is_char(X) :- X >= 0'A, X =< 0'Z, !.
is_char(0'_).
is_digit(X) :- X >= 0'0, X =< 0'9, !.
is_punct(X) :- memberchk(X,"`~!@#$%^&*()-=+[]\;',./{}|:\"<>?").
