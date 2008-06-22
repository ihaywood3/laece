% example demographics file
% needs to be compiled to a quick-load file with: pl -t qcompile\(\'demo.pl\'\). -g halt.

% demo(N,Firstname,Lastname,Dob,Address,Postcode,Telephone,_Medicare,_DVA,_CRN).

demo('12345',ian,haywood,date(1977,12,19),male,'87 sussex st','3056','87453423','123456789',none,none).
demo('12346',cilla,haywood,date(1979,3,1),female,'87 sussex st','3056','87453423','123456789',none,none).
demo('123457',john,smith,date(1967,5,4),male,'1 Smith St','3030','1234567','123456778',none,none).
demo('123458',jane,smith,date(1967,5,4),female,'1 Smith St','3030','1234567','123456778',none,none).

