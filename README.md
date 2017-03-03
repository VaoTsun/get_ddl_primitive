# get_ddl_primitive
Postgres primitives to get DDL when pg_dump -s is impossible
Basics:
* SQL is mostly borrowd from \d+ metacommand of psql, thus lots of excessive columns, not used in code
* pg_dump -s requires LOCK TABLE ... IN ACCESS SHARE MODE, so Eg. in AWS you can \d+ the table structure without being an owner, but can't pg_dump -s it to get DDL
* never tested - comes as is

Prior:
* http://dba.stackexchange.com/questions/165612/user-can-select-all-structure-from-pg-catalog-but-cant-make-a-dump-s
* http://stackoverflow.com/questions/1884758/generate-ddl-programmatically-on-postgresql
* http://stackoverflow.com/questions/6024108/export-a-create-script-for-a-database-from-pgadmin

Usage example: 
t=# \pset format unaligned
Output format is unaligned.
t=# \pset format unaligned
Output format is unaligned.
t=# create table a (i bigserial primary key, a text, ts timestamptz default now(), c int check (c>3));
CREATE TABLE
t=# create unique index i on a(c);
CREATE INDEX
t=# comment on table a is 'test table';
COMMENT
t=# comment on column a.a is 'c1';
COMMENT
t=# comment on column a.c is 'c2';
COMMENT
t=# \o /dev/null
t=# \i get_ddl_primitive/functions.sql
t=# \o
t=# select * from get_ddl_t('public','a');
get_ddl_t
CREATE SEQUENCE public.a_i_seq
        START WITH 1
        INCREMENT BY 1
        MINVALUE 1
        MAXVALUE 9223372036854775807
        CACHE 1
);
CREATE TABLE public.a (
        i bigint nextval('a_i_seq'::regclass) NOT NULL,
        a text ,
        ts timestamp with time zone now(),
        c integer
);
COMMENT ON COLUMN a.a IS 'c1';
COMMENT ON COLUMN a.c IS 'c2';
COMMENT ON TABLE a is 'test table';
ALTER TABLE ONLY a ADD CONSTRAINT a_pkey PRIMARY KEY (i);
CREATE UNIQUE INDEX i ON a USING btree (c);

(1 row)

