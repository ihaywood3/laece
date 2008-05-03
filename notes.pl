%   notes modules
%   Copyright (C) 2007 Ian Haywood
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

:- use_module(library(lists)).

page_avail(_,X,Y):-notes_view(X,Y,_,_).

:- multifile html_display/3.
:- discontiguous html_display/3.
  
reply(Request,[View]):-
	memberchk(patient=N,Request),
	notes_view(View,_,Match,Query),
	findall(Match,get_notes(N,Match,Query),Bag1),
	sort(Bag1,Bag2),
	reverse(Bag2,Bag3),
	reply_page(Request,'Notes',[
	    \if(Bag3==[],['No notes'], \print_notes(Bag3,null,[]))
	],View).

get_notes(N,Match,Query):-
	p(N,When,Who,What),
	p(When,Who,What)=Match,
	call(Query).

print_notes([],_,[])-->[].
print_notes([],CurrentDay,NotesSoFar)--> {NotesSoFar \= []}, print_notes_decide([],date(null,null,null),CurrentDay,NotesSoFar).
print_notes([p(When,User,What)|T],CurrentDay,NotesSoFar)-->
	{
	     stamp_date_time(When,date(Y,M,D,_H,_Mn,_S,_Off,_TZ,_DST),local)
	},
	print_notes_decide([p(When,User,What)|T],date(Y,M,D),CurrentDay,NotesSoFar).

print_notes_decide([p(When,User,What)|T],date(Y,M,D),null,NotesSoFar)-->
	print_notes(T,date(Y,M,D),[p(When,User,What)|NotesSoFar]).

print_notes_decide([p(When,User,What)|T],date(Y,M,D),date(Y,M,D),NotesSoFar)-->
	print_notes(T,date(Y,M,D),[p(When,User,What)|NotesSoFar]).

print_notes_decide(L,date(Y,M,D),CurrentDay,NotesSoFar)-->
	{
	    CurrentDay \= date(Y,M,D) ,
	    sort(NotesSoFar,NotesSorted),
	    CurrentDay = date(Y2,M2,D2),
	    format_time(string(DateS),'%A, %e %B %Y',date(Y2,M2,D2,0,0,0,0,-,-))
	},
	html(h2([],'~s'-DateS)),
	print_day_notes(NotesSorted),
	print_notes(L,date(Y,M,D),[]).

print_day_notes([p(When,User,What)|T])-->
	{format_time(string(TimeS),'%r',When)},
	html([
	      div([class=notesheader],['~s'-TimeS,br([],[]),User]),
	      div([class=notestext],\html_display(What)),br([],[])
	     ]),
	print_day_notes(T).
print_day_notes([])-->[].
html_display(consult(Text))--> html([Text]).

reply(Request,[newnote]):-
	memberchk(patient=N,Request),
	memberchk(cmdline=Note,Request),
	assert_patient(N,consult(Note)),
	reply([flash='Note added'|Request],[today]).


notes_view(notes,'All Notes',p(_,_,_),true).
notes_view(today,'Today',p(When,_,_),(get_time(Now),Ago is Now-When,Ago < 86400.0,log(notice,'ago: ~a',[Ago]))).






