%   decision-support module
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

:- use_module(src(db)).


:- op(1000,xfx,then).
:- op(950,fx,if).
:- op(950,fx,when).
:- op(900,xfx,and).
:- op(800,xfx,or).
:- op(700,fx,prescribed).
:- op(700,fx,has).
:- op(600,fx,allergy).
:- op(550,fx,to).
:- op(800,fx,warn).
:- op(800,fx,suggest).
:- op(800,fx,panic).

trans(N,then(A,B),':-'(warning(N,Type,Message),A2)):-
	functor(B,Type,_),
	arg(1,B,Message),
	trans(N,A,A2).

trans(N,has(allergy(to(X))),allergy(N,X)).
trans(N,allergy(to(X)),allergy(N,X)).
trans(N,allergy(X),allergy(N,X)):-X\=to(_).
trans(N,has(allergy(X)),allergy(N,X)):-X\=to(_).
trans(N,if(X),X2):-trans(N,X,X2).
trans(N,and(A,B),','(A2,B2)):-
	trans(N,A,A2),
	trans(N,B,B2).


trans(N,or(A,B),';'(A2,B2)):-
	trans(N,A,A2),
	trans(N,B,B2).	

trans(N,not(A),not(A2)):-
	trans(N,A,A2).

trans(N,has(X),diagnosed(N,X)):-
	X\=allergy(_).
trans(N,prescribed(X),prescribed(N,X)).
trans(N,female,female(N)).
trans(N,male,not(female(N))).
trans(N,age>X,(age(N,A),A>X)).
trans(N,age>X,(age(N,A),A<X)).
trans(N,age>=X,(age(N,A),A>=X)).
trans(N,age=<X,(age(N,A),A=<X)).

female(N):-
	demo(N,_FN,_SN,_DOB,female).
age(N,Age):-
	demo(N,_,_,date(Y,M,D),_),
	get_time(Time),
	stamp_date_time(Time,date(Y2,M2,D2,_,_,_,_,_,_),local),
	Age is (Y2-Y)+((M2-M)/12)+((D2-D)/365).

	






