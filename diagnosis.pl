%   list-of-diagnoses module
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


:- consult('icd10.pl').
:- use_module(library(url)).

completion(N,[DiseaseName|Remainder],cmdline,[add=diagnosis(Code,UserDisease),flash=Flash],submit_now,
   '<span class="compl_stem">Diagnosis</span> ~a'-[IcdName],'/laece/patient/~a/add/diagnoses'-[N]):-
    atom_length(DiseaseName,L),L>3,
    icd10(Code,IcdName),sub_atom(IcdName,_,_,_,DiseaseName),
    not(diagnosis(N,_,_,Code,_)),
    format(atom(Flash),'~a diagnosed',[IcdName]),
    (	
       Remainder==[] ->
          join([DiseaseName|Remainder]," ",UserDisease)
       ; 
	  UserDisease=IcdName
    ).

page_avail(_,diagnoses,'Diagnoses').

  
reply(Request,[diagnoses]):-
	memberchk(patient=N,Request),
	findall(diagnosis(When,User,Code,UserDisease),diagnosis(N,When,User,Code,UserDisease),DiseaseList),
	reply_page(Request,'Disease List',[\print_diagnoses_list(N,DiseaseList)],diagnoses).

diagnosis(N,When,User,Code,UserDisease):-
	p(N,When,User,diagnosis(Code,UserDisease)),not(((p(N,When2,_,dediagnosis(Code,_));p(N,When2,_,diagnosis(Code,_))),When2>When)).

print_diagnoses_list(N,[diagnosis(When,User,Code,UserDisease)|T])-->
	{format_time(atom(WhenS),'%c',When),
	format(atom(UserDisease2),'~q',[UserDisease]),
	www_form_encode(UserDisease2,UserDisease3)},
	html(
	     [div([class=list],[
			     span([class=list_title],[UserDisease,' (',Code,')']),
			     ' Diagnosed by ',User,' on ',WhenS,' ',
			     a([href='javascript:show_form(\'dx'+Code+'\');',id='btn_dx'+Code],'Change'), ' ',
			     a([href='/laece/patient/'+N+'/add/diagnoses?prolog=%5Badd%3Ddediagnosis%28%27'+Code+'%27%2C'+UserDisease3+'%29%5D&flash=Diagnosis%20deleted'],'Delete')
			    ]
	      ),
	      div([class=hidden,id=dx+Code],
		[
		 form([action='/laece/change_diagnosis',method=post],
		      [
		       input([name=patient,type=hidden,value=N],[]),
		       input([name=code,type=hidden,value=Code],[]),
		       input([name=newdescription,type=text,size=20,value=UserDisease],[]),
		       input([type=submit,value='Submit'])
		      ])
		])]							 							 
	    ),
	print_diagnoses_list(N,T).

print_diagnoses_list(_,[])-->[].

reply(Request,[change_diagnosis]):-
	memberchk(patient=N,Request),
	memberchk(newdescription=UserDisease,Request),
	memberchk(code=Code,Request),
	assert_patient(N,diagnosis(Code,UserDisease)),
	reply([flash='Diagnosis changed'|Request],[diagnoses]).

html_display(diagnosis(Code,Text))-->html([Text,' (',Code,') diagnosed']).
html_display(dediagnosis(Code,Text))-->html([Text,' (',Code,') removed']).








