create or replace function get_ddl_oid (_sn text default 'public', _tn text default '', _opt json default '{}') returns text as 
$$
declare
 _oid text;
begin
  --********* QUERY **********
  SELECT c.oid INTO _oid
  FROM pg_catalog.pg_class c
       LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
  WHERE c.relname = _tn
    AND n.nspname = _sn
    AND pg_catalog.pg_table_is_visible(c.oid)
  ;
  return _oid;
end;
$$ language plpgsql
;

create or replace function get_ddl_seq_tbl (_sn text default 'public', _tn text default '', _opt json default '{}') returns text as 
$$
declare
 _oid text;
 _rtn text;
 _seq text;
 _t text;
begin
  select get_ddl_oid(_sn,_tn,_opt) into _oid;
  SELECT d.objid::regclass into _seq
  FROM   pg_depend    d
  JOIN   pg_attribute a ON a.attrelid = d.refobjid AND a.attnum = d.refobjsubid
  JOIN   pg_class c ON c.oid = d.objid
  JOIN   pg_class r ON r.oid = d.refobjid
  WHERE  d.refobjsubid > 0
  AND    refobjid = _oid::bigint 
  AND    deptype ='a'
  AND    c.relkind = 'S'
  ;
  _t := format( 'CREATE SEQUENCE %s.%s', _sn, _seq); --using _sn here is wrong - sequence can be created in other schema than table
  EXECUTE FORMAT($f$
    SELECT concat(
      %L
      , chr(10),chr(9), 'START WITH ', start_value
      , chr(10),chr(9), 'INCREMENT BY ', increment_by
      , chr(10),chr(9), 'MINVALUE ', min_value
      , chr(10),chr(9), 'MAXVALUE ', max_value
      , chr(10),chr(9), 'CACHE ', cache_value
      , chr(10),');'
      ) 
    FROM %s.%s$f$, _t, _sn, _seq)
  into _rtn;
  return _rtn;
end;
$$ language plpgsql
;

create or replace function get_ddl_idx_tbl (_sn text default 'public', _tn text default '', _opt json default '{}') returns text as 
$$
declare
 _oid bigint;
 _rtn text :='';
 _seq text;
 _t text;
 _r record;
begin
  select get_ddl_oid(_sn,_tn,_opt)::bigint into _oid;
  for _r in (
  --********* QUERY **********
  SELECT c2.relname, i.indisprimary, i.indisunique, i.indisclustered, i.indisvalid, pg_catalog.pg_get_indexdef(i.indexrelid, 0, true),
    pg_catalog.pg_get_constraintdef(con.oid, true), contype, condeferrable, condeferred, c2.reltablespace
    , conname
  FROM pg_catalog.pg_class c, pg_catalog.pg_class c2, pg_catalog.pg_index i
    LEFT JOIN pg_catalog.pg_constraint con ON (conrelid = i.indrelid AND conindid = i.indexrelid AND contype IN ('p','u','x'))
  WHERE c.oid = _oid AND c.oid = i.indrelid AND i.indexrelid = c2.oid
    --AND contype is null
  ORDER BY i.indisprimary DESC, i.indisunique DESC, c2.relname
  ) loop
    if _r.contype is null then
      _rtn := concat(_rtn,_r.pg_get_indexdef,';',chr(10));
    else
      _rtn := concat(_rtn,format('ALTER TABLE ONLY %I ADD CONSTRAINT %I ',_tn,_r.conname),_r.pg_get_constraintdef,';',chr(10));
    end if;
  end loop;
  
  return _rtn;
end;
$$ language plpgsql
;

create or replace function get_ddl_t(_sn text default 'public', _tn text default '', _opt json default '{}') returns text as 
$$
declare
 _c bigint;
 _n int := 0;
 _columns text;
 _comments text;
 _table_comments text;
 _indices_ddl text;
 _rtn text;
 _oid text; --17896
 _seq text;
begin
  select get_ddl_oid(_sn,_tn,_opt) into _oid;
  select get_ddl_seq_tbl(_sn,_tn,_opt) into _seq;
  select pg_catalog.obj_description(_oid::bigint) into _table_comments;
  select get_ddl_idx_tbl(_sn,_tn,_opt) into _indices_ddl;
  -- 1. Get list of columns
  SELECT concat(
      chr(10)
    , string_agg(
      concat(
        chr(9)
        , a.attname
        , ' '
        , pg_catalog.format_type(a.atttypid, a.atttypmod)
        , ' '
        , (
          SELECT substring(pg_catalog.pg_get_expr(d.adbin, d.adrelid) for 128)
          FROM pg_catalog.pg_attrdef d
          WHERE d.adrelid = a.attrelid AND d.adnum = a.attnum AND a.atthasdef
        )
        , case when attnotnull then ' NOT NULL' end
      )
      , concat(',',chr(10))
      ) over (order by attnum)
    )
    , string_agg('COMMENT ON COLUMN '||_tn||'.'||a.attname||$c$ IS '$c$||col_description(a.attrelid, a.attnum)||$c$';$c$,chr(10)) over (order by attnum) 
  into _columns,_comments
  FROM pg_catalog.pg_attribute a
  join pg_class c on c.oid = a.attrelid
  join pg_namespace s on s.oid = c.relnamespace
  WHERE a.attnum > 0 AND NOT a.attisdropped
    AND nspname = _sn
    and relname = _tn
    order by 1 desc limit 1;
  
  _rtn := concat(format('CREATE TABLE %I.%I (',_sn,_tn),_columns,chr(10), ');');
  _rtn := concat(_seq,chr(10),_rtn);
  _rtn := concat(_rtn,chr(10),_comments);
  _rtn := concat(_rtn,chr(10),format($f$COMMENT ON TABLE %I is '%s';$f$,_tn,_table_comments));
  _rtn := concat(_rtn,chr(10),_indices_ddl);

  return _rtn;
end;
$$ language plpgsql
;

