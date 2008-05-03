

module('Patient Search',search).
module(_P,'Demographics',demographics).

data_section(none,search,Data,none):-
  format('
<form method="get" action="/search">
<input type="text" name="query" size="20"><input type="submit"></form><p>
<table>
<tr><th>ID</th><th>Name</th><th>Surname</th><th>Dob</th><th>Gender</th></tr>'),
  !,(memberchk(query=Query,Data)->list_demo(Query)),format('</table>').

list_demo(Query):-
  search_demo(Query,Id,Sur,First,date(Y,M,D),Gender),gender_name(Gender,G2),
  format('<tr><td>~a</td><td>~a</td><td>~a</td><td>~a/~a/~a</td><td>~a</td>
<td><a href="/demographics?patid=~a">Open</a></td></tr>',[Id,First,Sur,D,M,Y,G2,Id]),
  fail.

list_demo(_).

data_section(new,demographics,_Data,_Reply):-!,display_demo_form(create,'','','','','','New patient').
data_section(P,demographics,Data,error(Error)):-
  memberchk(surname=Sur,Data),
  memberchk(first=First,Data),
  memberchk(dob=Dob,Data),
  memberchk(gender=Gender,Data),
  display_demo_form(P,Sur,First,Dob,Gender,Error).
data_section(create,demographics,Data,success(P)):-!,data_section(P,demographics,Data,'New patient created').
data_section(P,demographics,Data,none):-!,data_section(P,demographics,Data,'').
data_section(P,demographics,_Data,Reply):-!,
  recorded(P,demo(_Id,Sur,First,Dob,Gender)),
  display_demo_form(P,Sur,First,Dob,Gender,Reply).
  
display_demo_form(P,Sur,First,Dob,Gender,Reply):-
  format('~w<p>',[Reply]),
  format('<form onsubmit="submit(this);return false" action="/demographics"><input type="hidden" name="patid" value="~a"><table>',[P]),
  format('<tr><td>Surname</td><td>'), input(text,surname,10,Sur),format('</td></tr>'),
  format('<tr><td>First name</td><td>'), input(text,first,10,First),format('</td></tr>'),
  format('<tr><td>Date Of Birth</td><td>'), input(date,dob,10,Dob),format('</td></tr>'),
  format('<tr><td>Gender</td><td>'), select(['Male'-m,'Female'-f],gender,Gender),format('</td></tr>'),
  format('<tr><td></td><td><input type="submit"><input type="reset"></td></tr></table></form>'),
  format('<p><a href="/demographics?patid=new">New Patient</a>').

process(create,demographics,Data,Reply):-
  memberchk(surname=Sur,Data),
  memberchk(first=First,Data),
  memberchk(dob=Dob,Data),
  memberchk(gender=Gender,Data),
  demo(Id,Sur,First,Dob,Gender),
  Reply=success(Id).

process(P,demographics,Data,Reply):-
  memberchk(surname=Sur,Data),
  memberchk(first=First,Data),
  memberchk(dob=Dob,Data),
  memberchk(gender=Gender,Data),
  demo(P,Sur,First,Dob,Gender),
  Reply='Patient record updated'.

gender_name(f,'Female').
gender_name(m,'Male').