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

% file of drug(GenericName,[form(FormDescription,Unit,[dose(Dose,PBSItemCode)])]).
:- consult('medlist.pl').
% file of
% pbs(GenericName,PBSForm,ItemNo,MaxQuantity,MaxRepeats,[Availability]).
:- consult('pbs_data.pl').


completion(P,Query,cmdline,newscript(GenericName,Name,Form,Dose),submit_now,
   '<span class="compl_stem">Script</span> ~a ~a ~a</em>'-[PName,Form,SDose],'/patient/~a/editdrug'-[P]):-
    drug(GenericName,Form,Dose,_Instr,_PBSCodes,Brands),
    (Name=GenericName;member(Name,Brands)),
    once((Name=[SName|_];SName=Name)),
    drug_query(Query,SName,Form,Dose),
    print_dose(Dose,SDose),
    print_drug(Name,PName).

drug_query([SDrug],Name,_,_):-
	sub_atom(Name,0,_,_,SDrug).

drug_query([SDrug,SForm],Name,Form,_):-
	sub_atom(Name,0,_,_,SDrug),
	sub_atom(Form,_,_,_,SForm).

drug_query([SDrug,SDose],Name,_,Dose):-
	sub_atom(Name,0,_,_,SDrug),	
	integer(SDose),
	once((
	   (Dose=[H|_],arg(1,H,SDose));
	   arg(1,Dose,SDose)
	)).



drug_query([SDrug,SForm,SDose],Name,Form,Dose):-
	sub_atom(Name,0,_,_,SDrug),
	sub_atom(Form,_,_,_,SForm),
	integer(SDose),
	once((
	   (Dose=[H|_],arg(1,H,SDose));
	   arg(1,Dose,SDose)
	)).

print_dose(Dose,SDose):- functor(Dose,Unit,_),Unit\='.',arg(1,Dose,N),concat_atom([N,Unit],SDose).

print_dose(Dose,SDose):- is_list(Dose),maplist(print_dose,Dose,DL),concat_atom(DL,-,SDose).

print_drug(Drug,Drug):-atom(Drug).

print_drug(Drug,DrugS):- is_list(Drug),concat_atom(Drug,'-',DrugS).

generic(N,G):-
	drug(G,_F,_D,_I,_PBS,Brands),member(N,Brands).
generic(G,G).

patient_process(_P,Params,script(Name,Form,Dose,Instr2,Modes)):-
	memberchk(cmdline=Cmd,Params),
	termchk(cmdline_data=newscript(GenericName,Name,Form,Dose),Params),
	parse_command(Cmd,PCmd),
       	ignore(script_extra(PCmd,Instr,Qty,Rpt)),
	drug(GenericName,Form,Dose,DInstr,PBSCodes,_Brands),
	ignore(DInstr=[m(1)]),
	ignore(DInstr=Instr), % use default instructions if unbound
	%Instr=[H|T],
	%once((compute_dose(P,H,H2);H=H2)),
	Instr2=Instr,
	findall(mode(Qty,Rpt,Mode,PBSCode),get_modes(PBSCodes,Qty,Rpt,Mode,PBSCode),ModesU),
	sort(ModesU,Modes1),
	make_private(ModesU,Private), % private script always an option
	reverse([Private|Modes1],Modes). % always the last option
	

get_modes(PBSCodes,Qty,Rpt,Mode,PBSCode):-
	(member(PBSCode,PBSCodes);(atom(PBSCodes),PBSCode=PBSCodes)),
	(
	         pbs(_,_,PBSCode,MaxQuantity,MaxRepeats,Chapter,PBSAvailablities,_),
	         memberchk(Chapter,['GE','SB','CI','PQ','R1','PL','CS','CT','HS','MF','GH','MD','IF','SY']),
		 ignore(Rpt=MaxRepeats),Rpt=<MaxRepeats,
	         ignore(MaxQuantity=Qty),Qty=<MaxQuantity,
	         member(Mode,PBSAvailablities)   
	).
	
make_private([],mode(0,0,auth(unrestricted,'',''),'PX')).
make_private([mode(Qty,Rpt,_,_)|_],mode(Qty,Rpt,auth(unrestricted,'',''),'PX')).

script_extra([_Name,_Form,N1|Rest],Instr,Qty,Rpt):-
	number(N1),
	parse_instr(Rest,Instr,Qty,Rpt).

script_extra([_Name,N1,N2|Rest],Instr,Qty,Rpt):-
	not(number(N1)),
	not(number(N2)),
	parse_instr([N1,N2|Rest],Instr,Qty,Rpt).


script_extra([_Name,_Form,N1|Rest],Instr,Qty,Rpt):-
	not(number(N1)),
	parse_instr([N1|Rest],Instr,Qty,Rpt).

script_extra([_Name,_Form,Dose,_Unit|Rest],Instr,Qty,Rpt):-
	number(Dose),
	parse_instr(Rest,Instr,Qty,Rpt).

parse_instr([Freq|Rest],[Instr1|Instr2],Qty,Rpt):-
	freq(Freq,1,Instr1),
	parse_rest(Rest,Instr2,Qty,Rpt).

parse_instr([X,Freq|Rest],[Instr1|Instr2],Qty,Rpt):-
	number(X),
	freq(Freq,X,Instr1),
	parse_rest(Rest,Instr2,Qty,Rpt).
 

parse_instr([X,mane,Y,nocte|Rest],[m(X,Y)|Instr2],Qty,Rpt):-
	number(X),number(Y),
	parse_rest(Rest,Instr2,Qty,Rpt).

parse_instr([X,m,Y,n|Rest],[nm(X,Y)|Instr2],Qty,Rpt):-
	number(X),number(Y),
	parse_rest(Rest,Instr2,Qty,Rpt).

parse_instr([X,mane,',',Y,nocte|Rest],[nm(X,Y)|Instr2],Qty,Rpt):-
	number(X),number(Y),
	parse_rest(Rest,Instr2,Qty,Rpt).

parse_instr([X,mane,Y,midi|Rest],[mm(X,Y)|Instr2],Qty,Rpt):-
	number(X),number(Y),
	parse_rest(Rest,Instr2,Qty,Rpt).

parse_instr([X,mane,',',Y,midi|Rest],[mm(X,Y)|Instr2],Qty,Rpt):-
	number(X),number(Y),
	parse_rest(Rest,Instr2,Qty,Rpt).

parse_instr([A,'/',B,'/',C,'/',D|Rest],[german(A,B,C,D)|Instr2],Qty,Rpt):-
	number(A),number(B),number(C),number(D),
	parse_rest(Rest,Instr2,Qty,Rpt).

parse_instr([q,N,h|Rest],[qxh(N,1)|Instr2],Qty,Rpt):-
	integer(N),
	parse_rest(Rest,Instr2,Qty,Rpt).

parse_instr([X,drops,q,N,h|Rest],[qxh(N,X)|Instr2],Qty,Rpt):-
	integer(N),integer(X),
	parse_rest(Rest,Instr2,Qty,Rpt).


parse_instr([X,gutt,q,N,h|Rest],[qxh(N,X)|Instr2],Qty,Rpt):-
	integer(N),integer(X),
	parse_rest(Rest,Instr2,Qty,Rpt).


parse_instr([X,gutt,'.',q,N,h|Rest],[qxh(N,X)|Instr2],Qty,Rpt):-
	integer(N),integer(X),
	parse_rest(Rest,Instr2,Qty,Rpt).

parse_instr([X,Y,'-',weekly|Rest],[weekly(Y,X)|Instr2],Qty,Rpt):-
	integer(X),integer(Y),
	parse_rest(Rest,Instr2,Qty,Rpt).

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


parse_rest([],[],_,_).

parse_rest(Rest,Rest5,Qty,Rpt):-
	reverse(Rest,Rest2),
	parse_qty(Rest2,Qty,Rpt,Rest3), % look for quantity and repeats at the end of the string
	reverse(Rest3,Rest5). % put the rest back in the right order

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

instr_to_latin([H|T],Latin):-
	instr_to_latin(H,F,L),
	format(atom(X),F,L),
	concat_atom([X|T],' ',Latin).

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


instr_to_english([H|T],English):-
	instr_to_english(H,F,L),
	maplist(latin_english,T,T2),
	format(atom(X),F,L),
	concat_atom([X|T2],' ',English).

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
instr_to_english(german(A,B,C,D),'~d at BRWAKFAST, ~d at LUNCH, ~d at DINNER, ~d at BEDTIME',[A,B,C,D]).



parse_qty([Rpt,'x',Qty|Rest],Qty,Rpt,Rest):-
	integer(Rpt),integer(Qty).

parse_qty([Rpt,'+',Qty|Rest],Qty,Rpt,Rest):-
	integer(Rpt),integer(Qty).

parse_qty([Qty|Rest],Qty,_,Rest):-
	integer(Qty).

parse_qty(Rest,_,_,Rest).



% drug editing screen


patient_reply(N,[editdrug],script(Name,Form,Dose,Instr,Modes)):-N\=nopatient,
    print_drug(Name,NameS),
    print_dose(Dose,DoseS),
    instr_to_latin(Instr,InstrL),
    instr_to_english(Instr,InstrE),
    with_output_to(atom(DrugS),writeq(drug(Name,Form,Dose))),
    patient_page(N,'Edit Prescription',[
      h2([NameS,' ',Form,' ',DoseS]),
      form([action='/patient/'+N+'/main',enctype='application/x-www-form-urlencoded',method='POST'],
	   [
	    p(['Instructions:',input([type=text,name=instructions,size=40,value=InstrL],[])]),
	    p(['Translation:',span([id=trans],InstrE)]),
	    input([type=hidden,name=drug,value=DrugS],[]),
	    h3('Prescription type'),
	    dl([\script_types(Modes)]),
	    input([type=submit,value='Submit'],[])])
	   ]).

script_types([mode(Qty,Rpt,PBSMode,PBSCode)|T])-->
	{make_auth(PBSMode,PBSCode,Auth),
	 (pbs(_G,_F,PBSCode,_,_,Chapter,_,_);Chapter='PI'),
	 pbs_title(PBSMode,PBSTitle),
	 chapter(Chapter,ChapterName)},
	html([dt([input([type=radio,name=mode,value=Auth],[]),ChapterName|PBSTitle]),
	      dd([\pbs_body(PBSMode),
	      'Quantity:',input([type=text,name=qty+Auth,value=Qty,size=3],[]),
	      'Repeats:',input([type=text,name=rpt+Auth,value=Rpt,size=3],[])])]),
	script_types(T).
	
script_types([])-->[].
	
pbs_body(auth(contact,_,Text))-->
	html([\[Text],p(['Authority code: ',input([type=text,name=auth_code,length=7],[])])]).
pbs_body(auth(Type,_,Text))-->{Type\=contact,Text\=''},
	html([\[Text]]).
pbs_body(auth(_,_,''))-->[].

pbs_title(auth(unrestricted,_,_),[]).
pbs_title(auth(contact,_,_),[strong('Authority')]).
pbs_title(auth(restricted,_,_),['Restricted']).
pbs_title(auth(streamlined,_,_),['Streamlined Authority']).

chapter('GE','PBS ').
chapter('SB','PBS (Special benefit) ').
chapter('CI','PBS (Ileostomy/Colostomy) ').
chapter('PQ','PBS (Paraplegia/Quadraplegia) ').
chapter('R1','Repatriation PBS ').
chapter('PL','PBS (Palliative) ').
chapter(X,'PBS (Section 100) '):-memberchk(X,['CS','CT','HS','MF','GH','IF','SY']).
chapter('MF','PBS (Opiate Dependence) ').
chapter('PI','Private script ').

patient_process(N,Params,Reply):-
	memberchk(instructions=Instr1,Params),
	parse_command(Instr1,Instr2),
	parse_instr(Instr2,Instr,_,_),
	termchk(drug=drug(Name,Form,Dose),Params),
	ignore(memberchk(auth_code=UserAuthCode,Params)),
	ignore(UserAuthCode=none),
	termchk(mode=Auth,Params),
	format(atom(QtyName),'~a~a',[qty,Auth]), % use packed auth string to access correct qty/rpt
	memberchk(QtyName=Qty,Params),
	format(atom(RptName),'~a~a',[rpt,Auth]),
	memberchk(RptName=Rpt,Params),
	atom_number(Rpt,Rpt2),
	atom_number(Qty,Qty2),
	concat_atom([PBSType,AuthCode,PBSCode],'_',Auth), % unpack auth string
	assert_patient(N,script(Name,Form,Dose,Instr,pbs(PBSType,PBSCode,AuthCode,UserAuthCode),Qty2,Rpt2)),
	once((pbs(_G,_F,PBSCode,_,_,Chapter,_,_);Chapter='PI')),
	once(((PBSType=contact,ScriptAuthCode=UserAuthCode);ScriptAuthCode=AuthCode)),
	asserta(print(N,drug(Name,Form,Dose,Instr,PBSType,Chapter,ScriptAuthCode,Qty2,Rpt2))),
	print_drug(Name,DrugS),
	print_dose(Dose,DoseS),
	format(atom(Reply),'~a ~a ~a prescribed',[DrugS,Form,DoseS]).

	
make_auth(auth(Type,Code,_Text),PBSCode,Auth):-
	format(atom(Auth),'~a_~a_~a',[Type,Code,PBSCode]).

% predicates for the print engine


print_list(N,drug(Name,Form,Dose,Instr,Qty,Rpt,AuthCode),'Authority Script'):-
	print(N,drug(Name,Form,Dose,Instr,PBSType,_Chapter,AuthCode,Qty,Rpt)),
	(PBSType=contact;PBSType=streamlined).

print_list(N,druglist(L2),'Script'):-
	(IsRepat=yes;IsRepat=no),
	findall(drug(Name,Form,Dose,Instr,Qty,Rpt),search_drug_printlist(N,IsRepat,Name,Form,Dose,Instr,Qty,Rpt),L),
	break_into_threes(L,L2).


search_drug_printlist(N,IsRepat,Name,Form,Dose,Instr,Qty,Rpt):-
	print(N,drug(Name,Form,Dose,Instr,PBSType,Chapter,_ScriptAuthCode,Qty,Rpt)),
	(PBSType=unrestricted;PBSType=restricted),
	((IsRepat=yes,Chapter='R1');(IsRepat\=yes,Chapter\='R1')).

% break list of scripts into groups of 3: legal limit for one script
break_into_threes(L,L):-
	length(L,X),X<3,X>0.
break_into_threes([L1,L2,L3|Rest],L4):-
	L4=[L1,L2,L3];break_into_threes(Rest,L4).

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



















