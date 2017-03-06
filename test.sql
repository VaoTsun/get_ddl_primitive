

select * from get_ddl_t('public','aA');


drop table "aA";
\pset format unaligned
create table "aA" (i bigserial primary key, a text, ts timestamptz default now(), c int check (c>3), s smallserial, iarr int[], tarr text[]);
create index i on "aA"(c);
create unique index uk on "aA"(c);
comment on table "aA" is 'test table';
comment on column "aA".a is 'c1';
comment on column "aA".c is 'c2';
\o /dev/null
\i get_ddl_primitive/functions.sql
\o 
select * from get_ddl_t('public','aA');
select get_ddl_t(schemaname,tablename) as "--" from pg_tables where tableowner <> 'postgres';

create table bin."cOne" (i int[],"mixedCaseEvil" oid);
--https://www.postgresql.org/docs/current/static/catalog-pg-depend.html

/* -- Skipped:
  ALTER TABLE aa OWNER TO vao;
  ALTER TABLE aa_objectid_seq OWNER TO vao;
  ALTER SEQUENCE aa_objectid_seq OWNED BY aa.objectid;
  ALTER TABLE ONLY aa ALTER COLUMN objectid SET DEFAULT nextval('aa_objectid_seq'::regclass);
  Permissions

*/

