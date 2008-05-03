create table person(
    id serial primary key,
    surname text,
    name text,
    dob date,
    gender char,
    username varchar (32),
    password varchar (32)
);


create table user_fact(
    id serial primary key,
    pred text,
    owner integer references person (id)
);


create table fact(
    id serial primary key,
    patient integer references person (id) not null,
    pred text not null,
    author integer references person (id) not null,
    stamp timestamp default now () not null,
    location inet default inet_client_addr(),
    deletion_date timestamp,
    deletion_user integer references person (id),
    deletion_comment text
);

create table blob(
    id serial primary key,
    patient integer references person (id) not null,
    content text not null,
    mime varchar(32) not null
);