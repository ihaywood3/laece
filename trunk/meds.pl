
:- use_module(library(sgml)).

% file of preparation(GenericName,PBSForm,Route,Constituents,Amount,AmountUnits,Brands).
:- consult('medlist.pl').
% file of pns(GenericName,PBSForm,ItemNo,MaxQuantity,MaxRepeats,[Availability]).
:- consult('pbs_data.pl').


completion(_Patient,[SDrug],cmdline,example,GenericName,
   '<span class="compl_stem">Drug</span> ~a <em>Dose Freq Amount</em>x<em>Repeats</em>'-[GenericName],''):-
    setof(G,get_generic(SDrug,G),B),member(GenericName,B).

completion(_Patient,[SDrug],cmdline,example,Brand,
   '<span class="compl_stem">Drug</span> ~a <em>Dose Freq Amount</em>x<em>Repeats</em>'-[Brand],''):-
   setof(B,get_brand(SDrug,B),Bag),member(Brand,Bag).

completion(_Patient,[Brand],cmdline,example,Brand,
   '<span class="compl_stem">Drug</span> ~a ~a <em>Freq Amount</em>x<em>Repeats</em>'-[Brand,PBSForm],''):-
    preparation(_GenericName,PBSForm,_Route,_Constituents,_Amount,_AmountUnits,Brands),
    member(Brand,Brands).
    
completion(_Patient,[GenericName],cmdline,example,GenericName,
   '<span class="compl_stem">Drug</span> ~a ~a <em>Freq Amount</em>x<em>Repeats</em>'-[GenericName,PBSForm],''):-
    preparation(GenericName,PBSForm,_Route,_Constituents,_Amount,_AmountUnits,_Brands).

get_generic(S,G):-
    preparation(G,_PBSForm,_Route,_Constituents,_Amount,_AmountUnits,_Brands),
    sub_atom(G,0,_,_,S).

get_brand(S,B):-
    preparation(_GenericName,_PBSForm,_Route,_Constituents,_Amount,_AmountUnits,Brands),
    member(B,Brands),
    sub_atom(B,0,_,_,S).

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
wite_pbs_data:-
    open('pbs_data.pl',write,Pbs),
    ignore(print_pbs(Pbs)),
    close(Pbs).

alltags(Y):-
	pbs(X),xfind(X,'pbs:ready-prepared',C,5),xfind(C,Y,_,0).

print_newdrugs(F):-
    list_drugs(_,G,D,Route,B),
    not(preparation(G,D,_,_,_,_,_)),
    format(F,'preparation(~k,~k,~W,[ct(,,)],1,each,~W).~n',[G,D,Route,[quoted(true)],B,[quoted(true)]]),
    fail.

print_pbs(F):-
    list_drugs(Prep,G,D,_),
    list_pbs(Prep,Code,Qty,Rpts,Modes),
    format(F,'pbs(~k,~k,~k,~w,~w,~W).~n',[G,D,Code,Qty,Rpts,Modes,[quoted(true)]]),
    fail.

list_generics(G):-pbs(PBS),xfind(PBS,'pbs:drug',_,C,0,20),xfind(C,'db:title',_,G,0,0).


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

list_pbs(Prep,Code,Qty,Rpts,Modes):-
    pbs(PBS),
    xfind(Prep,'pbs:code',[Code|_],1),
    mode(ModeTag,ModeIn),
    xfind(PBS,ModeTag,Info,20),
    xfind(Info,'pbs:code',[Code|_],1),
    xfind(Info,'pbs:maximum-quantity',[SQty|_],1),
    xfind(Info,'pbs:number-repeats',[SRpts|_],1),
    atom_number(SQty,Qty),atom_number(SRpts,Rpts),
    findall(Mode,get_restrict(Info,ModeIn,Mode),Modes).
    
get_brand(Prep,Brand2):-
    xfind(Prep,'pbs:brand',B,1),
    xfind(B,'db:title',[Brand|_],1),
    downcase_atom(Brand,Brand2).

mode('pbs:authority-required',auth).
mode('pbs:restricted',restricted).
mode('pbs:unrestricted',unrestricted).




get_restrict(_,unrestricted,unrestricted).

get_restrict(Info,auth,auth(AuthCode,Text)):-
    xfind(Info,'pbs:indication',I,2),
    \+is_streamlined(I),
    extract_authtext(I,Text,AuthCode).

get_restrict(Info,auth,streamlined(AuthCode,Text)):-
    xfind(Info,'pbs:indication',I,2),
    is_streamlined(I),
    extract_authtext(I,Text,AuthCode).

get_restrict(Info,restricted,restricted(AuthCode,Text)):-
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

