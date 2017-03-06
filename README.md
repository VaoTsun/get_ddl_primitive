# get_ddl_primitive
Postgres primitives to get DDL when `pg_dump -s` is impossible
Basics:
* SQL is mostly borrowd from `\d+` metacommand of `psql -E`, thus lots of excessive columns, not used in code
* pg_dump -s requires `LOCK TABLE ... IN ACCESS SHARE MODE`, so Eg. in AWS you can \d+ the table structure without being an owner, but can't pg_dump -s it to get DDL
* never tested - comes as is

# Inspired:
* http://dba.stackexchange.com/questions/165612/user-can-select-all-structure-from-pg-catalog-but-cant-make-a-dump-s
* http://stackoverflow.com/questions/1884758/generate-ddl-programmatically-on-postgresql
* http://stackoverflow.com/questions/6024108/export-a-create-script-for-a-database-from-pgadmin

# Supports
* 2/3 of what `psql \d+` shows in execution ready format
  * Table itself
  * Sequences asigned to it
  * Indexes
  * Constraints (not initially differed)
  * Column comments
  * Table comments

#Usage example: 
http://rextester.com/FTOUG46985
OR:
```
t=# drop table "aA";
DROP TABLE
t=# \pset format unaligned
Output format is unaligned.
t=# create table "aA" (i bigserial primary key, a text, ts timestamptz default now(), c int check (c>3), s smallserial, iarr int[], tarr text[]);
CREATE TABLE
t=# create index i on "aA"(c);
ERROR:  relation "i" already exists
t=# create unique index uk on "aA"(c);
CREATE INDEX
t=# comment on table "aA" is 'test table';
COMMENT
t=# comment on column "aA".a is 'c1';
COMMENT
t=# comment on column "aA".c is 'c2';
COMMENT
t=# \o /dev/null
t=# \i get_ddl_primitive/functions.sql
t=# \o
t=# select * from get_ddl_t('public','aA');
get_ddl_t
--Sequences DDL:

CREATE SEQUENCE public."aA_i_seq"
        START WITH 1
        INCREMENT BY 1
        MINVALUE 1
        MAXVALUE 9223372036854775807
        CACHE 1
);
CREATE SEQUENCE public."aA_s_seq"
        START WITH 1
        INCREMENT BY 1
        MINVALUE 1
        MAXVALUE 9223372036854775807
        CACHE 1
);


--Table DDL:
CREATE TABLE public."aA" (
        i bigint nextval('"aA_i_seq"'::regclass) NOT NULL,
        a text ,
        ts timestamp with time zone now(),
        c integer ,
        s smallint nextval('"aA_s_seq"'::regclass) NOT NULL,
        iarr integer[] ,
        tarr text[]
);

--Columns Comments:
COMMENT ON COLUMN aA.a IS 'c1';
COMMENT ON COLUMN aA.c IS 'c2';

--Table Comments:
COMMENT ON TABLE "aA" is 'test table';

--Indexes DDL:
ALTER TABLE ONLY "aA" ADD CONSTRAINT "aA_pkey" PRIMARY KEY (i);
CREATE UNIQUE INDEX uk ON "aA" USING btree (c);

(1 row)
```
mind `\pset format unaligned` part to remove `+` on new line with aligned format

#Multiple tables:
```
t=# select get_ddl_t(schemaname,tablename) as "--" from pg_tables where tableowner <> 'postgres';
--|

--Table DDL:
CREATE TABLE public."sick.name" (
        i integer
);

--|--Sequences DDL:

CREATE SEQUENCE public."aA_i_seq"
        START WITH 1
...
```
the rest is cut...
Mind `as "--"` in select  - to comment the result name, so it would not interfere with DDL generated

#Ignoring errors:
```
t=> \pset format unaligned
Output format is unaligned.
t=> select get_ddl_t(schemaname,tablename,'{"handle exceptions":true}') as "--" from pg_tables where schemaname='public';
INFO:  permission denied for relation t_user_us_us_id_seq
CONTEXT:  SQL statement "select get_ddl_seq_tbl(_sn,_tn,_opt)"
PL/pgSQL function get_ddl_t(text,text,json) line 14 at SQL statement
INFO:  permission denied for relation a_i_seq
CONTEXT:  SQL statement "select get_ddl_seq_tbl(_sn,_tn,_opt)"
PL/pgSQL function get_ddl_t(text,text,json) line 14 at SQL statement
INFO:  permission denied for relation t3_i_seq
CONTEXT:  SQL statement "select get_ddl_seq_tbl(_sn,_tn,_opt)"
PL/pgSQL function get_ddl_t(text,text,json) line 14 at SQL statement
INFO:  permission denied for relation aA_i_seq
CONTEXT:  SQL statement "select get_ddl_seq_tbl(_sn,_tn,_opt)"
PL/pgSQL function get_ddl_t(text,text,json) line 14 at SQL statement
INFO:  permission denied for relation aA_s_seq
CONTEXT:  SQL statement "select get_ddl_seq_tbl(_sn,_tn,_opt)"
PL/pgSQL function get_ddl_t(text,text,json) line 14 at SQL statement
--
--Sequences DDL:


--Table DDL:
CREATE TABLE public.t_user_us (
        us_id integer nextval('t_user_us_us_id_seq'::regclass) NOT NULL,
        us_name character varying(40)  NOT NULL,
        us_salary integer  NOT NULL
);

--Table Comments:
COMMENT ON TABLE t_user_us is 'table com';

--Indexes DDL:
ALTER TABLE ONLY t_user_us ADD CONSTRAINT t_user_us_pkey PRIMARY KEY (us_id);



--Table DDL:
CREATE TABLE public.feedbacks (
        id integer ,
        user_id text ,
        email text ,
        body text
);
--Sequences DDL:


--Table DDL:
CREATE TABLE public.a (
        i bigint nextval('a_i_seq'::regclass) NOT NULL,
        a text ,
        ts timestamp with time zone now(),
.......
```

