%   medications module
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

:- use_module(library(sgml)).
:- use_module(library(debug)).
:- use_module(library(lists)).

:- use_module(src(db)).
:- use_module(src(latex)).

% file of drug(GName,Dose,Form,DefaultInstr,PBS) and brand(GName,Brand).
:- consult(src('medlist.pl')).
% file of PBS Authority summaries
:- consult(src('brief_pbs_texts.pl')).
% file of
% pbs(Code,Chapter,PBS,PBSQty,PBSRpt,Mode)
% :- consult('pbs_data.pl').

:- dynamic script_print_pending/2.


completion(P,Query,cmdline,[script=Script],submit_now,
   '<span class="compl_stem">Script</span> ~a ~a ~a ~s ~a ~a + ~a (~s)'-[Name,Form,Dose,InstrL,Comment,Qty,Rpt,PBSName],
    editdrug):-
	drug_query(P,Query,Script,PBSName),
	Script=rx(Name,Form,Dose,Instr,Qty,Rpt,_PBSCode,_AuthCode,Comment),
	instr_to_latin(Instr,InstrL).

drug_query(P,Query,rx(Name,Form,Dose,Instr2,Qty,Rpt,PBSCode,AuthCode,Comment),PBSName):-
	findall(D1,query_name(Query,D1),Bag1),
	findall(D2,query_dose(Bag1,Query,D2),Bag2),
	findall(D3,query_form(Bag2,Query,D3),Bag3),
	drug_remainder(Bag1,Bag2,Bag3,Query,FinalBag,Remainder),
	parse_instr(Remainder,Instr,Remainder2),
	parse_qty_rpt(Remainder2,Qty,Rpt,Remainder3),
	concat_atom(Remainder3,' ',Comment),
	length(FinalBag,BagLen),
	member(drug(Name,Dose,Form,DefaultInstr,PBS),FinalBag),
	(   BagLen>1 ->
	         once(find_pbs_items(P,PBS,Qty,Rpt,PBSCode,AuthCode,PBSName))
	;   
	          find_pbs_items(P,PBS,Qty,Rpt,PBSCode,AuthCode,PBSName)
	),
	(   Instr==null  ->
	        Instr2=DefaultInstr
	;   
	        Instr2=Instr
	).

query_name([NameStem|_],drug(Name,Dose,Form,DefaultInstr,PBS)):-
	drug(GName,Dose,Form,DefaultInstr,PBS),
	(   Name=GName;brand(GName,Name)),
	sub_atom(Name,0,_,_,NameStem).

query_dose(Bag,[_NameStem,DoseStem|_],drug(Name,Dose,Form,Defaultinstr,PBS)):-
	member(drug(Name,Dose,Form,Defaultinstr,PBS),Bag),
	sub_atom(Dose,0,_,_,DoseStem).

query_form(Bag,[_NameStem,_DoseStem,FormStem|_],drug(Name,Dose,Form,Defaultinstr,PBS)):-
	member(drug(Name,Dose,Form,Defaultinstr,PBS),Bag),
	sub_atom(Form,0,_,_,FormStem).

%%   drug_remainder(+Bag1,+Bag2,+Bag3,+Query,-BagFinal,-Remainder).
% determine the remainder (the terminal component of the drug-phrase which does
% not play a role in selecting the drug)

% just the drug-name
drug_remainder([H|T],[],[],[_NameStem|Remainder],[H|T],Remainder).
% the name and the dose selectors
drug_remainder([_|_],[H|T],[],[_NameStem,_DoseStem|Remainder],[H|T],Remainder).
% all three
drug_remainder([_|_],[_|_],[H|T],[_,_,_|Remainder],[H|T],Remainder).

%%	parse_instr(+Query,-Instr,-Rest).
% parse the remainder (supra vide) for understandable instructions,
% returning a compound encapsulating them
parse_instr([X,mane,Y,nocte|Rest],mn(X,Y),Rest):-
	number(X),number(Y),!.

parse_instr([X,m,Y,n|Rest],nm(X,Y),Rest):-
	number(X),number(Y),!.

parse_instr([X,mane,',',Y,nocte|Rest],nm(X,Y),Rest):-
	number(X),number(Y),!.

parse_instr([X,mane,Y,midi|Rest],mm(X,Y),Rest):-
	number(X),number(Y),!.

parse_instr([X,mane,',',Y,midi|Rest],mm(X,Y),Rest):-
	number(X),number(Y).

parse_instr([A,'/',B,'/',C,'/',D|Rest],german(A,B,C,D),Rest):-
	number(A),number(B),number(C),number(D),!.

parse_instr([q,N,h|Rest],qxh(N,1),Rest):-
	integer(N),!.

parse_instr([X,Drops,q,N,h|Rest],qxh(N,X),Rest):-
	integer(N),integer(X),drops(Drops),!.

parse_instr([X,Drops,'.',q,N,h|Rest],qxh(N,X),Rest):-
	integer(N),integer(X),drops(Drops),!.


parse_instr([X,q,N,h|Rest],qxh(N,X),Rest):-
	integer(N),integer(X),!.

parse_instr([X,Y,'-',weekly|Rest],weekly(Y,X),Rest):-
	integer(X),integer(Y),!.


parse_instr([Freq|Rest],Instr,Rest):-
	freq(Freq,1,Instr),!.

parse_instr([X,Freq|Rest],Instr,Rest):-
	number(X),
	freq(Freq,X,Instr),!.

% empty list
parse_instr([],null,[]):-!.

% fallback if tokens unparseable
parse_instr(Rest,as_directed,Rest).

% words for 'drops'
drops(drops).
drops(drop).
drops(gutt).
drops(guttae).

%% freq(+Token,+Number,-Instr).
% facts matching simple drug frequency tokens to instructions

freq(mane,X,m(X)).
freq(nocte,X,n(X)).
freq(midi,X,midi(X)). % rare, mainly for frusemide
freq(vesper,X,vesper(X)). % vesper=the evening in Latin, never seen this used, only for completeness
freq(bd,X,bd(X)).
freq(bid,X,bd(X)).
freq(bds,X,bd(X)).
freq(tds,X,tds(X)).
freq(tid,X,tds(X)).
freq(qid,X,qid(X)).
freq(qds,X,qid(X)).
freq(weekly,X,weekly(1,X)).
freq(fortnightly,X,weekly(2,X)).
freq(monthly,X,weekly(4,X)).

%%   parse_qty_rpt(+Query,-Qty,-Rpt,-Rest).
% Parse the query string and extract specification of drug quantity and repeats
% If unsuccesful Qty and Rpt stay unbound
% Rest s unparsed tokens

parse_qty_rpt([Qty,'+',Rpt|Rest],Qty,Rpt,Rest):-
	integer(Qty),integer(Rpt),!.

parse_qty_rpt([Qty,x,Rpt|Rest],Qty,Rpt,Rest):-
	integer(Qty),integer(Rpt),!.

parse_qty_rpt([Qty|Rest],Qty,_Rpt,Rest):-
	integer(Qty),!.

parse_qty_rpt([','|Query],Qty,Rpt,Rest):-
	parse_qty_rpt(Query,Qty,Rpt,Rest),nonvar(Qty).

% fallback option
parse_qty_rpt(Rest,_,_,Rest).


latin_english(prn,'as required').
latin_english(os,'left eye'). % Oculus Sinster
latin_english(od,'right eye'). % Oculus Dexter
latin_english(ou,'both eyes'). % Oculus Universalis
latin_english(au,'both ears'). % Auriculus Universalis
latin_english(as,'left ear'). 
latin_english(ad,'right ear'). 
latin_english(pa,'with water'). % per aqua
latin_english(pl,'with milk'). % per lacte
latin_english(pp,'after meals'). % post prandium

%%   instr_to_Latin(+Instruction,-Latin).
% take to parsed instruction and return Latin description

instr_to_latin(I,S):-
	instr_to_latin(I,F,L),
	format(string(S),F,L).

instr_to_latin(bd(X),'~d bd',[X]).
instr_to_latin(tds(X),'~d tds',[X]).
instr_to_latin(qid(X),'~d qid',[X]).
instr_to_latin(weekly(Y,X),'~d ~d-weekly',[X,Y]).
instr_to_latin(mn(X,Y),'~d mane, ~d nocte',[X,Y]).
instr_to_latin(mm(X,Y),'~d mane, ~d midi',[X,Y]).
instr_to_latin(m(X),'~d mane',[X]).
instr_to_latin(n(X),'~d nocte',[X]).
instr_to_latin(midi(X),'~d midi',[X]).
instr_to_latin(vesper(X),'~d vesper',[X]).
instr_to_latin(qxh(X,Y),'~d q~dh',[Y,X]).
instr_to_latin(german(A,B,C,D),'~d/~d/~d/~d',[A,B,C,D]).
instr_to_latin(as_directed,'as directed',[]).

perday(bd(X),N):-
	N is X*2.
perday(tds(X),N):-
	N is X*3.
perday(qid(X),N):-
	N is X*4.
perday(mn(X,Y),N):-
	N is X+Y.
perday(mm(X,Y),N):-
	N is X+Y.
perday(german(A,B,C,D),N):-
	N is A+B+C+D.
perday(mane(X),X).
perday(midi(X),X).
perday(nocte(X),X).
perday(vesper(X),X).

instr_to_english(I,S):-
	instr_to_english(I,F,L),
	format(string(S),F,L).

instr_to_english(bd(X),'~d TWICE a day',[X]).
instr_to_english(tds(X),'~d THREE times a day',[X]).
instr_to_english(qid(X),'~d FOUR times a day',[X]).
instr_to_english(weekly(Y,X),'~d EVERY ~d WEEKS',[X,Y]).
instr_to_english(mn(X,Y),'~d in the MORNING and ~d in the EVENING',[X,Y]).
instr_to_english(mm(X,Y),'~d in the MORNING and ~d at MIDDAY',[X,Y]).
instr_to_english(m(X),'~d in the MORNING',[X]).
instr_to_english(n(X),'~d in the EVENING',[X]).
instr_to_english(midi(X),'~d at MIDDAY',[X]).
instr_to_english(vesper(X),'~d in the AFTERNOON',[X]).
instr_to_english(qxh(X,Y),'~d EVERY ~d HOURS',[Y,X]).
instr_to_english(german(A,B,C,D),'~d at BREAKFAST, ~d at LUNCH, ~d at DINNER, ~d at BEDTIME',[A,B,C,D]).
instr_to_english(as_directed,'as directed',[]).

%%	find_pbs_items(+Patient,+PBSId,?Qty,?Rpt,-PBSMode).
% PBS searching

find_pbs_items(P,PBS,Qty,Rpt,Code,AuthCode,Name):- 
	pbs(Code,Chapter,PBS,PBSQty,PBSRpt,Mode),
	ignore(Qty=PBSQty),ignore(PBSRpt=Rpt),
	Qty=<PBSQty,Rpt=<PBSRpt, 
	chapter(P,Chapter,ChapterName1,ChapterName2,Link),
	pbs_name(Code,ChapterName1,ChapterName2,Link,Mode,L,S,AuthCode),
	format(string(Name),L,S).

find_pbs_items(_P,PBS,Qty,Rpt,Code,required,'PBS Auth (increased qty.)'):-
	once((pbs(Code,Chapter,PBS,PBSQty,PBSRpt,Mode),
	          Chapter\='PI',
	          Mode\=authority(_,_),
	          Qty>PBSQty)),
	ignore(PBSRpt=Rpt).
	
% offer option of private script
find_pbs_items(_P,PBS,Qty,Rpt,private,null,'Private'):-
	once((pbs(_Code,Chapter,PBS,PBSQty,PBSRpt,_Mode),
	           Chapter\='PI')), % private-only don't need a private option
	ignore(Qty=PBSQty),ignore(Rpt=PBSRpt).

pbs_name(_Code,ChapterName1,ChapterName2,no,unrestricted,'~a ~a',[ChapterName1,ChapterName2],null).
pbs_name(Code,ChapterName1,ChapterName2,yes,unrestricted,'<a href="/laece/nopatient/druginfo/~a">~a ~a</a>',[Code,ChapterName1,ChapterName2],null).
pbs_name(Code,ChapterName1,_,_,authority(TextNo,Text),'<a href="/laece/nopatient/druginfo/~a">~a Auth:~a</a>',[Code,ChapterName1,BriefText],required):-
	once(brief_pbs_text(TextNo,Text,BriefText)).
pbs_name(Code,ChapterName1,_,_,restricted(TextNo,Text),'<a href="/laece/nopatient/druginfo/~a">~a Restrict:~a</a>',[Code,ChapterName1,BriefText],null):-
	once(brief_pbs_text(TextNo,Text,BriefText)).
pbs_name(Code,ChapterName1,_,_,streamlined(TextNo,Text,AuthCode),'<a href="/laece/nopatient/druginfo/~a">~a Auth:~a</a>',[Code,ChapterName1,BriefText],AuthCode):-
	once(brief_pbs_text(TextNo,Text,BriefText)).



%% chapter(+P,+Chapter,-ChapterName1,-ChapterName2,-Link).
% Information about PBS cahpters. Fails if patient not eligilbe for this chapter
% Link should be 'yes' if unrestricted items should also be linked to PBS info in
% the result list

chapter(P,'R1','RPBS','',no):-
      veteran(P).
chapter(_P,'PL','PBS','Pall. Care',yes).
	%diagnosis(P,_,_,DCode,_), % FIXME: auto-detection for palliative status? how?
	%palliative(DCode).	
chapter(_,'GE','PBS','',no). % GEneral items
chapter(_,'SB','PBS','Special benefit',yes).
chapter(_P,'CI','PBS','Ileostomy/Colostomy',yes).
	%diagnosis(P,_,_,DCode,_),
	%(  ileostomy(DCode);colostomy(DCode)).
chapter(_P,'PQ','PBS','Para/Quadraplegia',yes).
	%diagnosis(P,_,_,DCode,_),
	%(    paraplegia(DCode);quadriplegia(DCode)).
chapter(_,X,'Sect. 100','',yes):-
	memberchk(X,['CS','CT','HS','MF','GH','IF','SY']).
               % FIXME: should be divided up in separate section 100 chapters where this makes sense
chapter(_,'MF','PBS','Opiate Depend.',yes).
chapter(_,'PI','Private script ','',no).
% Of course there is no such PBS chapter, this is to allow entries for drugs 
% with no true PBS entry.

%% brief_pbs_text(+TextNo,+Text,-BriefText).
%  compute a brief text (max couple of words) for the Authority text
brief_pbs_text(TextNo,_,BriefText):-
	% use a set of pre-defined facts in a separate DB
	brief_pbs_text(TextNo,BriefText).
brief_pbs_text(_,Text,BriefText):-
	% no text found, so use start of text
	sub_atom(Text,0,12,_,BriefText).
brief_pbs_text(_,Text,Text).
               % if the former fails, because text is less than 12 chars (unlikely)

% receive new drug order

reply(Request,[newdrug]):-
	memberchk(patient=N,Request),
	N\=nopatient,
	memberchk(rx=Rx,Request),
	assertion(functor(Rx,rx,9)), % sanity check
	assert_patient(N,Rx),
	asserta(script_print_pending(N,Rx)),
	reply(Request,[medlist]).

% display a web form requesting the authorities
authority_form(Request):-
	memberchk(patient=N,Request),
	memberchk(scripts=Scripts,Request),
	format(atom(Prolog),'~q',[[scripts=Scripts]]),
	reply_page(Request,'Authority required',
	      form([action='/laece/'+N+'/recieve_authority',
		 enctype='application/x-www-form-urlencoded',
		 method='POST'],[
		      	    input([type=hidden,name=prolog,value=Prolog],[]),
		                  \one_script_auth(Request,Scripts),
			    p([],[input([type=submit,value='Submit'],[])])
				])).

one_script_auth(Request,[script(No,Rxs,_Chapter)|T])-->
	(one_drug_auth(Request,No,Rxs);[]),
	one_script_auth(T).
one_script_auth(_,[])-->[].

one_drug_auth(Request,No,[Rx|T])-->
	{
	     Rx=rx(Name,Form,Dose,Instr,Qty,Rpt,PBSCode,required,_Comment),!,
	     once((perday(Instr,PerDay);PerDay='--')),
	     findall(Text,pbs(PBSCode,_Chapter,_PBS,_PBSQty,_PBSRpt,authority(_No,Text)),Texts),
	     once(((Texts==[],Texts2=['Increased quantity']);Texts=Texts2))
	},
	html([
	    h2('Authority required'),
	    p([b('Drug:'),Name,' ',Form,' ',Dose]),
	    p([b('Script No.'),No]),
	    p([b('Amount per day:'),PerDay]),
	    h3('Authority Text'),					 
	    \print_auth(1,Texts2),
	    p([b('Authority code:'),input([type=text,name=authority_code_+PBSCode],[])]),
	    p([b('Quantity:'),input([type=text,name=quantity_+PBSCode,value=Qty],[])]),
	    p([b('Repeats:'),input([type=text,name=repeats_+PBSCode,value=Rpt],[])])
	     ]),
	one_drug_auth(Request,No,T).
one_drug_auth(R,No,[_|T])-->one_drug_auth(R,No,T). % not authority drug, so skip
one_drug_auth(_,_,[])-->[].

print_auth(N,[H|T])-->
	html(p([N,'. ',\[H]])),{N2 is N+1},print_auth(N2,T).
print_auth(_,[])-->[].

% predicates for the print engine

command([print,X],'print prescriptions - print pending prescriptions','print_scripts'):-
	member(X,[drugs,scripts,prescriptions]).

reply(Request,[print_scripts]):-
	memberchk(patient=N,Request),
	findall(Script,script_print_pending(N,Script),ScriptBag),
	filter_auths(ScriptBag,NonAuths,Auths),
	maplist(get_chapter,ScriptBag2,NonAuths),
	maplist(get_chapter,Auths,Auths2),
	keysort(ScriptBag2,ScriptBag3),
	split_meds_list(ScriptBag3,[],ScriptBag4),
	append(ScriptBag4,Auths2,ScriptBag5),
	maplist(make_script,ScriptBag5,ScriptBag6),
	(   Auths==[] ->
	     print_scripts(Request,ScriptBag6)
	;   
	    authority_form([scripts=ScriptBag6|Request])).

%%	make_script(+In,-Out).
% converts list of drugs into script term
% actually just gets a script number
% FIXME: currently a dummy value, need a sequential
% number generator
make_script(In,script(No,Out,Chapter)):-
	No='123456', % FIXME: use sequential values
	In=[Chapter-_|_],
	maplist(strip_chapter,In,Out).
	
%% filter_auths(OriginalList,NonAuths,Auths).
% separates authority and non-authority drugs
% authority drugs go in one-item lists because they will be one-drug
% scripts

filter_auths([],[],[]).
filter_auths([H|T1],[H|T2],L):-
	H=rx(_Name,_Form,_Dose,_Instr,_Qty,_Rpt,_PBSCode,AuthCode,_Comment),
	AuthCode==null,
	filter_auths(T1,T2,L).
filter_auths([H|T1],L,[[H]|T2]):-
	H=rx(_Name,_Form,_Dose,_Instr,_Qty,_Rpt,_PBSCode,AuthCode,_Comment),
	AuthCode\=null,
	filter_auths(T1,L,T2).

% gets drug chapter fr sorting out scripts (all drugs on a script must
% be same chapter)

get_chapter('PI'-Rx,Rx):-
	Rx=rx(_,_,_,_,_,_,private,_,_).
get_chapter(Chapter-Rx,Rx):-
	    Rx=rx(_,_,_,_,_,_,PBSCode,_,_),
	    pbs(PBSCode,Chapter,_PBS,_PBSQty,_PBSRpt,_Mode).

%%	split_meds_list(+In,-Temp,-Final).
% splits a sorted list of meds by chapter
split_meds_list([],[],[]).
split_meds_list([],[H|T],[[H|T]]).
split_meds_list([H|T],[],L):-!,
	split_meds_list(T,[H],L).
split_meds_list([C1-Rx1|T],[C2-Rx2|T2],L):-
	C1==C2,
	settings:script_max(ScriptMax),
	X is ScriptMax-1,
	length(T2,N),N<X,!,
	split_meds_list(T,[C1-Rx1,C2-Rx2|T2],L).
split_meds_list([H|T],L1,[L1|L2]):-
	split_meds_list(T,[H],L2).

strip_chapter(_Chapter-Rx,Rx).

% print_script(+Request,+ScriptBag).
% print some scripts
print_scripts(Request,[script(No,Rxs,Chapter)|T]):-
	memberchk(patient=N,Request),
	demo(N,Firstname,Lastname,Dob,Address,Postcode,_Telephone,Medicare,DVA,CRN),
	latex([documentclass(article),begin(document),
	       textbf('Patient Details:'),Firstname,Lastname,nl,
	       'DOB:',Dob,nl,Address,' ',Postcode,nl,
	       \script_patient_number(Medicare,DVA,CRN,Chapter),
	       textbf('Script No.: '),No,p,
	       \print_one_drug(Rxs),
	      end(document)]),
	print_scripts(Request,T).
print_scripts(_,[]).

script_patient_number(Medicare,_,CRN,Chapter)-->
	{Chapter\='PI',CRN\=none,Chapter\='R1'},
	latex([textbf('Medicare: '),Medicare,textbf(' CRN:'),CRN,nl]).

script_patient_number(Medicare,_,none,Chapter)-->
	{Chapter\='PI',Chapter\='R1'},
	latex([textbf('Medicare: '),Medicare,nl]).


script_patient_number(_,_,_,'PI')-->
	latex([textbf('**PRIVATE SCRIPT**')]).


script_patient_number(_,DVA,_,'R1')-->
	latex([textbf('DVA number: '),DVA,nl]).

print_one_drug([rx(_Name,_Form,_Dose,_Instr,_Qty,_Rpt,_PBSCode,AuthCode,_Comment),
	AuthCode\=null,
	filter_auths(T1,L,T2).

% gets drug chapter fr sorting out scripts (all drugs on a script must
% be same chapter)

get_chapter('PI'-Rx,Rx):-
	Rx=rx(_,_,_,_,_,_,private,_,_).
get_chapter(Chapter-Rx,Rx):-
	    Rx=rx(_,_,_,_,_,_,PBSCode,_,_),
	    pbs(PBSCode,Chapter,_PBS,_PBSQty,_PBSRpt,_Mode).

%%	split_meds_list(+In,-Temp,-Final).
% splits a sorted list of meds by chapter
split_meds_list([],[],[]).
split_meds_list([],[H|T],[[H|T]]).
split_meds_list([H|T],[],L):-!,
	split_meds_list(T,[H],L).
split_meds_list([C1-Rx1|T],[C2-Rx2|T2],L):-
	C1==C2,
	settings:script_max(ScriptMax),
	X is ScriptMax-1,
	length(T2,N),N<X,!,
	split_meds_list(T,[C1-Rx1,C2-Rx2|T2],L).
split_meds_list([H|T],L1,[L1|L2]):-
	split_meds_list(T,[H],L2).

strip_chapter(_Chapter-Rx,Rx).

% print_script(+Request,+ScriptBag).
% print some scripts
print_scripts(Request,[script(No,Rxs,Chapter)|T]):-
	memberchk(patient=N,Request),
	demo(N,Firstname,Lastname,Dob,Address,Postcode,_Telephone,Medicare,DVA,CRN),
	latex([documentclass(article),begin(document),
	       textbf('Patient Details:'),Firstname,Lastname,nl,
	       'DOB:',Dob,nl,Address,' ',Postcode,nl,
	       \script_patient_number(Medicare,DVA,CRN,Chapter),
	       textbf('Script No.: '),No,p,
	       \print_one_drug(Rxs),
	      end(document)]),
	print_scripts(Request,T).
print_scripts(_,[]).

script_patient_number(Medicare,_,CRN,Chapter)-->
	{Chapter\='PI',CRN\=none,Chapter\='R1'},
	latex([textbf('Medicare: '),Medicare,textbf(' CRN:'),CRN,nl]).

script_patient_number(Medicare,_,none,Chapter)-->
	{Chapter\='PI',Chapter\='R1'},
	latex([textbf('Medicare: '),Medicare,nl]).


script_patient_number(_,_,_,'PI')-->
	latex([textbf('**PRIVATE SCRIPT**')]).


script_patient_number(_,DVA,_,'R1')-->
	latex([textbf('DVA number: '),DVA,nl]).

print_one_drug([rx(Name,Form,Dose,Instr,Qty,Rpt,_,AuthCode,Comment)|T])-->
	latex,
	print_one_drug(T).
print_one_drug(T)-->[]..


% queries for summary display

current_drugs(N,script(Name,Form,Dose,Instr,Pbs,Qty,Rpt)):-
	get_time(Now),
	p(N,Time,_,script(Name,Form,Dose,Instr,Pbs,Qty,Rpt)),
	Age is (Now-Time)-((Rpt+1)*2419200), % allow one month for each repeat
	Age<0, % script still current.
	not(script_cancelled(Time,N,Name,Form,Dose)).

script_cancelled(Time,N,Name,Form,Dose):-
	p(N,Time2,_,cancelled_script(Name2,Form,Dose,_Reason)),
	Time2>Time,
	(Name2=Name;(generic(Name2,G),generic(Name,G))).
	


summary(N,Item,1):-
	current_drugs(N,Item).
link_summary(script(Name,_,_,_,_,_,_),Disease):-
	drug(G,_,_,_,PBSCode,Brands),
	(Name=G;memberchk(Name,Brands)),
	pbs(_G,_F,PBSCode,_Qty,_Rpt,_Chapter,_Auth,ATC),
	ldd(ATC2,Disease),sub_atom(ATC,0,_,_,ATC2).

display_summary(N,script(Name,Form,Dose,Instr,_Pbs,_Qty,_Rpt))-->
	{
	 print_drug(Name,NameS),
	 print_dose(Dose,DoseS),
	 instr_to_latin(Instr,Latin),
	 url_term(DrugS,drug(Name,Form,Dose))
	},
	html([a([href='/patient/'+N+'/showdrug/'+DrugS],[NameS,' ',Form,' ',DoseS,' ',Latin])]).

% screen for displaying a med's history

patient_reply(N,['showdrug',DrugS],_Reply):-
	url_term(DrugS,drug(Name,Form,Dose)),
	findall(line(Time,User,Instr,Pbs,Qty,Rpt),p(N,Time,User,script(Name,Form,Dose,Instr,Pbs,Qty,Rpt)),Drugs),
	 print_drug(Name,NameS),
	 print_dose(Dose,DoseS),
	 format(atom(DrugName),'~a ~a ~a'-[NameS,Form,DoseS]),
	 patient_page(N,DrugName, [
	    h2(DrugName),
	    table(\display_drug(Drugs)),
	    p(form([action='/patient/'+N+'/represcribe',method=post,enctype='application/x-www-form-urlencoded'],
		 [input([type=submit,name=noprint,value='Re-prescribe'],[]),
		  input([type=hidden,name=drug,value=DrugS],[]),
		  input([type=submit,name=print,value='Re-prescribe & Print'],[])])),
	    p(form([action='/patient/'+N+'/cancel_drug',method=post,enctype='application/x-www-form-urlencoded'],
	           [input([type=hidden,name=drug,value=DrugS],[]),
		    input([type=submit,value='Cancel'],[]),
		    'Reason: ',
		    input([type=text,name=reason,size=10],[])]))]).


% utility routines for loading and processing PBS's XML

xfind(PBS,Name,Attr,Content,Level,Max):-Level<Max,L2 is Level+1,member(element(_Name2,_Attr2,Content2),PBS),xfind(Content2,Name,Attr,Content,L2,Max).
xfind(PBS,Name,Attr,Content,_Level,_Max):-member(element(Name,Attr,Content),PBS).
xfind(PBS,Name,Content,Max):-xfind(PBS,Name,_Attr,Content,0,Max).

pbs:- 
    load_xml_file('/home/ian/pbs.xml',PBS),
    asserta(pbs(PBS)).
write_medlist:-
    open('medlist_new.pl',write,NewMeds),
    ignore(print_newdrugs(NewMeds)),
    close(NewMeds).
write_pbs_data:-
    open('pbs_data.pl',write,Pbs),
    ignore(print_pbs(Pbs)),
    close(Pbs).

alltags(Y):-
	pbs(X),xfind(X,'pbs:ready-prepared',C,5),xfind(C,Y,_,0).

print_newdrugs(F):-
    setof(drug(G,D),list_drugs(_,G,D,_,_),B),
    member(drug(G,D),B),
    setof(Brand,get_brands(G,D,Brand),Brands),
    setof(Code,get_codes(G,D,Code),Codes),
    format(F,'drug(~q,~q,,[],~q,~q).~n',[G,D,Codes,Brands]),
    format('drug(~q,~a,,[],~q,~q).~n',[G,D,Codes,Brands]),
    fail.

get_brands(G,D,Brand):-
    list_drugs(_Prep,G,D,_,Brands),
    member(Brand,Brands).

get_codes(G,D,Code):-
    list_drugs(Prep,G,D,_,_),
    xfind(Prep,'pbs:code',[Code|_],1).

print_pbs(F):-
    list_drugs(Prep,G,D,_,_),
    list_pbs(Prep,Code,Chapter,Qty,Rpts,Modes,ATC),
    format(F,'pbs(~q,~q,~q,~q,~q,~q,~q,~q).~n',[G,D,Code,Qty,Rpts,Chapter,Modes,ATC]),
    format('pbs(~q,~q,~q,~q,~q,~q,~q,~q).~n',[G,D,Code,Qty,Rpts,Chapter,Modes,ATC]),
    fail.

list_generics(G):-pbs(PBS),xfind(PBS,'pbs:drug',_,C,0,20),xfind(C,'db:title',_,G,0,0).

code_exists(Code):-
	drug(_Name,_Form,_Dose,_Intrs,Codes,_B),
	(memberchk(Code,Codes);Code=Codes).

list_drugs(Prep,Generic2,Description2,Route,Brands):-
    pbs(PBS),xfind(PBS,'pbs:drug',Drug,20),xfind(Drug,'db:title',[Generic|_],0),
    xfind(Drug,'pbs:ready-prepared',Prep,1),
    xfind(Prep,'pbs:form-strength',Form,1),
    once(xfind(Form,'pbs:label',[Description|_],1)),
    xfind(Prep,'pbs:administration',[Admin|_],1),
    sub_atom(Admin,51,_,0,Route),
    downcase_atom(Generic,Generic2),
    downcase_atom(Description,Description2),
    findall(Brand,get_brand(Prep,Brand),Brands).

list_pbs(Prep,Code,Chapter,Qty,Rpts,Modes,ATC):-
    pbs(PBS),
    xfind(Prep,'pbs:code',[Code|_],1),
    xfind(PBS,'pbs:section',Attrs,Section,0,4),
    mode(ModeTag,ModeIn),
    xfind(Section,ModeTag,Info,3),
    xfind(Info,'pbs:code',[Code|_],1),
    memberchk('xml:id'=Chapter,Attrs),
    xfind(Info,'pbs:maximum-quantity',[SQty|_],1),
    xfind(Info,'pbs:number-repeats',[SRpts|_],1),
    atom_number(SQty,Qty),atom_number(SRpts,Rpts),
    findall(Mode,get_restrict(Info,ModeIn,Mode),Modes),
    xfind(Info,'pbs:ATC-reference',Attrs2,_,0,2),
    memberchk('xlink:href'=Href,Attrs2),
    sub_atom(Href,1,_,0,ATC).
    
get_brand(Prep,Brand2):-
    xfind(Prep,'pbs:brand',B,1),
    xfind(B,'db:title',[Brand|_],1),
    downcase_atom(Brand,Brand2).

mode('pbs:authority-required',auth).
mode('pbs:restricted',restricted).
mode('pbs:unrestricted',unrestricted).




get_restrict(_,unrestricted,auth(unrestricted,'','')).

get_restrict(Info,auth,auth(contact,AuthCode,Text)):-
    xfind(Info,'pbs:indication',I,2),
    \+is_streamlined(I),
    extract_authtext(I,Text,AuthCode).

get_restrict(Info,auth,auth(streamlined,AuthCode,Text)):-
    xfind(Info,'pbs:indication',I,2),
    is_streamlined(I),
    extract_authtext(I,Text,AuthCode).

get_restrict(Info,restricted,auth(restricted,AuthCode,Text)):-
    xfind(Info,'pbs:indication',I,2),
    extract_authtext(I,Text,AuthCode).
    
is_streamlined(I):-
    xfind(I,'pbs:authority-method',[AuthMethod|_],3),
    sub_atom(AuthMethod,_,_,0,'no-contact').
    
extract_authtext(I,Text,AuthCode):-
    xfind(I,'pbs:code',[AuthCode|_],1),
    with_output_to(atom(Text),ignore(authtext_line(I))).
    
authtext_line(I):-
    xfind(I,'db:para',Attr,[Text|_],0,4),
    \+memberchk(role=legal,Attr),atom(Text),format('~a~n',[Text]),fail.

add_restrict(Text,unrestricted,restricted(0,Text)).

add_restrict(Text,streamlined(AuthCode,TextA),streamlined(AuthCode,Text2)):-
	concat_atom([TextA,'\n',Text],Text2).

add_restrict(Text,auth(AuthCode,TextA),auth(AuthCode,Text2)):-
	concat_atom([TextA,'\n',Text],Text2).

add_restrict(Text,restricted(AuthCode,TextA),restricted(AuthCode,Text2)):-
	concat_atom([TextA,'\n',Text],Text2).

add_restricts(Text,[H1|L1],[H2|L2]):-
	add_restrict(Text,H1,H2),add_restricts(Text,L1,L2).

add_restricts(_,[],[]).



















