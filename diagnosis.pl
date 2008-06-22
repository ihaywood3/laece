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

completion(N,DiseaseNames,cmdline,[add=diagnosis(Code,UserDisease),flash=Flash],submit_now,
   '<span class="compl_stem">Diagnosis</span> ~a'-[IcdName],diagnoses):-
    N\=nopatient,
    DiseaseNames=[First|_],
    atom_length(First,L),L>3,
    split_d_names(DiseaseNames,DSearch,Remainder),
    (  Remainder==[] ->
	UserDisease=''
    ;	
              concat_atom(Remainder,' ',UserDisease)
    ),
    icd10(Code,IcdName),
    not(diagnosis(N,_,_,Code,_)),
    disease_match(IcdName,DSearch),
    Flash=[IcdName,' diagnosed'].


split_d_names(['-'|R],[],R).
split_d_names([],[],[]).
split_d_names([H|T],[[H,H2,H3]|T2],R):- H\= '-',
	atom_concat(' ',H,H2),
	atom_concat('(',H,H3),
	split_d_names(T,T2,R).

disease_match(IcdName,[[H1,H2,H3]|T]):-
	once((   sub_atom(IcdName,0,_,_,H1);
                           sub_atom(IcdName,_,_,_,H2);
                           sub_atom(IcdName,_,_,_,H3))),
	disease_match(IcdName,T).
disease_match(_,[]).

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
	www_form_encode(UserDisease2,UserDisease3),
	 disease_name(Code,UserDisease,DiseaseName)},
	html(
	     [div([class=list],[
			     span([class=list_title],DiseaseName),
			     ' Diagnosed by ',User,' on ',WhenS,' ',
			     a([href='javascript:show_form(\'dx'+Code+'\');',id='btn_dx'+Code],'Change'), ' ',
			     a([href='/laece/'+N+'/diagnoses?prolog=%5Badd%3Ddediagnosis%28%27'+Code+'%27%2C'+UserDisease3+'%29%5D&flash=Diagnosis%20deleted'],'Delete')
			    ]
	      ),
	      div([class=invisible,id=dx+Code],
		[
		 form([action='/laece/'+N+'/change_diagnosis',method=post],
		      [
		       input([name=code,type=hidden,value=Code],[]),
		       input([name=newdescription,type=text,size=20,value=UserDisease],[]),
		       input([type=submit,value='Submit'])
		      ])
		])]							 							 
	    ),
	print_diagnoses_list(N,T).

print_diagnoses_list(_,[])-->[].

disease_name(Code,UserDisease,D2):-
	icd10(Code,IcdName),
	 End=[' (',Code,')'],
	(UserDisease== ''  ->D2=[IcdName|End];D2=[IcdName,' - ',UserDisease|End]).


reply(Request,[change_diagnosis]):-
	memberchk(patient=N,Request),
	memberchk(newdescription=UserDisease,Request),
	memberchk(code=Code,Request),
	assert_patient(N,diagnosis(Code,UserDisease)),
	reply([flash='Diagnosis changed'|Request],[diagnoses]).

html_display(diagnosis(Code,Text))-->{disease_name(Code,Text,DN),append(DN,[' diagnosed'],D3)},
	html(D3).
html_display(dediagnosis(Code,Text))-->{disease_name(Code,Text,DN),append(DN,[' removed'],D3)},
	html(D3).











