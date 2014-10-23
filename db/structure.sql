--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = public, pg_catalog;

--
-- Name: gtsq; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN gtsq AS text;


--
-- Name: gtsvector; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN gtsvector AS pg_catalog.gtsvector;


--
-- Name: statinfo; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE statinfo AS (
	word text,
	ndoc integer,
	nentry integer
);


--
-- Name: tokenout; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE tokenout AS (
	tokid integer,
	token text
);


--
-- Name: tokentype; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE tokentype AS (
	tokid integer,
	alias text,
	descr text
);


--
-- Name: tsdebug; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE tsdebug AS (
	ts_name text,
	tok_type text,
	description text,
	token text,
	dict_name text[],
	tsvector pg_catalog.tsvector
);


--
-- Name: tsquery; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN tsquery AS pg_catalog.tsquery;


--
-- Name: tsvector; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN tsvector AS pg_catalog.tsvector;


--
-- Name: _get_parser_from_curcfg(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION _get_parser_from_curcfg() RETURNS text
    LANGUAGE sql IMMUTABLE STRICT
    AS $$select prsname::text from pg_catalog.pg_ts_parser p join pg_ts_config c on cfgparser = p.oid where c.oid = show_curcfg();$$;


--
-- Name: aggregate_increment(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION aggregate_increment() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
                DECLARE
                    object_type varchar;
                    object_id integer;
                    column_name varchar;
                    agg_date date;
                    
                    entry object_aggregates%ROWTYPE;

                BEGIN
                  IF (TG_TABLE_NAME = 'comments') THEN
                    object_type := NEW.commentable_type;
                    object_id := NEW.commentable_id;
                    column_name := 'comments_count';
                    agg_date := NEW.created_at;
                  ELSIF (TG_TABLE_NAME = 'bookmarks') THEN
                      object_type := NEW.bookmarkable_type;
                      object_id := NEW.bookmarkable_id;
                      column_name := 'bookmarks_count';
                      agg_date := NEW.created_at;
                  ELSIF (TG_TABLE_NAME = 'bill_votes') THEN
                      object_type := 'Bill';
                      object_id := NEW.bill_id;
                      IF (NEW.support = 0) THEN
                        column_name := 'votes_support';
                      ELSE 
                        column_name := 'votes_oppose';
                      END IF;
                      agg_date := NEW.updated_at;
                  ELSIF (TG_TABLE_NAME = 'commentaries') THEN
                      IF (NEW.is_ok = 't') THEN
                        object_type := NEW.commentariable_type;
                        object_id := NEW.commentariable_id;
                        IF (NEW.is_news = 't') THEN
                          column_name := 'news_articles_count';
                        ELSE 
                          column_name := 'blog_articles_count';
                        END IF;
                        agg_date := NEW.date;
                      ELSE
                        RETURN NULL;
                      END IF;
                  END IF;
              
                
                  SELECT * INTO entry FROM object_aggregates WHERE aggregatable_type = object_type AND aggregatable_id = object_id AND date = agg_date::date;
     
                  IF FOUND THEN
                    EXECUTE 'UPDATE object_aggregates SET ' || column_name || ' = ' || column_name || ' + 1 WHERE aggregatable_type = ''' || object_type || ''' AND aggregatable_id = ' || object_id || ' AND date = ''' || agg_date || '''';
                  ELSE
                    EXECUTE 'INSERT INTO object_aggregates (aggregatable_type, aggregatable_id, date, ' || column_name || ') VALUES (''' || object_type || ''', ' ||  object_id || ', ''' || agg_date || ''', 1)';
                  END IF;
                  
                  RETURN NULL;
                END;
            $$;


--
-- Name: comment_page(integer, integer, character varying, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION comment_page(comment_id integer, c_id integer, c_type character varying, comments_per_page integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
    declare
       c_row record;
       rc int := 0;
       found int := 0;
       page_count int := 1;
    begin
       for c_row in select id from comments where commentable_id = c_id and commentable_type = c_type order by comments.root_id ASC, comments.lft ASC loop
          rc := rc + 1;
          if rc = comments_per_page then
             rc := 0;
             page_count := page_count + 1;
          end if;
          if c_row.id = comment_id then
            found := 1;
            exit;
          end if;
       end loop;
       if found = 0 then
         return 1;
       else
         return page_count;
       end if;
    end;
    $$;


--
-- Name: concat(pg_catalog.tsvector, pg_catalog.tsvector); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION concat(pg_catalog.tsvector, pg_catalog.tsvector) RETURNS pg_catalog.tsvector
    LANGUAGE internal IMMUTABLE STRICT
    AS $$tsvector_concat$$;


--
-- Name: dex_init(internal); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION dex_init(internal) RETURNS internal
    LANGUAGE c
    AS '$libdir/tsearch2', 'tsa_dex_init';


--
-- Name: dex_lexize(internal, internal, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION dex_lexize(internal, internal, integer) RETURNS internal
    LANGUAGE c STRICT
    AS '$libdir/tsearch2', 'tsa_dex_lexize';


--
-- Name: get_covers(pg_catalog.tsvector, pg_catalog.tsquery); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION get_covers(pg_catalog.tsvector, pg_catalog.tsquery) RETURNS text
    LANGUAGE c STRICT
    AS '$libdir/tsearch2', 'tsa_get_covers';


--
-- Name: headline(text, pg_catalog.tsquery); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION headline(text, pg_catalog.tsquery) RETURNS text
    LANGUAGE internal IMMUTABLE STRICT
    AS $$ts_headline$$;


--
-- Name: headline(oid, text, pg_catalog.tsquery); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION headline(oid, text, pg_catalog.tsquery) RETURNS text
    LANGUAGE internal IMMUTABLE STRICT
    AS $$ts_headline_byid$$;


--
-- Name: headline(text, text, pg_catalog.tsquery); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION headline(text, text, pg_catalog.tsquery) RETURNS text
    LANGUAGE c IMMUTABLE STRICT
    AS '$libdir/tsearch2', 'tsa_headline_byname';


--
-- Name: headline(text, pg_catalog.tsquery, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION headline(text, pg_catalog.tsquery, text) RETURNS text
    LANGUAGE internal IMMUTABLE STRICT
    AS $$ts_headline_opt$$;


--
-- Name: headline(oid, text, pg_catalog.tsquery, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION headline(oid, text, pg_catalog.tsquery, text) RETURNS text
    LANGUAGE internal IMMUTABLE STRICT
    AS $$ts_headline_byid_opt$$;


--
-- Name: headline(text, text, pg_catalog.tsquery, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION headline(text, text, pg_catalog.tsquery, text) RETURNS text
    LANGUAGE c IMMUTABLE STRICT
    AS '$libdir/tsearch2', 'tsa_headline_byname';


--
-- Name: length(pg_catalog.tsvector); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION length(pg_catalog.tsvector) RETURNS integer
    LANGUAGE internal IMMUTABLE STRICT
    AS $$tsvector_length$$;


--
-- Name: lexize(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION lexize(text) RETURNS text[]
    LANGUAGE c STRICT
    AS '$libdir/tsearch2', 'tsa_lexize_bycurrent';


--
-- Name: lexize(oid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION lexize(oid, text) RETURNS text[]
    LANGUAGE internal STRICT
    AS $$ts_lexize$$;


--
-- Name: lexize(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION lexize(text, text) RETURNS text[]
    LANGUAGE c STRICT
    AS '$libdir/tsearch2', 'tsa_lexize_byname';


--
-- Name: longtxs(double precision, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION longtxs(v_time double precision, v_status text, v_schema text) RETURNS SETOF pg_stat_activity
    LANGUAGE sql
    AS $_$

SELECT * from pg_stat_activity
WHERE extract(minute from current_timestamp-query_start) > $1
AND current_query = $2 ;

$_$;


--
-- Name: numnode(pg_catalog.tsquery); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION numnode(pg_catalog.tsquery) RETURNS integer
    LANGUAGE internal IMMUTABLE STRICT
    AS $$tsquery_numnode$$;


--
-- Name: oc_votes_apart(integer, timestamp without time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION oc_votes_apart(pid integer, after timestamp without time zone) RETURNS SETOF record
    LANGUAGE plpgsql
    AS $$
              DECLARE
                  a_vote RECORD;
                  b_vote RECORD;
                  insert_statement TEXT;
                  ordered_grouped_select TEXT;
              BEGIN
                EXECUTE 'CREATE TEMPORARY TABLE t_votes (LIKE roll_call_votes) ON COMMIT DROP';

                FOR a_vote IN SELECT rcv.* FROM roll_call_votes rcv, roll_calls rc WHERE rc.date > after AND rc.id=rcv.roll_call_id AND rcv.person_id=pid AND rcv.vote != '0' AND rcv.vote != 'P' LOOP
                  insert_statement := 'INSERT INTO t_votes SELECT * FROM roll_call_votes WHERE roll_call_id='||a_vote.roll_call_id||' AND person_id != '||pid||' AND vote IS NOT NULL AND vote !='||quote_literal('0')||' AND vote !='||quote_literal('P')||' AND vote !='||quote_literal(a_vote.vote);
                  EXECUTE insert_statement;
                END LOOP;

                ordered_grouped_select := 'SELECT person_id, count(person_id) as v_count FROM t_votes GROUP BY person_id ORDER BY v_count DESC';
                FOR b_vote IN EXECUTE ordered_grouped_select LOOP
                  RETURN NEXT b_vote;
                END LOOP;

                EXECUTE 'DROP TABLE t_votes';
              END;
              $$;


--
-- Name: oc_votes_together(integer, timestamp without time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION oc_votes_together(pid integer, after timestamp without time zone) RETURNS SETOF record
    LANGUAGE plpgsql
    AS $$
              DECLARE
                a_vote RECORD;
                b_vote RECORD;
                insert_statement TEXT;
                ordered_grouped_select TEXT;
              BEGIN
                EXECUTE 'CREATE TEMPORARY TABLE t_votes (LIKE roll_call_votes) ON COMMIT DROP';

              FOR a_vote IN SELECT rcv.* FROM roll_call_votes rcv, roll_calls rc WHERE rc.date > after AND rc.id=rcv.roll_call_id AND rcv.person_id=pid AND rcv.vote != '0' AND rcv.vote != 'P' LOOP
                insert_statement := 'INSERT INTO t_votes SELECT * FROM roll_call_votes WHERE roll_call_id='||a_vote.roll_call_id||' AND person_id != '||pid||' AND vote='||quote_literal(a_vote.vote);
                EXECUTE insert_statement;
              END LOOP;

              ordered_grouped_select := 'SELECT person_id, count(person_id) as v_count FROM t_votes GROUP BY person_id ORDER BY v_count DESC';
              FOR b_vote IN EXECUTE ordered_grouped_select LOOP
                RETURN NEXT b_vote;
              END LOOP;

              EXECUTE 'DROP TABLE t_votes';
            END;
            $$;


--
-- Name: parse(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION parse(text) RETURNS SETOF tokenout
    LANGUAGE c STRICT
    AS '$libdir/tsearch2', 'tsa_parse_current';


--
-- Name: parse(oid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION parse(oid, text) RETURNS SETOF tokenout
    LANGUAGE internal STRICT
    AS $$ts_parse_byid$$;


--
-- Name: parse(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION parse(text, text) RETURNS SETOF tokenout
    LANGUAGE internal STRICT
    AS $$ts_parse_byname$$;


--
-- Name: plainto_tsquery(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION plainto_tsquery(text) RETURNS pg_catalog.tsquery
    LANGUAGE internal IMMUTABLE STRICT
    AS $$plainto_tsquery$$;


--
-- Name: plainto_tsquery(oid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION plainto_tsquery(oid, text) RETURNS pg_catalog.tsquery
    LANGUAGE internal IMMUTABLE STRICT
    AS $$plainto_tsquery_byid$$;


--
-- Name: plainto_tsquery(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION plainto_tsquery(text, text) RETURNS pg_catalog.tsquery
    LANGUAGE c IMMUTABLE STRICT
    AS '$libdir/tsearch2', 'tsa_plainto_tsquery_name';


--
-- Name: prsd_end(internal); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION prsd_end(internal) RETURNS void
    LANGUAGE c
    AS '$libdir/tsearch2', 'tsa_prsd_end';


--
-- Name: prsd_getlexeme(internal, internal, internal); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION prsd_getlexeme(internal, internal, internal) RETURNS integer
    LANGUAGE c
    AS '$libdir/tsearch2', 'tsa_prsd_getlexeme';


--
-- Name: prsd_headline(internal, internal, internal); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION prsd_headline(internal, internal, internal) RETURNS internal
    LANGUAGE c
    AS '$libdir/tsearch2', 'tsa_prsd_headline';


--
-- Name: prsd_lextype(internal); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION prsd_lextype(internal) RETURNS internal
    LANGUAGE c
    AS '$libdir/tsearch2', 'tsa_prsd_lextype';


--
-- Name: prsd_start(internal, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION prsd_start(internal, integer) RETURNS internal
    LANGUAGE c
    AS '$libdir/tsearch2', 'tsa_prsd_start';


--
-- Name: querytree(pg_catalog.tsquery); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION querytree(pg_catalog.tsquery) RETURNS text
    LANGUAGE internal STRICT
    AS $$tsquerytree$$;


--
-- Name: rank(pg_catalog.tsvector, pg_catalog.tsquery); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION rank(pg_catalog.tsvector, pg_catalog.tsquery) RETURNS real
    LANGUAGE internal IMMUTABLE STRICT
    AS $$ts_rank_tt$$;


--
-- Name: rank(real[], pg_catalog.tsvector, pg_catalog.tsquery); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION rank(real[], pg_catalog.tsvector, pg_catalog.tsquery) RETURNS real
    LANGUAGE internal IMMUTABLE STRICT
    AS $$ts_rank_wtt$$;


--
-- Name: rank(pg_catalog.tsvector, pg_catalog.tsquery, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION rank(pg_catalog.tsvector, pg_catalog.tsquery, integer) RETURNS real
    LANGUAGE internal IMMUTABLE STRICT
    AS $$ts_rank_ttf$$;


--
-- Name: rank(real[], pg_catalog.tsvector, pg_catalog.tsquery, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION rank(real[], pg_catalog.tsvector, pg_catalog.tsquery, integer) RETURNS real
    LANGUAGE internal IMMUTABLE STRICT
    AS $$ts_rank_wttf$$;


--
-- Name: rank_cd(pg_catalog.tsvector, pg_catalog.tsquery); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION rank_cd(pg_catalog.tsvector, pg_catalog.tsquery) RETURNS real
    LANGUAGE internal IMMUTABLE STRICT
    AS $$ts_rankcd_tt$$;


--
-- Name: rank_cd(real[], pg_catalog.tsvector, pg_catalog.tsquery); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION rank_cd(real[], pg_catalog.tsvector, pg_catalog.tsquery) RETURNS real
    LANGUAGE internal IMMUTABLE STRICT
    AS $$ts_rankcd_wtt$$;


--
-- Name: rank_cd(pg_catalog.tsvector, pg_catalog.tsquery, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION rank_cd(pg_catalog.tsvector, pg_catalog.tsquery, integer) RETURNS real
    LANGUAGE internal IMMUTABLE STRICT
    AS $$ts_rankcd_ttf$$;


--
-- Name: rank_cd(real[], pg_catalog.tsvector, pg_catalog.tsquery, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION rank_cd(real[], pg_catalog.tsvector, pg_catalog.tsquery, integer) RETURNS real
    LANGUAGE internal IMMUTABLE STRICT
    AS $$ts_rankcd_wttf$$;


--
-- Name: reset_tsearch(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION reset_tsearch() RETURNS void
    LANGUAGE c STRICT
    AS '$libdir/tsearch2', 'tsa_reset_tsearch';


--
-- Name: rewrite(pg_catalog.tsquery, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION rewrite(pg_catalog.tsquery, text) RETURNS pg_catalog.tsquery
    LANGUAGE internal IMMUTABLE STRICT
    AS $$tsquery_rewrite_query$$;


--
-- Name: rewrite(pg_catalog.tsquery, pg_catalog.tsquery, pg_catalog.tsquery); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION rewrite(pg_catalog.tsquery, pg_catalog.tsquery, pg_catalog.tsquery) RETURNS pg_catalog.tsquery
    LANGUAGE internal IMMUTABLE STRICT
    AS $$tsquery_rewrite$$;


--
-- Name: rewrite_accum(pg_catalog.tsquery, pg_catalog.tsquery[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION rewrite_accum(pg_catalog.tsquery, pg_catalog.tsquery[]) RETURNS pg_catalog.tsquery
    LANGUAGE c
    AS '$libdir/tsearch2', 'tsa_rewrite_accum';


--
-- Name: rewrite_finish(pg_catalog.tsquery); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION rewrite_finish(pg_catalog.tsquery) RETURNS pg_catalog.tsquery
    LANGUAGE c
    AS '$libdir/tsearch2', 'tsa_rewrite_finish';


--
-- Name: set_curcfg(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION set_curcfg(integer) RETURNS void
    LANGUAGE c STRICT
    AS '$libdir/tsearch2', 'tsa_set_curcfg';


--
-- Name: set_curcfg(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION set_curcfg(text) RETURNS void
    LANGUAGE c STRICT
    AS '$libdir/tsearch2', 'tsa_set_curcfg_byname';


--
-- Name: set_curdict(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION set_curdict(integer) RETURNS void
    LANGUAGE c STRICT
    AS '$libdir/tsearch2', 'tsa_set_curdict';


--
-- Name: set_curdict(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION set_curdict(text) RETURNS void
    LANGUAGE c STRICT
    AS '$libdir/tsearch2', 'tsa_set_curdict_byname';


--
-- Name: set_curprs(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION set_curprs(integer) RETURNS void
    LANGUAGE c STRICT
    AS '$libdir/tsearch2', 'tsa_set_curprs';


--
-- Name: set_curprs(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION set_curprs(text) RETURNS void
    LANGUAGE c STRICT
    AS '$libdir/tsearch2', 'tsa_set_curprs_byname';


--
-- Name: setweight(pg_catalog.tsvector, "char"); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION setweight(pg_catalog.tsvector, "char") RETURNS pg_catalog.tsvector
    LANGUAGE internal IMMUTABLE STRICT
    AS $$tsvector_setweight$$;


--
-- Name: show_curcfg(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION show_curcfg() RETURNS oid
    LANGUAGE internal STABLE STRICT
    AS $$get_current_ts_config$$;


--
-- Name: snb_en_init(internal); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION snb_en_init(internal) RETURNS internal
    LANGUAGE c
    AS '$libdir/tsearch2', 'tsa_snb_en_init';


--
-- Name: snb_lexize(internal, internal, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION snb_lexize(internal, internal, integer) RETURNS internal
    LANGUAGE c STRICT
    AS '$libdir/tsearch2', 'tsa_snb_lexize';


--
-- Name: snb_ru_init(internal); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION snb_ru_init(internal) RETURNS internal
    LANGUAGE c
    AS '$libdir/tsearch2', 'tsa_snb_ru_init';


--
-- Name: snb_ru_init_koi8(internal); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION snb_ru_init_koi8(internal) RETURNS internal
    LANGUAGE c
    AS '$libdir/tsearch2', 'tsa_snb_ru_init_koi8';


--
-- Name: snb_ru_init_utf8(internal); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION snb_ru_init_utf8(internal) RETURNS internal
    LANGUAGE c
    AS '$libdir/tsearch2', 'tsa_snb_ru_init_utf8';


--
-- Name: spell_init(internal); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION spell_init(internal) RETURNS internal
    LANGUAGE c
    AS '$libdir/tsearch2', 'tsa_spell_init';


--
-- Name: spell_lexize(internal, internal, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION spell_lexize(internal, internal, integer) RETURNS internal
    LANGUAGE c STRICT
    AS '$libdir/tsearch2', 'tsa_spell_lexize';


--
-- Name: stat(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION stat(text) RETURNS SETOF statinfo
    LANGUAGE internal STRICT
    AS $$ts_stat1$$;


--
-- Name: stat(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION stat(text, text) RETURNS SETOF statinfo
    LANGUAGE internal STRICT
    AS $$ts_stat2$$;


--
-- Name: strip(pg_catalog.tsvector); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION strip(pg_catalog.tsvector) RETURNS pg_catalog.tsvector
    LANGUAGE internal IMMUTABLE STRICT
    AS $$tsvector_strip$$;


--
-- Name: syn_init(internal); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION syn_init(internal) RETURNS internal
    LANGUAGE c
    AS '$libdir/tsearch2', 'tsa_syn_init';


--
-- Name: syn_lexize(internal, internal, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION syn_lexize(internal, internal, integer) RETURNS internal
    LANGUAGE c STRICT
    AS '$libdir/tsearch2', 'tsa_syn_lexize';


--
-- Name: thesaurus_init(internal); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION thesaurus_init(internal) RETURNS internal
    LANGUAGE c
    AS '$libdir/tsearch2', 'tsa_thesaurus_init';


--
-- Name: thesaurus_lexize(internal, internal, integer, internal); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION thesaurus_lexize(internal, internal, integer, internal) RETURNS internal
    LANGUAGE c STRICT
    AS '$libdir/tsearch2', 'tsa_thesaurus_lexize';


--
-- Name: to_tsquery(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION to_tsquery(text) RETURNS pg_catalog.tsquery
    LANGUAGE internal IMMUTABLE STRICT
    AS $$to_tsquery$$;


--
-- Name: to_tsquery(oid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION to_tsquery(oid, text) RETURNS pg_catalog.tsquery
    LANGUAGE internal IMMUTABLE STRICT
    AS $$to_tsquery_byid$$;


--
-- Name: to_tsquery(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION to_tsquery(text, text) RETURNS pg_catalog.tsquery
    LANGUAGE c IMMUTABLE STRICT
    AS '$libdir/tsearch2', 'tsa_to_tsquery_name';


--
-- Name: to_tsvector(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION to_tsvector(text) RETURNS pg_catalog.tsvector
    LANGUAGE internal IMMUTABLE STRICT
    AS $$to_tsvector$$;


--
-- Name: to_tsvector(oid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION to_tsvector(oid, text) RETURNS pg_catalog.tsvector
    LANGUAGE internal IMMUTABLE STRICT
    AS $$to_tsvector_byid$$;


--
-- Name: to_tsvector(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION to_tsvector(text, text) RETURNS pg_catalog.tsvector
    LANGUAGE c IMMUTABLE STRICT
    AS '$libdir/tsearch2', 'tsa_to_tsvector_name';


--
-- Name: token_type(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION token_type() RETURNS SETOF tokentype
    LANGUAGE c STRICT ROWS 16
    AS '$libdir/tsearch2', 'tsa_token_type_current';


--
-- Name: token_type(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION token_type(integer) RETURNS SETOF tokentype
    LANGUAGE internal STRICT ROWS 16
    AS $$ts_token_type_byid$$;


--
-- Name: token_type(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION token_type(text) RETURNS SETOF tokentype
    LANGUAGE internal STRICT ROWS 16
    AS $$ts_token_type_byname$$;


--
-- Name: ts_debug(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION ts_debug(text) RETURNS SETOF tsdebug
    LANGUAGE sql STRICT
    AS $_$
select
        (select c.cfgname::text from pg_catalog.pg_ts_config as c
         where c.oid = show_curcfg()),
        t.alias as tok_type,
        t.descr as description,
        p.token,
        ARRAY ( SELECT m.mapdict::pg_catalog.regdictionary::pg_catalog.text
                FROM pg_catalog.pg_ts_config_map AS m
                WHERE m.mapcfg = show_curcfg() AND m.maptokentype = p.tokid
                ORDER BY m.mapseqno )
        AS dict_name,
        strip(to_tsvector(p.token)) as tsvector
from
        parse( _get_parser_from_curcfg(), $1 ) as p,
        token_type() as t
where
        t.tokid = p.tokid
$_$;


--
-- Name: tsearch2(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION tsearch2() RETURNS trigger
    LANGUAGE c
    AS '$libdir/tsearch2', 'tsa_tsearch2';


--
-- Name: tsq_mcontained(pg_catalog.tsquery, pg_catalog.tsquery); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION tsq_mcontained(pg_catalog.tsquery, pg_catalog.tsquery) RETURNS boolean
    LANGUAGE internal IMMUTABLE STRICT
    AS $$tsq_mcontained$$;


--
-- Name: tsq_mcontains(pg_catalog.tsquery, pg_catalog.tsquery); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION tsq_mcontains(pg_catalog.tsquery, pg_catalog.tsquery) RETURNS boolean
    LANGUAGE internal IMMUTABLE STRICT
    AS $$tsq_mcontains$$;


--
-- Name: tsquery_and(pg_catalog.tsquery, pg_catalog.tsquery); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION tsquery_and(pg_catalog.tsquery, pg_catalog.tsquery) RETURNS pg_catalog.tsquery
    LANGUAGE internal IMMUTABLE STRICT
    AS $$tsquery_and$$;


--
-- Name: tsquery_not(pg_catalog.tsquery); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION tsquery_not(pg_catalog.tsquery) RETURNS pg_catalog.tsquery
    LANGUAGE internal IMMUTABLE STRICT
    AS $$tsquery_not$$;


--
-- Name: tsquery_or(pg_catalog.tsquery, pg_catalog.tsquery); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION tsquery_or(pg_catalog.tsquery, pg_catalog.tsquery) RETURNS pg_catalog.tsquery
    LANGUAGE internal IMMUTABLE STRICT
    AS $$tsquery_or$$;


--
-- Name: rewrite(pg_catalog.tsquery[]); Type: AGGREGATE; Schema: public; Owner: -
--

CREATE AGGREGATE rewrite(pg_catalog.tsquery[]) (
    SFUNC = rewrite_accum,
    STYPE = pg_catalog.tsquery,
    FINALFUNC = rewrite_finish
);


--
-- Name: tsquery_ops; Type: OPERATOR FAMILY; Schema: public; Owner: -
--

CREATE OPERATOR FAMILY tsquery_ops USING btree;


--
-- Name: tsquery_ops; Type: OPERATOR CLASS; Schema: public; Owner: -
--

CREATE OPERATOR CLASS tsquery_ops
    FOR TYPE pg_catalog.tsquery USING btree AS
    OPERATOR 1 <(pg_catalog.tsquery,pg_catalog.tsquery) ,
    OPERATOR 2 <=(pg_catalog.tsquery,pg_catalog.tsquery) ,
    OPERATOR 3 =(pg_catalog.tsquery,pg_catalog.tsquery) ,
    OPERATOR 4 >=(pg_catalog.tsquery,pg_catalog.tsquery) ,
    OPERATOR 5 >(pg_catalog.tsquery,pg_catalog.tsquery) ,
    FUNCTION 1 (pg_catalog.tsquery, pg_catalog.tsquery) tsquery_cmp(pg_catalog.tsquery,pg_catalog.tsquery);


--
-- Name: tsvector_ops; Type: OPERATOR FAMILY; Schema: public; Owner: -
--

CREATE OPERATOR FAMILY tsvector_ops USING btree;


--
-- Name: tsvector_ops; Type: OPERATOR CLASS; Schema: public; Owner: -
--

CREATE OPERATOR CLASS tsvector_ops
    FOR TYPE pg_catalog.tsvector USING btree AS
    OPERATOR 1 <(pg_catalog.tsvector,pg_catalog.tsvector) ,
    OPERATOR 2 <=(pg_catalog.tsvector,pg_catalog.tsvector) ,
    OPERATOR 3 =(pg_catalog.tsvector,pg_catalog.tsvector) ,
    OPERATOR 4 >=(pg_catalog.tsvector,pg_catalog.tsvector) ,
    OPERATOR 5 >(pg_catalog.tsvector,pg_catalog.tsvector) ,
    FUNCTION 1 (pg_catalog.tsvector, pg_catalog.tsvector) tsvector_cmp(pg_catalog.tsvector,pg_catalog.tsvector);


SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: actions; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE actions (
    id integer NOT NULL,
    action_type character varying(255),
    date integer,
    datetime timestamp without time zone,
    how character varying(255),
    "where" character varying(255),
    vote_type character varying(255),
    result character varying(255),
    bill_id integer,
    amendment_id integer,
    type character varying(255),
    text text,
    roll_call_id integer,
    roll_call_number integer,
    created_at timestamp without time zone,
    govtrack_order integer,
    in_committee text,
    in_subcommittee text,
    ordinal_position integer
);


--
-- Name: actions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE actions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: actions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE actions_id_seq OWNED BY actions.id;


--
-- Name: activities; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE activities (
    id integer NOT NULL,
    trackable_id integer,
    trackable_type character varying(255),
    owner_id integer,
    owner_type character varying(255),
    key character varying(255),
    parameters text,
    recipient_id integer,
    recipient_type character varying(255),
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: activities_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE activities_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: activities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE activities_id_seq OWNED BY activities.id;


--
-- Name: activity_options; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE activity_options (
    id integer NOT NULL,
    key character varying(255),
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    owner_model character varying(255),
    trackable_model character varying(255)
);


--
-- Name: activity_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE activity_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: activity_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE activity_options_id_seq OWNED BY activity_options.id;


--
-- Name: amendments; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE amendments (
    id integer NOT NULL,
    number character varying(255),
    retreived_date integer,
    status character varying(255),
    status_date integer,
    status_datetime timestamp without time zone,
    offered_date integer,
    offered_datetime timestamp without time zone,
    bill_id integer,
    purpose text,
    description text,
    updated timestamp without time zone,
    key_vote_category_id integer,
    congress integer
);


--
-- Name: amendments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE amendments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: amendments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE amendments_id_seq OWNED BY amendments.id;


--
-- Name: api_hits; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE api_hits (
    id integer NOT NULL,
    action character varying(255),
    user_id integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    ip character varying(50)
);


--
-- Name: api_hits_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE api_hits_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: api_hits_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE api_hits_id_seq OWNED BY api_hits.id;


--
-- Name: article_images; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE article_images (
    id integer NOT NULL,
    article_id integer,
    image character varying(255)
);


--
-- Name: article_images_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE article_images_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: article_images_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE article_images_id_seq OWNED BY article_images.id;


--
-- Name: articles; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE articles (
    id integer NOT NULL,
    title character varying(255),
    article text,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    published_flag boolean,
    frontpage boolean DEFAULT false,
    user_id integer,
    render_type character varying(255),
    frontpage_image_url character varying(255),
    excerpt text,
    fti_names tsvector
);


--
-- Name: articles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE articles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: articles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE articles_id_seq OWNED BY articles.id;


--
-- Name: bad_commentaries; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE bad_commentaries (
    url text,
    commentariable_id integer,
    commentariable_type character varying(255),
    date timestamp without time zone,
    id integer NOT NULL
);


--
-- Name: bad_commentaries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE bad_commentaries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bad_commentaries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE bad_commentaries_id_seq OWNED BY bad_commentaries.id;


--
-- Name: bill_battles; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE bill_battles (
    id integer NOT NULL,
    first_bill_id integer,
    second_bill_id integer,
    first_score integer,
    second_score integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    created_by integer,
    active boolean,
    run_date timestamp without time zone
);


--
-- Name: bill_battles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE bill_battles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bill_battles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE bill_battles_id_seq OWNED BY bill_battles.id;


--
-- Name: bill_fulltext; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE bill_fulltext (
    bill_id integer,
    fulltext text,
    fti_names tsvector
);


--
-- Name: bill_interest_groups; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE bill_interest_groups (
    id integer NOT NULL,
    bill_id integer NOT NULL,
    crp_interest_group_id integer NOT NULL,
    disposition character varying(255)
);


--
-- Name: bill_interest_groups_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE bill_interest_groups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bill_interest_groups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE bill_interest_groups_id_seq OWNED BY bill_interest_groups.id;


--
-- Name: bill_position_organizations; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE bill_position_organizations (
    id integer NOT NULL,
    bill_id integer NOT NULL,
    maplight_organization_id integer NOT NULL,
    name character varying(255),
    disposition character varying(255),
    citation text
);


--
-- Name: bill_position_organizations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE bill_position_organizations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bill_position_organizations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE bill_position_organizations_id_seq OWNED BY bill_position_organizations.id;


--
-- Name: bill_referrers; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE bill_referrers (
    id integer NOT NULL,
    bill_id integer,
    url character varying(255),
    created_at timestamp without time zone
);


--
-- Name: bill_referrers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE bill_referrers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bill_referrers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE bill_referrers_id_seq OWNED BY bill_referrers.id;


--
-- Name: bill_stats; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE bill_stats (
    bill_id integer NOT NULL,
    entered_top_viewed timestamp without time zone,
    entered_top_news timestamp without time zone,
    entered_top_blog timestamp without time zone
);


--
-- Name: bill_subjects; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE bill_subjects (
    id integer NOT NULL,
    bill_id integer,
    subject_id integer
);


--
-- Name: bill_subjects_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE bill_subjects_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bill_subjects_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE bill_subjects_id_seq OWNED BY bill_subjects.id;


--
-- Name: bill_text_nodes; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE bill_text_nodes (
    id integer NOT NULL,
    bill_text_version_id integer,
    nid character varying(255)
);


--
-- Name: bill_text_nodes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE bill_text_nodes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bill_text_nodes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE bill_text_nodes_id_seq OWNED BY bill_text_nodes.id;


--
-- Name: bill_text_versions; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE bill_text_versions (
    id integer NOT NULL,
    bill_id integer,
    version character varying(255),
    word_count integer DEFAULT 0,
    previous_version character varying(255),
    difference_size_chars integer DEFAULT 0,
    percent_change integer DEFAULT 0,
    total_changes integer DEFAULT 0,
    file_timestamp timestamp without time zone
);


--
-- Name: bill_text_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE bill_text_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bill_text_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE bill_text_versions_id_seq OWNED BY bill_text_versions.id;


--
-- Name: bill_titles; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE bill_titles (
    id integer NOT NULL,
    title_type character varying(255),
    "as" character varying(255),
    bill_id integer,
    title text,
    fti_titles tsvector,
    is_default boolean DEFAULT false
);


--
-- Name: bill_titles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE bill_titles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bill_titles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE bill_titles_id_seq OWNED BY bill_titles.id;


--
-- Name: bill_votes; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE bill_votes (
    id integer NOT NULL,
    bill_id integer,
    user_id integer,
    support smallint,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: bill_votes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE bill_votes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bill_votes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE bill_votes_id_seq OWNED BY bill_votes.id;


--
-- Name: bills; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE bills (
    id integer NOT NULL,
    session integer,
    bill_type character varying(7),
    number integer,
    introduced integer,
    sponsor_id integer,
    lastaction integer,
    rolls character varying(255),
    last_vote_date integer,
    last_vote_where character varying(255),
    last_vote_roll integer,
    last_speech integer,
    pl character varying(255),
    topresident_date integer,
    topresident_datetime date,
    summary text,
    plain_language_summary text,
    hot_bill_category_id integer,
    updated timestamp without time zone,
    page_views_count integer,
    is_frontpage_hot boolean,
    news_article_count integer DEFAULT 0,
    blog_article_count integer DEFAULT 0,
    caption text,
    key_vote_category_id integer,
    is_major boolean,
    top_subject_id integer,
    short_title text,
    popular_title text,
    official_title text,
    manual_title text
);


--
-- Name: bills_committees; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE bills_committees (
    id integer NOT NULL,
    bill_id integer,
    committee_id integer,
    activity character varying(255)
);


--
-- Name: bills_committees_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE bills_committees_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bills_committees_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE bills_committees_id_seq OWNED BY bills_committees.id;


--
-- Name: bills_cosponsors; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE bills_cosponsors (
    id integer NOT NULL,
    person_id integer,
    bill_id integer,
    date_added date,
    date_withdrawn date
);


--
-- Name: bills_cosponsors_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE bills_cosponsors_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bills_cosponsors_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE bills_cosponsors_id_seq OWNED BY bills_cosponsors.id;


--
-- Name: bills_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE bills_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bills_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE bills_id_seq OWNED BY bills.id;


--
-- Name: bills_relations; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE bills_relations (
    id integer NOT NULL,
    relation character varying(255),
    bill_id integer,
    related_bill_id integer
);


--
-- Name: bills_relations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE bills_relations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bills_relations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE bills_relations_id_seq OWNED BY bills_relations.id;


--
-- Name: bookmarks; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE bookmarks (
    id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    bookmarkable_type character varying(15) DEFAULT ''::character varying NOT NULL,
    bookmarkable_id integer DEFAULT 0 NOT NULL,
    user_id integer DEFAULT 0 NOT NULL
);


--
-- Name: bookmarks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE bookmarks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bookmarks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE bookmarks_id_seq OWNED BY bookmarks.id;


--
-- Name: comment_scores; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE comment_scores (
    id integer NOT NULL,
    user_id integer,
    comment_id integer,
    score integer,
    created_at timestamp without time zone,
    ip_address character varying(255)
);


--
-- Name: comment_scores_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE comment_scores_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: comment_scores_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE comment_scores_id_seq OWNED BY comment_scores.id;


--
-- Name: commentaries; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE commentaries (
    id integer NOT NULL,
    title character varying,
    url text,
    excerpt text,
    date timestamp without time zone,
    source character varying(255),
    source_url character varying(255),
    weight integer,
    scraped_from character varying(255),
    status character varying(255),
    contains_term character varying(255),
    fti_names tsvector,
    created_at timestamp without time zone,
    is_news boolean,
    is_ok boolean DEFAULT false,
    average_rating double precision,
    commentariable_id integer,
    commentariable_type character varying(255)
);


--
-- Name: commentaries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE commentaries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: commentaries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE commentaries_id_seq OWNED BY commentaries.id;


--
-- Name: commentary_ratings; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE commentary_ratings (
    id integer NOT NULL,
    user_id integer,
    commentary_id integer,
    rating integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: commentary_ratings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE commentary_ratings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: commentary_ratings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE commentary_ratings_id_seq OWNED BY commentary_ratings.id;


--
-- Name: comments; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE comments (
    id integer NOT NULL,
    commentable_id integer,
    commentable_type character varying(255),
    comment text,
    user_id integer,
    name character varying(255),
    email character varying(255),
    homepage character varying(255),
    created_at timestamp without time zone,
    parent_id integer,
    title character varying(255),
    updated_at timestamp without time zone,
    average_rating double precision DEFAULT 5.0,
    censored boolean DEFAULT false,
    ok boolean,
    rgt integer,
    lft integer,
    root_id integer,
    fti_names tsvector,
    flagged boolean DEFAULT false,
    ip_address character varying(255),
    plus_score_count integer DEFAULT 0 NOT NULL,
    minus_score_count integer DEFAULT 0 NOT NULL,
    spam boolean,
    defensio_sig character varying(255),
    spaminess double precision,
    permalink character varying(255),
    user_agent text,
    referrer character varying(255)
);


--
-- Name: comments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE comments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: comments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE comments_id_seq OWNED BY comments.id;


--
-- Name: committee_meetings; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE committee_meetings (
    id integer NOT NULL,
    subject text,
    meeting_at timestamp without time zone,
    committee_id integer,
    "where" character varying(255)
);


--
-- Name: committee_meetings_bills; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE committee_meetings_bills (
    id integer NOT NULL,
    committee_meeting_id integer,
    bill_id integer
);


--
-- Name: committee_meetings_bills_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE committee_meetings_bills_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: committee_meetings_bills_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE committee_meetings_bills_id_seq OWNED BY committee_meetings_bills.id;


--
-- Name: committee_meetings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE committee_meetings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: committee_meetings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE committee_meetings_id_seq OWNED BY committee_meetings.id;


--
-- Name: committee_names; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE committee_names (
    id integer NOT NULL,
    committee_id integer,
    name character varying(255),
    session integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: committee_names_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE committee_names_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: committee_names_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE committee_names_id_seq OWNED BY committee_names.id;


--
-- Name: committee_reports; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE committee_reports (
    id integer NOT NULL,
    name character varying(255),
    number integer,
    kind character varying(255),
    person_id integer,
    bill_id integer,
    committee_id integer,
    congress integer,
    title text,
    reported_at timestamp without time zone,
    created_at timestamp without time zone,
    gpo_id character varying(255),
    chamber character varying(255)
);


--
-- Name: committee_reports_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE committee_reports_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: committee_reports_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE committee_reports_id_seq OWNED BY committee_reports.id;


--
-- Name: committee_stats; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE committee_stats (
    committee_id integer NOT NULL,
    entered_top_viewed timestamp without time zone
);


--
-- Name: committees; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE committees (
    id integer NOT NULL,
    name character varying(255),
    subcommittee_name character varying(255),
    fti_names tsvector,
    active boolean DEFAULT true,
    code character varying(255),
    page_views_count integer,
    thomas_id character varying(255),
    chamber character varying(255),
    parent_id integer
);


--
-- Name: committees_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE committees_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: committees_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE committees_id_seq OWNED BY committees.id;


--
-- Name: committees_people; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE committees_people (
    id integer NOT NULL,
    committee_id integer,
    person_id integer,
    role character varying(255),
    session integer
);


--
-- Name: committees_people_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE committees_people_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: committees_people_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE committees_people_id_seq OWNED BY committees_people.id;


--
-- Name: comparison_data_points; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE comparison_data_points (
    id integer NOT NULL,
    comparison_id integer,
    comp_value integer,
    comp_indx integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: comparison_data_points_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE comparison_data_points_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: comparison_data_points_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE comparison_data_points_id_seq OWNED BY comparison_data_points.id;


--
-- Name: comparisons; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE comparisons (
    id integer NOT NULL,
    type character varying(255),
    congress integer,
    chamber character varying(255),
    average_value integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: comparisons_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE comparisons_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: comparisons_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE comparisons_id_seq OWNED BY comparisons.id;


--
-- Name: congress_sessions; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE congress_sessions (
    id integer NOT NULL,
    chamber character varying(255),
    date date,
    is_in_session boolean,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: congress_sessions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE congress_sessions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: congress_sessions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE congress_sessions_id_seq OWNED BY congress_sessions.id;


--
-- Name: contact_congress_letters; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE contact_congress_letters (
    id integer NOT NULL,
    user_id integer,
    disposition character varying(255),
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    receive_replies boolean DEFAULT true,
    contactable_id integer,
    contactable_type character varying(255),
    is_public boolean DEFAULT false
);


--
-- Name: contact_congress_letters_formageddon_threads; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE contact_congress_letters_formageddon_threads (
    contact_congress_letter_id integer,
    formageddon_thread_id integer
);


--
-- Name: contact_congress_letters_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE contact_congress_letters_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: contact_congress_letters_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE contact_congress_letters_id_seq OWNED BY contact_congress_letters.id;


--
-- Name: contact_congress_tests; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE contact_congress_tests (
    id integer NOT NULL,
    bioguideid character varying(255),
    status text,
    after_browser_state text,
    "values" text,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    submitted_form text
);


--
-- Name: contact_congress_tests_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE contact_congress_tests_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: contact_congress_tests_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE contact_congress_tests_id_seq OWNED BY contact_congress_tests.id;


--
-- Name: crp_contrib_individual_to_candidate; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE crp_contrib_individual_to_candidate (
    cycle character varying(255) NOT NULL,
    fec_trans_id character varying(255) NOT NULL,
    fec_contrib_id character varying(255),
    name character varying(255) NOT NULL,
    recipient_osid character varying(255),
    org character varying(255),
    parent_org character varying(255),
    crp_interest_group_osid character varying(255),
    contrib_date date NOT NULL,
    amount integer,
    street character varying(255),
    city character varying(255),
    state character varying(255),
    zip character varying(255),
    recip_code character varying(255),
    contrib_type character varying(255),
    pac_id character varying(255),
    other_pac_id character varying(255),
    gender character varying(255),
    microfilm character varying(255),
    occ_ef character varying(255),
    emp_ef character varying(255),
    source character varying(255)
);


--
-- Name: crp_contrib_pac_to_candidate; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE crp_contrib_pac_to_candidate (
    cycle character varying(255) NOT NULL,
    fec_trans_id character varying(255) NOT NULL,
    crp_pac_osid character varying(255) NOT NULL,
    recipient_osid character varying(255),
    amount integer NOT NULL,
    contrib_date date NOT NULL,
    crp_interest_group_osid character varying(255),
    contrib_type character varying(255),
    direct_or_indirect character varying(255) NOT NULL,
    fec_cand_id character varying(255)
);


--
-- Name: crp_industries; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE crp_industries (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    crp_sector_id integer
);


--
-- Name: crp_industries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE crp_industries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: crp_industries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE crp_industries_id_seq OWNED BY crp_industries.id;


--
-- Name: crp_interest_groups; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE crp_interest_groups (
    id integer NOT NULL,
    osid character varying(255) NOT NULL,
    name character varying(255),
    crp_industry_id integer,
    "order" character varying(255)
);


--
-- Name: crp_interest_groups_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE crp_interest_groups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: crp_interest_groups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE crp_interest_groups_id_seq OWNED BY crp_interest_groups.id;


--
-- Name: crp_pacs; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE crp_pacs (
    id integer NOT NULL,
    fec_id character varying(255) NOT NULL,
    osid character varying(255) NOT NULL,
    name character varying(255) NOT NULL,
    affiliate_pac_id integer,
    parent_pac_id integer,
    recipient_type character varying(255),
    recipient_person_id integer,
    party character varying(255),
    crp_interest_group_id integer,
    crp_interest_group_source character varying(255),
    is_sensitive boolean DEFAULT false,
    is_foreign boolean DEFAULT false,
    is_active boolean DEFAULT true
);


--
-- Name: crp_pacs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE crp_pacs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: crp_pacs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE crp_pacs_id_seq OWNED BY crp_pacs.id;


--
-- Name: crp_sectors; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE crp_sectors (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    display_name character varying(255)
);


--
-- Name: crp_sectors_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE crp_sectors_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: crp_sectors_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE crp_sectors_id_seq OWNED BY crp_sectors.id;


--
-- Name: delayed_jobs; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE delayed_jobs (
    id integer NOT NULL,
    priority integer DEFAULT 0 NOT NULL,
    attempts integer DEFAULT 0 NOT NULL,
    handler text NOT NULL,
    last_error text,
    run_at timestamp without time zone,
    locked_at timestamp without time zone,
    failed_at timestamp without time zone,
    locked_by character varying(255),
    queue character varying(255),
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: delayed_jobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE delayed_jobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: delayed_jobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE delayed_jobs_id_seq OWNED BY delayed_jobs.id;


--
-- Name: districts; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE districts (
    id integer NOT NULL,
    district_number integer,
    state_id integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    center_lat numeric(15,10),
    center_lng numeric(15,10)
);


--
-- Name: districts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE districts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: districts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE districts_id_seq OWNED BY districts.id;


--
-- Name: email_congress_letter_seeds; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE email_congress_letter_seeds (
    id integer NOT NULL,
    raw_source text,
    sender_email character varying(255),
    sender_title character varying(255),
    sender_first_name character varying(255),
    sender_last_name character varying(255),
    sender_street_address character varying(255),
    sender_street_address_2 character varying(255),
    sender_city character varying(255),
    sender_state character varying(255),
    sender_zipcode character varying(255),
    sender_zip_four character varying(255),
    sender_mobile_phone character varying(255),
    email_subject character varying(255),
    email_body text,
    resolved boolean DEFAULT false,
    resolved_at timestamp without time zone,
    resolution character varying(255),
    confirmation_code character varying(255),
    contact_congress_letter_id integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: email_congress_letter_seeds_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE email_congress_letter_seeds_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: email_congress_letter_seeds_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE email_congress_letter_seeds_id_seq OWNED BY email_congress_letter_seeds.id;


--
-- Name: facebook_templates; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE facebook_templates (
    id integer NOT NULL,
    template_name character varying(255) NOT NULL,
    content_hash character varying(255) NOT NULL,
    bundle_id character varying(255)
);


--
-- Name: facebook_templates_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE facebook_templates_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: facebook_templates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE facebook_templates_id_seq OWNED BY facebook_templates.id;


--
-- Name: facebook_user_bills; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE facebook_user_bills (
    id integer NOT NULL,
    facebook_user_id integer,
    bill_id integer,
    tracking_type character varying(255),
    comment text,
    updated_at timestamp without time zone,
    created_at timestamp without time zone
);


--
-- Name: facebook_user_bills_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE facebook_user_bills_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: facebook_user_bills_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE facebook_user_bills_id_seq OWNED BY facebook_user_bills.id;


--
-- Name: facebook_users; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE facebook_users (
    id integer NOT NULL,
    facebook_uid integer,
    facebook_session_key character varying(255),
    updated_at timestamp without time zone,
    created_at timestamp without time zone
);


--
-- Name: facebook_users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE facebook_users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: facebook_users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE facebook_users_id_seq OWNED BY facebook_users.id;


--
-- Name: featured_people; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE featured_people (
    id integer NOT NULL,
    person_id integer,
    text text,
    updated_at timestamp without time zone,
    created_at timestamp without time zone
);


--
-- Name: featured_people_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE featured_people_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: featured_people_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE featured_people_id_seq OWNED BY featured_people.id;


--
-- Name: formageddon_browser_states; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE formageddon_browser_states (
    id integer NOT NULL,
    uri text,
    cookie_jar text,
    raw_html text,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: formageddon_browser_states_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE formageddon_browser_states_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: formageddon_browser_states_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE formageddon_browser_states_id_seq OWNED BY formageddon_browser_states.id;


--
-- Name: formageddon_contact_steps; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE formageddon_contact_steps (
    id integer NOT NULL,
    formageddon_recipient_id integer,
    formageddon_recipient_type character varying(255),
    step_number integer,
    command character varying(255),
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: formageddon_contact_steps_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE formageddon_contact_steps_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: formageddon_contact_steps_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE formageddon_contact_steps_id_seq OWNED BY formageddon_contact_steps.id;


--
-- Name: formageddon_delivery_attempts; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE formageddon_delivery_attempts (
    id integer NOT NULL,
    formageddon_letter_id integer,
    result text,
    letter_contact_step integer,
    before_browser_state_id text,
    after_browser_state_id text,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    captcha_browser_state_id text
);


--
-- Name: formageddon_delivery_attempts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE formageddon_delivery_attempts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: formageddon_delivery_attempts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE formageddon_delivery_attempts_id_seq OWNED BY formageddon_delivery_attempts.id;


--
-- Name: formageddon_form_captcha_images; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE formageddon_form_captcha_images (
    id integer NOT NULL,
    formageddon_form_id integer,
    image_number integer,
    css_selector character varying(255),
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    formageddon_recaptcha_form_id integer
);


--
-- Name: formageddon_form_captcha_images_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE formageddon_form_captcha_images_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: formageddon_form_captcha_images_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE formageddon_form_captcha_images_id_seq OWNED BY formageddon_form_captcha_images.id;


--
-- Name: formageddon_form_fields; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE formageddon_form_fields (
    id integer NOT NULL,
    formageddon_form_id integer,
    field_number integer,
    name character varying(255),
    value character varying(255),
    css_selector character varying(255),
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    required boolean
);


--
-- Name: formageddon_form_fields_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE formageddon_form_fields_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: formageddon_form_fields_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE formageddon_form_fields_id_seq OWNED BY formageddon_form_fields.id;


--
-- Name: formageddon_forms; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE formageddon_forms (
    id integer NOT NULL,
    formageddon_contact_step_id integer,
    form_number integer,
    use_field_names boolean,
    success_string character varying(255),
    use_real_email_address boolean DEFAULT false,
    submit_css_selector character varying(255),
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: formageddon_forms_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE formageddon_forms_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: formageddon_forms_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE formageddon_forms_id_seq OWNED BY formageddon_forms.id;


--
-- Name: formageddon_letters; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE formageddon_letters (
    id integer NOT NULL,
    formageddon_thread_id integer,
    direction character varying(255),
    status text,
    issue_area character varying(255),
    subject text,
    message text,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    fax_id integer
);


--
-- Name: formageddon_letters_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE formageddon_letters_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: formageddon_letters_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE formageddon_letters_id_seq OWNED BY formageddon_letters.id;


--
-- Name: formageddon_recaptcha_forms; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE formageddon_recaptcha_forms (
    id integer NOT NULL,
    formageddon_form_id integer,
    url character varying(255),
    response_field_css_selector character varying(255),
    image_css_selector character varying(255),
    id_selector character varying(255),
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: formageddon_recaptcha_forms_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE formageddon_recaptcha_forms_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: formageddon_recaptcha_forms_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE formageddon_recaptcha_forms_id_seq OWNED BY formageddon_recaptcha_forms.id;


--
-- Name: formageddon_threads; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE formageddon_threads (
    id integer NOT NULL,
    formageddon_recipient_id integer,
    formageddon_recipient_type character varying(255),
    sender_title character varying(255),
    sender_first_name character varying(255),
    sender_last_name character varying(255),
    sender_address1 character varying(255),
    sender_address2 character varying(255),
    sender_city character varying(255),
    sender_state character varying(255),
    sender_zip5 character varying(255),
    sender_zip4 character varying(255),
    sender_phone character varying(255),
    sender_email character varying(255),
    privacy character varying(255),
    formageddon_sender_id integer,
    formageddon_sender_type character varying(255),
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: formageddon_threads_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE formageddon_threads_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: formageddon_threads_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE formageddon_threads_id_seq OWNED BY formageddon_threads.id;


--
-- Name: friend_emails; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE friend_emails (
    id integer NOT NULL,
    emailable_id integer NOT NULL,
    emailable_type character varying(255),
    created_at timestamp without time zone,
    ip_address character varying(255)
);


--
-- Name: friend_emails_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE friend_emails_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: friend_emails_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE friend_emails_id_seq OWNED BY friend_emails.id;


--
-- Name: friend_invites; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE friend_invites (
    id integer NOT NULL,
    inviter_id integer,
    invitee_email character varying(255),
    created_at timestamp without time zone,
    invite_key character varying(255)
);


--
-- Name: friend_invites_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE friend_invites_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: friend_invites_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE friend_invites_id_seq OWNED BY friend_invites.id;


--
-- Name: friends; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE friends (
    id integer NOT NULL,
    user_id integer,
    friend_id integer,
    confirmed boolean,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    confirmed_at timestamp without time zone
);


--
-- Name: friends_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE friends_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: friends_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE friends_id_seq OWNED BY friends.id;


--
-- Name: fundraisers; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE fundraisers (
    id integer NOT NULL,
    sunlight_id integer,
    person_id integer,
    host character varying(255),
    beneficiaries character varying(255),
    start_time timestamp without time zone,
    end_time timestamp without time zone,
    venue character varying(255),
    entertainment_type character varying(255),
    venue_address1 character varying(255),
    venue_address2 character varying(255),
    venue_city character varying(255),
    venue_state character varying(255),
    venue_zipcode character varying(255),
    venue_website character varying(255),
    contributions_info character varying(255),
    latlong character varying(255),
    rsvp_info character varying(255),
    distribution_payer character varying(255),
    make_checks_payable_to character varying(255),
    checks_payable_address character varying(255),
    committee_id character varying(255)
);


--
-- Name: fundraisers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE fundraisers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: fundraisers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE fundraisers_id_seq OWNED BY fundraisers.id;


--
-- Name: geo_ips; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE geo_ips (
    id integer NOT NULL,
    start_ip bigint,
    end_ip bigint,
    lat character varying(255),
    lng character varying(255),
    state character varying(255),
    district integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: geo_ips_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE geo_ips_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: geo_ips_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE geo_ips_id_seq OWNED BY geo_ips.id;


--
-- Name: gossip; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE gossip (
    id integer NOT NULL,
    name character varying(255),
    title character varying(255),
    email character varying(255),
    link character varying(255),
    tip text,
    frontpage boolean DEFAULT false,
    approved boolean DEFAULT false,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: gossip_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE gossip_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: gossip_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE gossip_id_seq OWNED BY gossip.id;


--
-- Name: gpo_billtext_timestamps; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE gpo_billtext_timestamps (
    id integer NOT NULL,
    session integer,
    bill_type character varying(255),
    number integer,
    version character varying(255),
    created_at timestamp without time zone
);


--
-- Name: gpo_billtext_timestamps_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE gpo_billtext_timestamps_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: gpo_billtext_timestamps_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE gpo_billtext_timestamps_id_seq OWNED BY gpo_billtext_timestamps.id;


--
-- Name: group_bill_positions; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE group_bill_positions (
    id integer NOT NULL,
    group_id integer,
    bill_id integer,
    "position" character varying(255),
    comment character varying(255),
    permalink character varying(255),
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: group_bill_positions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE group_bill_positions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: group_bill_positions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE group_bill_positions_id_seq OWNED BY group_bill_positions.id;


--
-- Name: group_invites; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE group_invites (
    id integer NOT NULL,
    group_id integer,
    user_id integer,
    email character varying(255),
    key character varying(255),
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: group_invites_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE group_invites_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: group_invites_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE group_invites_id_seq OWNED BY group_invites.id;


--
-- Name: group_members; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE group_members (
    id integer NOT NULL,
    group_id integer,
    user_id integer,
    status character varying(255),
    receive_owner_emails boolean DEFAULT true,
    last_view timestamp without time zone,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: group_members_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE group_members_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: group_members_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE group_members_id_seq OWNED BY group_members.id;


--
-- Name: groups; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE groups (
    id integer NOT NULL,
    user_id integer,
    name character varying(255),
    description text,
    join_type character varying(255),
    invite_type character varying(255),
    post_type character varying(255),
    publicly_visible boolean DEFAULT true,
    website character varying(255),
    pvs_category_id integer,
    group_image_file_name character varying(255),
    group_image_content_type character varying(255),
    group_image_file_size integer,
    group_image_updated_at timestamp without time zone,
    state_id integer,
    district_id integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    subject_id integer
);


--
-- Name: groups_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE groups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: groups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE groups_id_seq OWNED BY groups.id;


--
-- Name: hot_bill_categories; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE hot_bill_categories (
    id integer NOT NULL,
    name character varying(255)
);


--
-- Name: hot_bill_categories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE hot_bill_categories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: hot_bill_categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE hot_bill_categories_id_seq OWNED BY hot_bill_categories.id;


--
-- Name: industry_stats; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE industry_stats (
    sector_id integer NOT NULL,
    entered_top_viewed timestamp without time zone
);


--
-- Name: issue_stats; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE issue_stats (
    subject_id integer NOT NULL,
    entered_top_viewed timestamp without time zone
);


--
-- Name: mailing_list_items; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE mailing_list_items (
    id integer NOT NULL,
    mailable_type character varying(255),
    mailable_id integer,
    user_mailing_list_id integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: mailing_list_items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE mailing_list_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mailing_list_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE mailing_list_items_id_seq OWNED BY mailing_list_items.id;


--
-- Name: notebook_items; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE notebook_items (
    id integer NOT NULL,
    political_notebook_id integer,
    type character varying(255),
    url character varying(255),
    title character varying(255),
    date character varying(255),
    source character varying(255),
    description text,
    is_internal boolean,
    embed text,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    parent_id integer,
    size integer,
    width integer,
    height integer,
    filename character varying(255),
    content_type character varying(255),
    thumbnail character varying(255),
    notebookable_type character varying(255),
    notebookable_id integer,
    hot_bill_category_id integer,
    file_file_name character varying(255),
    file_content_type character varying(255),
    file_file_size integer,
    file_updated_at timestamp without time zone,
    group_user_id integer,
    user_agent character varying(255),
    ip_address character varying(255),
    spam boolean,
    censored boolean,
    data text
);


--
-- Name: notebook_items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE notebook_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: notebook_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE notebook_items_id_seq OWNED BY notebook_items.id;


--
-- Name: notification_aggregates; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE notification_aggregates (
    id integer NOT NULL,
    score integer DEFAULT 0,
    hide integer DEFAULT 0,
    user_id integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    click_count integer DEFAULT 0
);


--
-- Name: notification_aggregates_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE notification_aggregates_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: notification_aggregates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE notification_aggregates_id_seq OWNED BY notification_aggregates.id;


--
-- Name: notification_distributors; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE notification_distributors (
    id integer NOT NULL,
    notification_aggregate_id integer,
    notification_outbound_id integer,
    link_code character varying(255),
    view_count integer DEFAULT 0,
    stop_request integer DEFAULT 0,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: notification_distributors_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE notification_distributors_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: notification_distributors_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE notification_distributors_id_seq OWNED BY notification_distributors.id;


--
-- Name: notification_items; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE notification_items (
    id integer NOT NULL,
    notification_aggregate_id integer,
    activities_id integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: notification_items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE notification_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: notification_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE notification_items_id_seq OWNED BY notification_items.id;


--
-- Name: notification_outbounds; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE notification_outbounds (
    id integer NOT NULL,
    sent integer DEFAULT 0,
    received integer DEFAULT 0,
    receive_code character varying(255),
    outbound_type character varying(255),
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    is_digest boolean
);


--
-- Name: notification_outbounds_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE notification_outbounds_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: notification_outbounds_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE notification_outbounds_id_seq OWNED BY notification_outbounds.id;


--
-- Name: object_aggregates; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE object_aggregates (
    id integer NOT NULL,
    aggregatable_type character varying(255),
    aggregatable_id integer,
    date date,
    page_views_count integer DEFAULT 0,
    comments_count integer DEFAULT 0,
    blog_articles_count integer DEFAULT 0,
    news_articles_count integer DEFAULT 0,
    bookmarks_count integer DEFAULT 0,
    votes_support integer DEFAULT 0,
    votes_oppose integer DEFAULT 0
);


--
-- Name: object_aggregates_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE object_aggregates_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: object_aggregates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE object_aggregates_id_seq OWNED BY object_aggregates.id;


--
-- Name: open_id_authentication_associations; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE open_id_authentication_associations (
    id integer NOT NULL,
    issued integer,
    lifetime integer,
    handle character varying(255),
    assoc_type character varying(255),
    server_url bytea,
    secret bytea
);


--
-- Name: open_id_authentication_associations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE open_id_authentication_associations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: open_id_authentication_associations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE open_id_authentication_associations_id_seq OWNED BY open_id_authentication_associations.id;


--
-- Name: open_id_authentication_nonces; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE open_id_authentication_nonces (
    id integer NOT NULL,
    "timestamp" integer NOT NULL,
    server_url character varying(255),
    salt character varying(255) NOT NULL
);


--
-- Name: open_id_authentication_nonces_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE open_id_authentication_nonces_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: open_id_authentication_nonces_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE open_id_authentication_nonces_id_seq OWNED BY open_id_authentication_nonces.id;


--
-- Name: panel_referrers; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE panel_referrers (
    id integer NOT NULL,
    referrer_url text NOT NULL,
    panel_type character varying(255),
    views integer DEFAULT 0,
    updated_at timestamp without time zone
);


--
-- Name: panel_referrers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE panel_referrers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: panel_referrers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE panel_referrers_id_seq OWNED BY panel_referrers.id;


--
-- Name: people; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE people (
    id integer NOT NULL,
    firstname character varying(255),
    middlename character varying(255),
    lastname character varying(255),
    nickname character varying(255),
    birthday date,
    gender character varying(1),
    religion character varying(255),
    url character varying(255),
    party character varying(255),
    osid character varying(255),
    bioguideid character varying(255),
    title character varying(255),
    state character varying(255),
    district character varying(255),
    name character varying(255),
    email character varying(255),
    fti_names tsvector,
    user_approval double precision DEFAULT 5,
    biography text,
    unaccented_name character varying(255),
    metavid_id character varying(255),
    youtube_id character varying(255),
    website character varying(255),
    congress_office character varying(255),
    phone character varying(255),
    fax character varying(255),
    contact_webform character varying(255),
    watchdog_id character varying(255),
    page_views_count integer,
    news_article_count integer DEFAULT 0,
    blog_article_count integer DEFAULT 0,
    total_session_votes integer,
    votes_democratic_position integer,
    votes_republican_position integer,
    govtrack_id integer,
    fec_id character varying(255),
    thomas_id character varying(255),
    cspan_id integer,
    lis_id character varying(255),
    death_date date,
    twitter_id character varying(255)
);


--
-- Name: people_cycle_contributions; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE people_cycle_contributions (
    id integer NOT NULL,
    person_id integer,
    total_raised integer,
    top_contributor_id integer,
    top_contributor_amount integer,
    cycle character varying(255),
    updated_at timestamp without time zone
);


--
-- Name: people_cycle_contributions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE people_cycle_contributions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: people_cycle_contributions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE people_cycle_contributions_id_seq OWNED BY people_cycle_contributions.id;


--
-- Name: people_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE people_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: people_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE people_id_seq OWNED BY people.id;


--
-- Name: person_approvals; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE person_approvals (
    id integer NOT NULL,
    user_id integer,
    rating integer,
    person_id integer,
    created_at timestamp without time zone,
    update_at timestamp without time zone
);


--
-- Name: person_approvals_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE person_approvals_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: person_approvals_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE person_approvals_id_seq OWNED BY person_approvals.id;


--
-- Name: person_identifiers; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE person_identifiers (
    id integer NOT NULL,
    person_id integer,
    bioguideid character varying(255),
    namespace text,
    value text,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: person_identifiers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE person_identifiers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: person_identifiers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE person_identifiers_id_seq OWNED BY person_identifiers.id;


--
-- Name: person_stats; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE person_stats (
    person_id integer NOT NULL,
    entered_top_viewed timestamp without time zone,
    votes_most_often_with_id integer,
    votes_least_often_with_id integer,
    opposing_party_votes_most_often_with_id integer,
    same_party_votes_least_often_with_id integer,
    entered_top_news timestamp without time zone,
    entered_top_blog timestamp without time zone,
    sponsored_bills integer,
    cosponsored_bills integer,
    sponsored_bills_passed integer,
    cosponsored_bills_passed integer,
    sponsored_bills_rank integer,
    cosponsored_bills_rank integer,
    sponsored_bills_passed_rank integer,
    cosponsored_bills_passed_rank integer,
    party_votes_percentage double precision,
    party_votes_percentage_rank integer,
    abstains_percentage double precision,
    abstains integer,
    abstains_percentage_rank integer
);


SET default_with_oids = true;

--
-- Name: pg_ts_cfg; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE pg_ts_cfg (
    ts_name text NOT NULL,
    prs_name text NOT NULL,
    locale text
);


--
-- Name: pg_ts_cfgmap; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE pg_ts_cfgmap (
    ts_name text NOT NULL,
    tok_alias text NOT NULL,
    dict_name text[]
);


--
-- Name: pg_ts_dict; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE pg_ts_dict (
    dict_name text NOT NULL,
    dict_init regprocedure,
    dict_initoption text,
    dict_lexize regprocedure NOT NULL,
    dict_comment text
);


--
-- Name: pg_ts_parser; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE pg_ts_parser (
    prs_name text NOT NULL,
    prs_start regprocedure NOT NULL,
    prs_nexttoken regprocedure NOT NULL,
    prs_end regprocedure NOT NULL,
    prs_headline regprocedure NOT NULL,
    prs_lextype regprocedure NOT NULL,
    prs_comment text
);


SET default_with_oids = false;

--
-- Name: political_notebooks; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE political_notebooks (
    id integer NOT NULL,
    user_id integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    group_id integer
);


--
-- Name: political_notebooks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE political_notebooks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: political_notebooks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE political_notebooks_id_seq OWNED BY political_notebooks.id;


--
-- Name: user_privacy_options; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE user_privacy_options (
    id integer NOT NULL,
    name integer DEFAULT 1,
    email integer DEFAULT 0,
    zipcode integer DEFAULT 1,
    location integer DEFAULT 2,
    profile integer DEFAULT 2,
    actions integer DEFAULT 2,
    bookmarks integer DEFAULT 2,
    friends integer DEFAULT 2,
    user_id integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    political_notebook integer DEFAULT 2,
    watchdog integer DEFAULT 2,
    groups integer DEFAULT 2
);


--
-- Name: privacy_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE privacy_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: privacy_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE privacy_options_id_seq OWNED BY user_privacy_options.id;


--
-- Name: pvs_categories; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE pvs_categories (
    id integer NOT NULL,
    name character varying(255),
    pvs_id integer
);


--
-- Name: pvs_categories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE pvs_categories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pvs_categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE pvs_categories_id_seq OWNED BY pvs_categories.id;


--
-- Name: pvs_category_mappings; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE pvs_category_mappings (
    id integer NOT NULL,
    pvs_category_id integer,
    pvs_category_mappable_id integer,
    pvs_category_mappable_type character varying(255)
);


--
-- Name: pvs_category_mappings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE pvs_category_mappings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pvs_category_mappings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE pvs_category_mappings_id_seq OWNED BY pvs_category_mappings.id;


--
-- Name: roles; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE roles (
    id integer NOT NULL,
    person_id integer,
    role_type character varying(255),
    startdate date,
    enddate date,
    party character varying(255),
    state character varying(255),
    district character varying(255),
    url character varying(255),
    address character varying(255),
    phone character varying(255),
    email character varying(255)
);


--
-- Name: roles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE roles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: roles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE roles_id_seq OWNED BY roles.id;


--
-- Name: roll_call_votes; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE roll_call_votes (
    id integer NOT NULL,
    vote character varying(255),
    roll_call_id integer,
    person_id integer
);


--
-- Name: roll_call_votes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE roll_call_votes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: roll_call_votes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE roll_call_votes_id_seq OWNED BY roll_call_votes.id;


--
-- Name: roll_calls; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE roll_calls (
    id integer NOT NULL,
    number integer,
    "where" character varying(255),
    date timestamp without time zone,
    updated timestamp without time zone,
    roll_type text,
    question text,
    required character varying(255),
    result character varying(255),
    bill_id integer,
    amendment_id integer,
    filename character varying(255),
    ayes integer DEFAULT 0,
    nays integer DEFAULT 0,
    abstains integer DEFAULT 0,
    presents integer DEFAULT 0,
    democratic_position boolean,
    republican_position boolean,
    is_hot boolean DEFAULT false,
    title character varying(255),
    hot_date timestamp without time zone,
    page_views_count integer
);


--
-- Name: roll_calls_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE roll_calls_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: roll_calls_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE roll_calls_id_seq OWNED BY roll_calls.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE schema_migrations (
    version character varying(255) NOT NULL
);


--
-- Name: searches; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE searches (
    id integer NOT NULL,
    search_text character varying(255),
    created_at timestamp without time zone,
    search_filters text,
    page integer,
    user_id integer,
    search_congresses text
);


--
-- Name: searches_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE searches_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: searches_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE searches_id_seq OWNED BY searches.id;


--
-- Name: sidebar_boxes; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE sidebar_boxes (
    id integer NOT NULL,
    image_url character varying(255),
    box_html text,
    sidebarable_id integer,
    sidebarable_type character varying(255)
);


--
-- Name: sidebar_boxes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE sidebar_boxes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sidebar_boxes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE sidebar_boxes_id_seq OWNED BY sidebar_boxes.id;


--
-- Name: simple_captcha_data; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE simple_captcha_data (
    id integer NOT NULL,
    key character varying(40),
    value character varying(6),
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: simple_captcha_data_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE simple_captcha_data_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: simple_captcha_data_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE simple_captcha_data_id_seq OWNED BY simple_captcha_data.id;


--
-- Name: site_text_pages; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE site_text_pages (
    id integer NOT NULL,
    page_params character varying(255),
    title_tags character varying(255),
    meta_description text,
    meta_keywords character varying(255),
    title_desc text,
    page_text_editable_type text,
    page_text_editable_id integer
);


--
-- Name: site_text_pages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE site_text_pages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: site_text_pages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE site_text_pages_id_seq OWNED BY site_text_pages.id;


--
-- Name: site_texts; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE site_texts (
    id integer NOT NULL,
    text_type character varying(255),
    text text,
    updated_at timestamp without time zone
);


--
-- Name: site_texts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE site_texts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: site_texts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE site_texts_id_seq OWNED BY site_texts.id;


--
-- Name: states; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE states (
    id integer NOT NULL,
    name character varying(255),
    abbreviation character varying(255),
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: states_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE states_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: states_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE states_id_seq OWNED BY states.id;


--
-- Name: subject_relations; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE subject_relations (
    id integer NOT NULL,
    subject_id integer,
    related_subject_id integer,
    relation_count integer
);


--
-- Name: subject_relations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE subject_relations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: subject_relations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE subject_relations_id_seq OWNED BY subject_relations.id;


--
-- Name: subjects; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE subjects (
    id integer NOT NULL,
    term character varying(255),
    bill_count integer,
    fti_names tsvector,
    page_views_count integer,
    parent_id integer
);


--
-- Name: subjects_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE subjects_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: subjects_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE subjects_id_seq OWNED BY subjects.id;


--
-- Name: taggings; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE taggings (
    id integer NOT NULL,
    tag_id integer,
    taggable_id integer,
    tagger_id integer,
    tagger_type character varying(255),
    taggable_type character varying(255),
    context character varying(255),
    created_at timestamp without time zone
);


--
-- Name: taggings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE taggings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: taggings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE taggings_id_seq OWNED BY taggings.id;


--
-- Name: tags; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE tags (
    id integer NOT NULL,
    name character varying(255),
    taggings_count integer
);


--
-- Name: tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE tags_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE tags_id_seq OWNED BY tags.id;


--
-- Name: talking_points; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE talking_points (
    id integer NOT NULL,
    talking_pointable_id integer,
    talking_pointable_type character varying(255),
    talking_point text,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    include_in_message_body boolean DEFAULT false
);


--
-- Name: talking_points_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE talking_points_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: talking_points_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE talking_points_id_seq OWNED BY talking_points.id;


--
-- Name: twitter_configs; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE twitter_configs (
    id integer NOT NULL,
    user_id integer,
    secret character varying(255),
    token character varying(255),
    tracking boolean,
    bill_votes boolean,
    person_approvals boolean,
    new_notebook_items boolean,
    logins boolean,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: twitter_configs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE twitter_configs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: twitter_configs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE twitter_configs_id_seq OWNED BY twitter_configs.id;


--
-- Name: upcoming_bills; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE upcoming_bills (
    id integer NOT NULL,
    title text,
    summary text,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    fti_names tsvector
);


--
-- Name: upcoming_bills_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE upcoming_bills_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: upcoming_bills_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE upcoming_bills_id_seq OWNED BY upcoming_bills.id;


--
-- Name: user_audits; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE user_audits (
    id integer NOT NULL,
    user_id integer,
    email character varying(255),
    email_was character varying(255),
    full_name character varying(255),
    district character varying(255),
    zipcode character varying(255),
    state character varying(255),
    created_at timestamp without time zone,
    processed boolean DEFAULT false NOT NULL,
    mailing boolean DEFAULT false NOT NULL
);


--
-- Name: user_audits_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE user_audits_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_audits_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE user_audits_id_seq OWNED BY user_audits.id;


--
-- Name: user_ip_addresses; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE user_ip_addresses (
    id integer NOT NULL,
    user_id integer,
    addr bigint,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: user_ip_addresses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE user_ip_addresses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_ip_addresses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE user_ip_addresses_id_seq OWNED BY user_ip_addresses.id;


--
-- Name: user_mailing_lists; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE user_mailing_lists (
    id integer NOT NULL,
    user_id integer,
    last_processed timestamp without time zone,
    status integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: user_mailing_lists_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE user_mailing_lists_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_mailing_lists_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE user_mailing_lists_id_seq OWNED BY user_mailing_lists.id;


--
-- Name: user_notification_option_items; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE user_notification_option_items (
    id integer NOT NULL,
    feed integer,
    feed_priority character varying(255),
    email integer,
    email_frequency character varying(255),
    mobile integer,
    mobile_frequency character varying(255),
    mms_message integer,
    mms_message_frequency character varying(255),
    user_notification_option_id integer,
    activity_option_id integer,
    bookmark_id integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    aggregate_timeframe integer DEFAULT 21600
);


--
-- Name: user_notification_option_items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE user_notification_option_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_notification_option_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE user_notification_option_items_id_seq OWNED BY user_notification_option_items.id;


--
-- Name: user_notification_options; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE user_notification_options (
    id integer NOT NULL,
    email_digest_frequency character varying(255),
    user_id integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: user_notification_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE user_notification_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_notification_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE user_notification_options_id_seq OWNED BY user_notification_options.id;


--
-- Name: user_options; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE user_options (
    id integer NOT NULL,
    user_id integer,
    comment_threshold integer DEFAULT 5,
    opencongress_mail boolean DEFAULT true,
    partner_mail boolean DEFAULT false,
    sms_notifications boolean DEFAULT false,
    email_notifications boolean DEFAULT true,
    feed_key character varying(255)
);


--
-- Name: user_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE user_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE user_options_id_seq OWNED BY user_options.id;


--
-- Name: user_privacy_option_items; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE user_privacy_option_items (
    id integer NOT NULL,
    user_id integer,
    privacy_object_id integer,
    privacy_object_type character varying(255),
    method character varying(255),
    privacy integer DEFAULT 0,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: user_privacy_option_items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE user_privacy_option_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_privacy_option_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE user_privacy_option_items_id_seq OWNED BY user_privacy_option_items.id;


--
-- Name: user_profiles; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE user_profiles (
    id integer NOT NULL,
    user_id integer,
    first_name character varying(255),
    last_name character varying(255),
    website character varying(255),
    about text,
    main_picture character varying(255),
    small_picture character varying(255),
    street_address character varying(255),
    street_address_2 character varying(255),
    city character varying(255),
    zipcode character varying(5),
    zip_four character varying(4),
    mobile_phone character varying(255)
);


--
-- Name: user_profiles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE user_profiles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_profiles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE user_profiles_id_seq OWNED BY user_profiles.id;


--
-- Name: user_roles; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE user_roles (
    id integer NOT NULL,
    name character varying(255) DEFAULT ''::character varying,
    can_blog boolean DEFAULT false,
    can_administer_users boolean DEFAULT false,
    can_see_stats boolean DEFAULT false,
    can_manage_text boolean DEFAULT false,
    can_moderate_articles boolean DEFAULT false,
    can_edit_blog_tags boolean DEFAULT false
);


--
-- Name: user_roles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE user_roles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_roles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE user_roles_id_seq OWNED BY user_roles.id;


--
-- Name: user_warnings; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE user_warnings (
    id integer NOT NULL,
    user_id integer,
    warning_message text,
    warned_by integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: user_warnings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE user_warnings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_warnings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE user_warnings_id_seq OWNED BY user_warnings.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE users (
    id integer NOT NULL,
    login character varying(255),
    email character varying(255),
    crypted_password character varying(40),
    salt character varying(40),
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    remember_token character varying(255),
    remember_created_at timestamp without time zone,
    status integer DEFAULT 0,
    last_login timestamp without time zone,
    activation_code character varying(40),
    activated_at timestamp without time zone,
    password_reset_code character varying(40),
    user_role_id integer DEFAULT 0,
    representative_id integer,
    previous_login_date timestamp without time zone,
    identity_url character varying(255),
    accepted_tos_at timestamp without time zone,
    authentication_token character varying(255),
    facebook_uid character varying(255),
    possible_states text,
    possible_districts text,
    state character varying(2),
    district integer,
    district_needs_update boolean DEFAULT false
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE users_id_seq OWNED BY users.id;


--
-- Name: v_current_roles; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW v_current_roles AS
 SELECT states.id AS state_id,
    roles.id AS role_id,
    people.id AS person_id,
    roles.role_type
   FROM ((people
   JOIN roles ON ((roles.person_id = people.id)))
   JOIN states ON (((people.state)::text = (states.abbreviation)::text)))
  WHERE (roles.enddate > now());


--
-- Name: videos; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE videos (
    id integer NOT NULL,
    person_id integer,
    bill_id integer,
    embed text,
    title character varying(255),
    source character varying(255),
    video_date date,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    description text,
    url character varying(255),
    length integer
);


--
-- Name: videos_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE videos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: videos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE videos_id_seq OWNED BY videos.id;


--
-- Name: watch_dogs; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE watch_dogs (
    id integer NOT NULL,
    district_id integer,
    user_id integer,
    is_active boolean,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: watch_dogs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE watch_dogs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: watch_dogs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE watch_dogs_id_seq OWNED BY watch_dogs.id;


--
-- Name: wiki_links; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE wiki_links (
    id integer NOT NULL,
    wikiable_type character varying(255),
    wikiable_id integer,
    name character varying(255),
    oc_link character varying(255),
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: wiki_links_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE wiki_links_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: wiki_links_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE wiki_links_id_seq OWNED BY wiki_links.id;


--
-- Name: write_rep_email_msgids; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE write_rep_email_msgids (
    id integer NOT NULL,
    write_rep_email_id integer,
    person_id integer,
    status character varying(255),
    msgid integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: write_rep_email_msgids_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE write_rep_email_msgids_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: write_rep_email_msgids_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE write_rep_email_msgids_id_seq OWNED BY write_rep_email_msgids.id;


--
-- Name: write_rep_emails; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE write_rep_emails (
    id integer NOT NULL,
    user_id integer,
    prefix character varying(255),
    fname character varying(255),
    lname character varying(255),
    address character varying(255),
    zip5 character varying(255),
    zip4 character varying(255),
    city character varying(255),
    state character varying(255),
    district character varying(255),
    person_id integer,
    email character varying(255),
    phone character varying(255),
    subject character varying(255),
    msg text,
    result character varying(255),
    ip_address character varying(255),
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: write_rep_emails_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE write_rep_emails_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: write_rep_emails_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE write_rep_emails_id_seq OWNED BY write_rep_emails.id;


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY actions ALTER COLUMN id SET DEFAULT nextval('actions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY activities ALTER COLUMN id SET DEFAULT nextval('activities_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY activity_options ALTER COLUMN id SET DEFAULT nextval('activity_options_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY amendments ALTER COLUMN id SET DEFAULT nextval('amendments_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY api_hits ALTER COLUMN id SET DEFAULT nextval('api_hits_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY article_images ALTER COLUMN id SET DEFAULT nextval('article_images_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY articles ALTER COLUMN id SET DEFAULT nextval('articles_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY bad_commentaries ALTER COLUMN id SET DEFAULT nextval('bad_commentaries_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY bill_battles ALTER COLUMN id SET DEFAULT nextval('bill_battles_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY bill_interest_groups ALTER COLUMN id SET DEFAULT nextval('bill_interest_groups_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY bill_position_organizations ALTER COLUMN id SET DEFAULT nextval('bill_position_organizations_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY bill_referrers ALTER COLUMN id SET DEFAULT nextval('bill_referrers_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY bill_subjects ALTER COLUMN id SET DEFAULT nextval('bill_subjects_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY bill_text_nodes ALTER COLUMN id SET DEFAULT nextval('bill_text_nodes_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY bill_text_versions ALTER COLUMN id SET DEFAULT nextval('bill_text_versions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY bill_titles ALTER COLUMN id SET DEFAULT nextval('bill_titles_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY bill_votes ALTER COLUMN id SET DEFAULT nextval('bill_votes_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY bills ALTER COLUMN id SET DEFAULT nextval('bills_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY bills_committees ALTER COLUMN id SET DEFAULT nextval('bills_committees_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY bills_cosponsors ALTER COLUMN id SET DEFAULT nextval('bills_cosponsors_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY bills_relations ALTER COLUMN id SET DEFAULT nextval('bills_relations_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY bookmarks ALTER COLUMN id SET DEFAULT nextval('bookmarks_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY comment_scores ALTER COLUMN id SET DEFAULT nextval('comment_scores_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY commentaries ALTER COLUMN id SET DEFAULT nextval('commentaries_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY commentary_ratings ALTER COLUMN id SET DEFAULT nextval('commentary_ratings_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY comments ALTER COLUMN id SET DEFAULT nextval('comments_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY committee_meetings ALTER COLUMN id SET DEFAULT nextval('committee_meetings_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY committee_meetings_bills ALTER COLUMN id SET DEFAULT nextval('committee_meetings_bills_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY committee_names ALTER COLUMN id SET DEFAULT nextval('committee_names_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY committee_reports ALTER COLUMN id SET DEFAULT nextval('committee_reports_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY committees ALTER COLUMN id SET DEFAULT nextval('committees_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY committees_people ALTER COLUMN id SET DEFAULT nextval('committees_people_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY comparison_data_points ALTER COLUMN id SET DEFAULT nextval('comparison_data_points_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY comparisons ALTER COLUMN id SET DEFAULT nextval('comparisons_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY congress_sessions ALTER COLUMN id SET DEFAULT nextval('congress_sessions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY contact_congress_letters ALTER COLUMN id SET DEFAULT nextval('contact_congress_letters_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY contact_congress_tests ALTER COLUMN id SET DEFAULT nextval('contact_congress_tests_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY crp_industries ALTER COLUMN id SET DEFAULT nextval('crp_industries_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY crp_interest_groups ALTER COLUMN id SET DEFAULT nextval('crp_interest_groups_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY crp_pacs ALTER COLUMN id SET DEFAULT nextval('crp_pacs_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY crp_sectors ALTER COLUMN id SET DEFAULT nextval('crp_sectors_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY delayed_jobs ALTER COLUMN id SET DEFAULT nextval('delayed_jobs_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY districts ALTER COLUMN id SET DEFAULT nextval('districts_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY email_congress_letter_seeds ALTER COLUMN id SET DEFAULT nextval('email_congress_letter_seeds_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY facebook_templates ALTER COLUMN id SET DEFAULT nextval('facebook_templates_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY facebook_user_bills ALTER COLUMN id SET DEFAULT nextval('facebook_user_bills_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY facebook_users ALTER COLUMN id SET DEFAULT nextval('facebook_users_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY featured_people ALTER COLUMN id SET DEFAULT nextval('featured_people_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY formageddon_browser_states ALTER COLUMN id SET DEFAULT nextval('formageddon_browser_states_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY formageddon_contact_steps ALTER COLUMN id SET DEFAULT nextval('formageddon_contact_steps_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY formageddon_delivery_attempts ALTER COLUMN id SET DEFAULT nextval('formageddon_delivery_attempts_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY formageddon_form_captcha_images ALTER COLUMN id SET DEFAULT nextval('formageddon_form_captcha_images_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY formageddon_form_fields ALTER COLUMN id SET DEFAULT nextval('formageddon_form_fields_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY formageddon_forms ALTER COLUMN id SET DEFAULT nextval('formageddon_forms_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY formageddon_letters ALTER COLUMN id SET DEFAULT nextval('formageddon_letters_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY formageddon_recaptcha_forms ALTER COLUMN id SET DEFAULT nextval('formageddon_recaptcha_forms_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY formageddon_threads ALTER COLUMN id SET DEFAULT nextval('formageddon_threads_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY friend_emails ALTER COLUMN id SET DEFAULT nextval('friend_emails_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY friend_invites ALTER COLUMN id SET DEFAULT nextval('friend_invites_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY friends ALTER COLUMN id SET DEFAULT nextval('friends_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY fundraisers ALTER COLUMN id SET DEFAULT nextval('fundraisers_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY geo_ips ALTER COLUMN id SET DEFAULT nextval('geo_ips_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY gossip ALTER COLUMN id SET DEFAULT nextval('gossip_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY gpo_billtext_timestamps ALTER COLUMN id SET DEFAULT nextval('gpo_billtext_timestamps_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY group_bill_positions ALTER COLUMN id SET DEFAULT nextval('group_bill_positions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY group_invites ALTER COLUMN id SET DEFAULT nextval('group_invites_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY group_members ALTER COLUMN id SET DEFAULT nextval('group_members_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY groups ALTER COLUMN id SET DEFAULT nextval('groups_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY hot_bill_categories ALTER COLUMN id SET DEFAULT nextval('hot_bill_categories_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY mailing_list_items ALTER COLUMN id SET DEFAULT nextval('mailing_list_items_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY notebook_items ALTER COLUMN id SET DEFAULT nextval('notebook_items_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY notification_aggregates ALTER COLUMN id SET DEFAULT nextval('notification_aggregates_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY notification_distributors ALTER COLUMN id SET DEFAULT nextval('notification_distributors_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY notification_items ALTER COLUMN id SET DEFAULT nextval('notification_items_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY notification_outbounds ALTER COLUMN id SET DEFAULT nextval('notification_outbounds_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY object_aggregates ALTER COLUMN id SET DEFAULT nextval('object_aggregates_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY open_id_authentication_associations ALTER COLUMN id SET DEFAULT nextval('open_id_authentication_associations_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY open_id_authentication_nonces ALTER COLUMN id SET DEFAULT nextval('open_id_authentication_nonces_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY panel_referrers ALTER COLUMN id SET DEFAULT nextval('panel_referrers_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY people ALTER COLUMN id SET DEFAULT nextval('people_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY people_cycle_contributions ALTER COLUMN id SET DEFAULT nextval('people_cycle_contributions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY person_approvals ALTER COLUMN id SET DEFAULT nextval('person_approvals_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY person_identifiers ALTER COLUMN id SET DEFAULT nextval('person_identifiers_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY political_notebooks ALTER COLUMN id SET DEFAULT nextval('political_notebooks_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY pvs_categories ALTER COLUMN id SET DEFAULT nextval('pvs_categories_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY pvs_category_mappings ALTER COLUMN id SET DEFAULT nextval('pvs_category_mappings_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY roles ALTER COLUMN id SET DEFAULT nextval('roles_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY roll_call_votes ALTER COLUMN id SET DEFAULT nextval('roll_call_votes_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY roll_calls ALTER COLUMN id SET DEFAULT nextval('roll_calls_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY searches ALTER COLUMN id SET DEFAULT nextval('searches_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY sidebar_boxes ALTER COLUMN id SET DEFAULT nextval('sidebar_boxes_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY simple_captcha_data ALTER COLUMN id SET DEFAULT nextval('simple_captcha_data_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY site_text_pages ALTER COLUMN id SET DEFAULT nextval('site_text_pages_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY site_texts ALTER COLUMN id SET DEFAULT nextval('site_texts_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY states ALTER COLUMN id SET DEFAULT nextval('states_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY subject_relations ALTER COLUMN id SET DEFAULT nextval('subject_relations_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY subjects ALTER COLUMN id SET DEFAULT nextval('subjects_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY taggings ALTER COLUMN id SET DEFAULT nextval('taggings_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY tags ALTER COLUMN id SET DEFAULT nextval('tags_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY talking_points ALTER COLUMN id SET DEFAULT nextval('talking_points_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY twitter_configs ALTER COLUMN id SET DEFAULT nextval('twitter_configs_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY upcoming_bills ALTER COLUMN id SET DEFAULT nextval('upcoming_bills_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY user_audits ALTER COLUMN id SET DEFAULT nextval('user_audits_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY user_ip_addresses ALTER COLUMN id SET DEFAULT nextval('user_ip_addresses_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY user_mailing_lists ALTER COLUMN id SET DEFAULT nextval('user_mailing_lists_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY user_notification_option_items ALTER COLUMN id SET DEFAULT nextval('user_notification_option_items_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY user_notification_options ALTER COLUMN id SET DEFAULT nextval('user_notification_options_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY user_options ALTER COLUMN id SET DEFAULT nextval('user_options_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY user_privacy_option_items ALTER COLUMN id SET DEFAULT nextval('user_privacy_option_items_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY user_privacy_options ALTER COLUMN id SET DEFAULT nextval('privacy_options_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY user_profiles ALTER COLUMN id SET DEFAULT nextval('user_profiles_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY user_roles ALTER COLUMN id SET DEFAULT nextval('user_roles_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY user_warnings ALTER COLUMN id SET DEFAULT nextval('user_warnings_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY users ALTER COLUMN id SET DEFAULT nextval('users_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY videos ALTER COLUMN id SET DEFAULT nextval('videos_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY watch_dogs ALTER COLUMN id SET DEFAULT nextval('watch_dogs_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY wiki_links ALTER COLUMN id SET DEFAULT nextval('wiki_links_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY write_rep_email_msgids ALTER COLUMN id SET DEFAULT nextval('write_rep_email_msgids_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY write_rep_emails ALTER COLUMN id SET DEFAULT nextval('write_rep_emails_id_seq'::regclass);


--
-- Name: actions_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY actions
    ADD CONSTRAINT actions_pkey PRIMARY KEY (id);


--
-- Name: activities_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY activities
    ADD CONSTRAINT activities_pkey PRIMARY KEY (id);


--
-- Name: activity_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY activity_options
    ADD CONSTRAINT activity_options_pkey PRIMARY KEY (id);


--
-- Name: amendments_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY amendments
    ADD CONSTRAINT amendments_pkey PRIMARY KEY (id);


--
-- Name: api_hits_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY api_hits
    ADD CONSTRAINT api_hits_pkey PRIMARY KEY (id);


--
-- Name: article_images_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY article_images
    ADD CONSTRAINT article_images_pkey PRIMARY KEY (id);


--
-- Name: articles_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY articles
    ADD CONSTRAINT articles_pkey PRIMARY KEY (id);


--
-- Name: bill_battles_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY bill_battles
    ADD CONSTRAINT bill_battles_pkey PRIMARY KEY (id);


--
-- Name: bill_interest_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY bill_interest_groups
    ADD CONSTRAINT bill_interest_groups_pkey PRIMARY KEY (id);


--
-- Name: bill_position_organizations_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY bill_position_organizations
    ADD CONSTRAINT bill_position_organizations_pkey PRIMARY KEY (id);


--
-- Name: bill_referrers_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY bill_referrers
    ADD CONSTRAINT bill_referrers_pkey PRIMARY KEY (id);


--
-- Name: bill_subjects_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY bill_subjects
    ADD CONSTRAINT bill_subjects_pkey PRIMARY KEY (id);


--
-- Name: bill_text_nodes_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY bill_text_nodes
    ADD CONSTRAINT bill_text_nodes_pkey PRIMARY KEY (id);


--
-- Name: bill_text_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY bill_text_versions
    ADD CONSTRAINT bill_text_versions_pkey PRIMARY KEY (id);


--
-- Name: bill_titles_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY bill_titles
    ADD CONSTRAINT bill_titles_pkey PRIMARY KEY (id);


--
-- Name: bill_votes_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY bill_votes
    ADD CONSTRAINT bill_votes_pkey PRIMARY KEY (id);


--
-- Name: bills_committees_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY bills_committees
    ADD CONSTRAINT bills_committees_pkey PRIMARY KEY (id);


--
-- Name: bills_cosponsors_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY bills_cosponsors
    ADD CONSTRAINT bills_cosponsors_pkey PRIMARY KEY (id);


--
-- Name: bills_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY bills
    ADD CONSTRAINT bills_pkey PRIMARY KEY (id);


--
-- Name: bills_relations_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY bills_relations
    ADD CONSTRAINT bills_relations_pkey PRIMARY KEY (id);


--
-- Name: bookmarks_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY bookmarks
    ADD CONSTRAINT bookmarks_pkey PRIMARY KEY (id);


--
-- Name: comment_scores_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY comment_scores
    ADD CONSTRAINT comment_scores_pkey PRIMARY KEY (id);


--
-- Name: commentaries_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY commentaries
    ADD CONSTRAINT commentaries_pkey PRIMARY KEY (id);


--
-- Name: commentary_ratings_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY commentary_ratings
    ADD CONSTRAINT commentary_ratings_pkey PRIMARY KEY (id);


--
-- Name: comments_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY comments
    ADD CONSTRAINT comments_pkey PRIMARY KEY (id);


--
-- Name: commitees_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY committees
    ADD CONSTRAINT commitees_pkey PRIMARY KEY (id);


--
-- Name: committee_meetings_bills_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY committee_meetings_bills
    ADD CONSTRAINT committee_meetings_bills_pkey PRIMARY KEY (id);


--
-- Name: committee_meetings_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY committee_meetings
    ADD CONSTRAINT committee_meetings_pkey PRIMARY KEY (id);


--
-- Name: committee_names_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY committee_names
    ADD CONSTRAINT committee_names_pkey PRIMARY KEY (id);


--
-- Name: committee_reports_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY committee_reports
    ADD CONSTRAINT committee_reports_pkey PRIMARY KEY (id);


--
-- Name: committees_people_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY committees_people
    ADD CONSTRAINT committees_people_pkey PRIMARY KEY (id);


--
-- Name: comparison_data_points_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY comparison_data_points
    ADD CONSTRAINT comparison_data_points_pkey PRIMARY KEY (id);


--
-- Name: comparisons_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY comparisons
    ADD CONSTRAINT comparisons_pkey PRIMARY KEY (id);


--
-- Name: congress_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY congress_sessions
    ADD CONSTRAINT congress_sessions_pkey PRIMARY KEY (id);


--
-- Name: contact_congress_letters_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY contact_congress_letters
    ADD CONSTRAINT contact_congress_letters_pkey PRIMARY KEY (id);


--
-- Name: contact_congress_tests_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY contact_congress_tests
    ADD CONSTRAINT contact_congress_tests_pkey PRIMARY KEY (id);


--
-- Name: crp_industries_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY crp_industries
    ADD CONSTRAINT crp_industries_pkey PRIMARY KEY (id);


--
-- Name: crp_interest_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY crp_interest_groups
    ADD CONSTRAINT crp_interest_groups_pkey PRIMARY KEY (id);


--
-- Name: crp_pacs_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY crp_pacs
    ADD CONSTRAINT crp_pacs_pkey PRIMARY KEY (id);


--
-- Name: crp_sectors_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY crp_sectors
    ADD CONSTRAINT crp_sectors_pkey PRIMARY KEY (id);


--
-- Name: delayed_jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY delayed_jobs
    ADD CONSTRAINT delayed_jobs_pkey PRIMARY KEY (id);


--
-- Name: districts_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY districts
    ADD CONSTRAINT districts_pkey PRIMARY KEY (id);


--
-- Name: email_congress_letter_seeds_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY email_congress_letter_seeds
    ADD CONSTRAINT email_congress_letter_seeds_pkey PRIMARY KEY (id);


--
-- Name: facebook_templates_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY facebook_templates
    ADD CONSTRAINT facebook_templates_pkey PRIMARY KEY (id);


--
-- Name: facebook_user_bills_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY facebook_user_bills
    ADD CONSTRAINT facebook_user_bills_pkey PRIMARY KEY (id);


--
-- Name: facebook_users_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY facebook_users
    ADD CONSTRAINT facebook_users_pkey PRIMARY KEY (id);


--
-- Name: featured_people_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY featured_people
    ADD CONSTRAINT featured_people_pkey PRIMARY KEY (id);


--
-- Name: formageddon_browser_states_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY formageddon_browser_states
    ADD CONSTRAINT formageddon_browser_states_pkey PRIMARY KEY (id);


--
-- Name: formageddon_contact_steps_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY formageddon_contact_steps
    ADD CONSTRAINT formageddon_contact_steps_pkey PRIMARY KEY (id);


--
-- Name: formageddon_delivery_attempts_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY formageddon_delivery_attempts
    ADD CONSTRAINT formageddon_delivery_attempts_pkey PRIMARY KEY (id);


--
-- Name: formageddon_form_captcha_images_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY formageddon_form_captcha_images
    ADD CONSTRAINT formageddon_form_captcha_images_pkey PRIMARY KEY (id);


--
-- Name: formageddon_form_fields_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY formageddon_form_fields
    ADD CONSTRAINT formageddon_form_fields_pkey PRIMARY KEY (id);


--
-- Name: formageddon_forms_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY formageddon_forms
    ADD CONSTRAINT formageddon_forms_pkey PRIMARY KEY (id);


--
-- Name: formageddon_letters_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY formageddon_letters
    ADD CONSTRAINT formageddon_letters_pkey PRIMARY KEY (id);


--
-- Name: formageddon_recaptcha_forms_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY formageddon_recaptcha_forms
    ADD CONSTRAINT formageddon_recaptcha_forms_pkey PRIMARY KEY (id);


--
-- Name: formageddon_threads_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY formageddon_threads
    ADD CONSTRAINT formageddon_threads_pkey PRIMARY KEY (id);


--
-- Name: friend_emails_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY friend_emails
    ADD CONSTRAINT friend_emails_pkey PRIMARY KEY (id);


--
-- Name: friend_invites_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY friend_invites
    ADD CONSTRAINT friend_invites_pkey PRIMARY KEY (id);


--
-- Name: friends_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY friends
    ADD CONSTRAINT friends_pkey PRIMARY KEY (id);


--
-- Name: fundraisers_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY fundraisers
    ADD CONSTRAINT fundraisers_pkey PRIMARY KEY (id);


--
-- Name: geo_ips_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY geo_ips
    ADD CONSTRAINT geo_ips_pkey PRIMARY KEY (id);


--
-- Name: gossip_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY gossip
    ADD CONSTRAINT gossip_pkey PRIMARY KEY (id);


--
-- Name: gpo_billtext_timestamps_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY gpo_billtext_timestamps
    ADD CONSTRAINT gpo_billtext_timestamps_pkey PRIMARY KEY (id);


--
-- Name: group_bill_positions_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY group_bill_positions
    ADD CONSTRAINT group_bill_positions_pkey PRIMARY KEY (id);


--
-- Name: group_invites_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY group_invites
    ADD CONSTRAINT group_invites_pkey PRIMARY KEY (id);


--
-- Name: group_members_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY group_members
    ADD CONSTRAINT group_members_pkey PRIMARY KEY (id);


--
-- Name: groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY groups
    ADD CONSTRAINT groups_pkey PRIMARY KEY (id);


--
-- Name: hot_bill_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY hot_bill_categories
    ADD CONSTRAINT hot_bill_categories_pkey PRIMARY KEY (id);


--
-- Name: mailing_list_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY mailing_list_items
    ADD CONSTRAINT mailing_list_items_pkey PRIMARY KEY (id);


--
-- Name: notebook_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY notebook_items
    ADD CONSTRAINT notebook_items_pkey PRIMARY KEY (id);


--
-- Name: notification_aggregates_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY notification_aggregates
    ADD CONSTRAINT notification_aggregates_pkey PRIMARY KEY (id);


--
-- Name: notification_distributors_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY notification_distributors
    ADD CONSTRAINT notification_distributors_pkey PRIMARY KEY (id);


--
-- Name: notification_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY notification_items
    ADD CONSTRAINT notification_items_pkey PRIMARY KEY (id);


--
-- Name: notification_outbounds_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY notification_outbounds
    ADD CONSTRAINT notification_outbounds_pkey PRIMARY KEY (id);


--
-- Name: object_aggregates_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY object_aggregates
    ADD CONSTRAINT object_aggregates_pkey PRIMARY KEY (id);


--
-- Name: open_id_authentication_associations_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY open_id_authentication_associations
    ADD CONSTRAINT open_id_authentication_associations_pkey PRIMARY KEY (id);


--
-- Name: open_id_authentication_nonces_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY open_id_authentication_nonces
    ADD CONSTRAINT open_id_authentication_nonces_pkey PRIMARY KEY (id);


--
-- Name: panel_referrers_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY panel_referrers
    ADD CONSTRAINT panel_referrers_pkey PRIMARY KEY (id);


--
-- Name: people_cycle_contributions_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY people_cycle_contributions
    ADD CONSTRAINT people_cycle_contributions_pkey PRIMARY KEY (id);


--
-- Name: people_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY people
    ADD CONSTRAINT people_pkey PRIMARY KEY (id);


--
-- Name: person_approvals_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY person_approvals
    ADD CONSTRAINT person_approvals_pkey PRIMARY KEY (id);


--
-- Name: person_identifiers_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY person_identifiers
    ADD CONSTRAINT person_identifiers_pkey PRIMARY KEY (id);


--
-- Name: pg_ts_cfg_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY pg_ts_cfg
    ADD CONSTRAINT pg_ts_cfg_pkey PRIMARY KEY (ts_name);


--
-- Name: pg_ts_cfgmap_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY pg_ts_cfgmap
    ADD CONSTRAINT pg_ts_cfgmap_pkey PRIMARY KEY (ts_name, tok_alias);


--
-- Name: pg_ts_dict_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY pg_ts_dict
    ADD CONSTRAINT pg_ts_dict_pkey PRIMARY KEY (dict_name);


--
-- Name: pg_ts_parser_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY pg_ts_parser
    ADD CONSTRAINT pg_ts_parser_pkey PRIMARY KEY (prs_name);


--
-- Name: political_notebooks_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY political_notebooks
    ADD CONSTRAINT political_notebooks_pkey PRIMARY KEY (id);


--
-- Name: privacy_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY user_privacy_options
    ADD CONSTRAINT privacy_options_pkey PRIMARY KEY (id);


--
-- Name: pvs_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY pvs_categories
    ADD CONSTRAINT pvs_categories_pkey PRIMARY KEY (id);


--
-- Name: pvs_category_mappings_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY pvs_category_mappings
    ADD CONSTRAINT pvs_category_mappings_pkey PRIMARY KEY (id);


--
-- Name: roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (id);


--
-- Name: roll_call_votes_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY roll_call_votes
    ADD CONSTRAINT roll_call_votes_pkey PRIMARY KEY (id);


--
-- Name: roll_calls_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY roll_calls
    ADD CONSTRAINT roll_calls_pkey PRIMARY KEY (id);


--
-- Name: searches_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY searches
    ADD CONSTRAINT searches_pkey PRIMARY KEY (id);


--
-- Name: sidebar_boxes_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY sidebar_boxes
    ADD CONSTRAINT sidebar_boxes_pkey PRIMARY KEY (id);


--
-- Name: simple_captcha_data_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY simple_captcha_data
    ADD CONSTRAINT simple_captcha_data_pkey PRIMARY KEY (id);


--
-- Name: site_text_pages_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY site_text_pages
    ADD CONSTRAINT site_text_pages_pkey PRIMARY KEY (id);


--
-- Name: site_texts_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY site_texts
    ADD CONSTRAINT site_texts_pkey PRIMARY KEY (id);


--
-- Name: states_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY states
    ADD CONSTRAINT states_pkey PRIMARY KEY (id);


--
-- Name: subject_relations_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY subject_relations
    ADD CONSTRAINT subject_relations_pkey PRIMARY KEY (id);


--
-- Name: subjects_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY subjects
    ADD CONSTRAINT subjects_pkey PRIMARY KEY (id);


--
-- Name: taggings_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY taggings
    ADD CONSTRAINT taggings_pkey PRIMARY KEY (id);


--
-- Name: tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY tags
    ADD CONSTRAINT tags_pkey PRIMARY KEY (id);


--
-- Name: talking_points_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY talking_points
    ADD CONSTRAINT talking_points_pkey PRIMARY KEY (id);


--
-- Name: twitter_configs_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY twitter_configs
    ADD CONSTRAINT twitter_configs_pkey PRIMARY KEY (id);


--
-- Name: unique_email; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY users
    ADD CONSTRAINT unique_email UNIQUE (email);


--
-- Name: upcoming_bills_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY upcoming_bills
    ADD CONSTRAINT upcoming_bills_pkey PRIMARY KEY (id);


--
-- Name: user_audits_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY user_audits
    ADD CONSTRAINT user_audits_pkey PRIMARY KEY (id);


--
-- Name: user_ip_addresses_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY user_ip_addresses
    ADD CONSTRAINT user_ip_addresses_pkey PRIMARY KEY (id);


--
-- Name: user_mailing_lists_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY user_mailing_lists
    ADD CONSTRAINT user_mailing_lists_pkey PRIMARY KEY (id);


--
-- Name: user_notification_option_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY user_notification_option_items
    ADD CONSTRAINT user_notification_option_items_pkey PRIMARY KEY (id);


--
-- Name: user_notification_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY user_notification_options
    ADD CONSTRAINT user_notification_options_pkey PRIMARY KEY (id);


--
-- Name: user_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY user_options
    ADD CONSTRAINT user_options_pkey PRIMARY KEY (id);


--
-- Name: user_privacy_option_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY user_privacy_option_items
    ADD CONSTRAINT user_privacy_option_items_pkey PRIMARY KEY (id);


--
-- Name: user_profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY user_profiles
    ADD CONSTRAINT user_profiles_pkey PRIMARY KEY (id);


--
-- Name: user_roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY user_roles
    ADD CONSTRAINT user_roles_pkey PRIMARY KEY (id);


--
-- Name: user_warnings_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY user_warnings
    ADD CONSTRAINT user_warnings_pkey PRIMARY KEY (id);


--
-- Name: users_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: videos_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY videos
    ADD CONSTRAINT videos_pkey PRIMARY KEY (id);


--
-- Name: watch_dogs_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY watch_dogs
    ADD CONSTRAINT watch_dogs_pkey PRIMARY KEY (id);


--
-- Name: wiki_links_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY wiki_links
    ADD CONSTRAINT wiki_links_pkey PRIMARY KEY (id);


--
-- Name: write_rep_email_msgids_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY write_rep_email_msgids
    ADD CONSTRAINT write_rep_email_msgids_pkey PRIMARY KEY (id);


--
-- Name: write_rep_emails_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY write_rep_emails
    ADD CONSTRAINT write_rep_emails_pkey PRIMARY KEY (id);


--
-- Name: actions_bill_id_index; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX actions_bill_id_index ON actions USING btree (bill_id);


--
-- Name: aggregatable_date_poly_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX aggregatable_date_poly_idx ON object_aggregates USING btree (date, aggregatable_type, aggregatable_id);


--
-- Name: aggregatable_date_type_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX aggregatable_date_type_idx ON object_aggregates USING btree (date, aggregatable_type);


--
-- Name: aggregatable_poly_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX aggregatable_poly_idx ON object_aggregates USING btree (aggregatable_type, aggregatable_id);


--
-- Name: amendments_bill_id_index; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX amendments_bill_id_index ON amendments USING btree (bill_id, number);


--
-- Name: articles_created_at_index; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX articles_created_at_index ON articles USING btree (created_at);


--
-- Name: articles_fti_names_index; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX articles_fti_names_index ON articles USING gist (fti_names);


--
-- Name: bill_fti_names_index; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX bill_fti_names_index ON bill_fulltext USING gist (fti_names);


--
-- Name: bill_fulltext_bill_id_index; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX bill_fulltext_bill_id_index ON bill_fulltext USING btree (bill_id);


--
-- Name: bill_subjects_subject_id_index; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX bill_subjects_subject_id_index ON bill_subjects USING btree (subject_id);


--
-- Name: bill_titles_bill_id_index; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX bill_titles_bill_id_index ON bill_titles USING btree (bill_id);


--
-- Name: bill_titles_fti_titles_index; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX bill_titles_fti_titles_index ON bill_titles USING gist (fti_titles);


--
-- Name: bill_titles_title_index; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX bill_titles_title_index ON bill_titles USING btree (title);


--
-- Name: bill_titles_upper_title_index; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX bill_titles_upper_title_index ON bill_titles USING btree (upper(title));


--
-- Name: bills_number_index; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX bills_number_index ON bills USING btree (number, session, bill_type);


--
-- Name: bills_relations_bill_id_index; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX bills_relations_bill_id_index ON bills_relations USING btree (bill_id, related_bill_id);


--
-- Name: bills_sponsor_id_index; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX bills_sponsor_id_index ON bills USING btree (sponsor_id);


--
-- Name: commentaries_url_index; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX commentaries_url_index ON commentaries USING btree (url);


--
-- Name: commentary_fti_names_index; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX commentary_fti_names_index ON commentaries USING gist (fti_names);


--
-- Name: comments_fti_names_index; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX comments_fti_names_index ON comments USING gist (fti_names);


--
-- Name: committee_reports_name_index; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX committee_reports_name_index ON committee_reports USING btree (name);


--
-- Name: committees_fti_names_index; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX committees_fti_names_index ON committees USING gist (fti_names);


--
-- Name: contactable_index; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX contactable_index ON contact_congress_letters USING btree (contactable_id, contactable_type);


--
-- Name: delayed_jobs_priority; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX delayed_jobs_priority ON delayed_jobs USING btree (priority, run_at);


--
-- Name: formageddon_cs_recipient_index; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX formageddon_cs_recipient_index ON formageddon_contact_steps USING btree (formageddon_recipient_id, formageddon_recipient_type);


--
-- Name: formageddon_t_recipient_index; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX formageddon_t_recipient_index ON formageddon_threads USING btree (formageddon_recipient_id, formageddon_recipient_type);


--
-- Name: friend_emails_created_at_index; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX friend_emails_created_at_index ON friend_emails USING btree (created_at);


--
-- Name: friend_emails_ip_address_index; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX friend_emails_ip_address_index ON friend_emails USING btree (ip_address);


--
-- Name: idx_key; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX idx_key ON simple_captcha_data USING btree (key);


--
-- Name: index_actions_on_roll_call_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_actions_on_roll_call_id ON actions USING btree (roll_call_id);


--
-- Name: index_activities_on_owner_id_and_owner_type; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_activities_on_owner_id_and_owner_type ON activities USING btree (owner_id, owner_type);


--
-- Name: index_activities_on_recipient_id_and_recipient_type; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_activities_on_recipient_id_and_recipient_type ON activities USING btree (recipient_id, recipient_type);


--
-- Name: index_activities_on_trackable_id_and_trackable_type; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_activities_on_trackable_id_and_trackable_type ON activities USING btree (trackable_id, trackable_type);


--
-- Name: index_activity_options_on_key; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_activity_options_on_key ON activity_options USING btree (key);


--
-- Name: index_bad_commentaries_on_cid_and_ctype; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_bad_commentaries_on_cid_and_ctype ON bad_commentaries USING btree (commentariable_id, commentariable_type);


--
-- Name: index_bad_commentaries_on_url; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_bad_commentaries_on_url ON bad_commentaries USING btree (url);


--
-- Name: index_bill_position_organizations_on_bill_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_bill_position_organizations_on_bill_id ON bill_position_organizations USING btree (bill_id);


--
-- Name: index_bill_referrers_on_bill_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_bill_referrers_on_bill_id ON bill_referrers USING btree (bill_id);


--
-- Name: index_bill_referrers_on_url; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_bill_referrers_on_url ON bill_referrers USING btree (url);


--
-- Name: index_bill_subjects_on_bill_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_bill_subjects_on_bill_id ON bill_subjects USING btree (bill_id);


--
-- Name: index_bill_text_nodes_on_bill_text_version_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_bill_text_nodes_on_bill_text_version_id ON bill_text_nodes USING btree (bill_text_version_id);


--
-- Name: index_bill_text_nodes_on_nid; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_bill_text_nodes_on_nid ON bill_text_nodes USING btree (nid);


--
-- Name: index_bill_text_versions_on_bill_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_bill_text_versions_on_bill_id ON bill_text_versions USING btree (bill_id);


--
-- Name: index_bill_votes_on_bill_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_bill_votes_on_bill_id ON bill_votes USING btree (bill_id);


--
-- Name: index_bill_votes_on_created_at; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_bill_votes_on_created_at ON bill_votes USING btree (created_at);


--
-- Name: index_bill_votes_on_user_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_bill_votes_on_user_id ON bill_votes USING btree (user_id);


--
-- Name: index_bills_committees_on_bill_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_bills_committees_on_bill_id ON bills_committees USING btree (bill_id);


--
-- Name: index_bills_committees_on_committee_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_bills_committees_on_committee_id ON bills_committees USING btree (committee_id);


--
-- Name: index_bills_cosponsors_on_bill_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_bills_cosponsors_on_bill_id ON bills_cosponsors USING btree (bill_id);


--
-- Name: index_bills_cosponsors_on_person_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_bills_cosponsors_on_person_id ON bills_cosponsors USING btree (person_id);


--
-- Name: index_bills_on_hot_bill_category_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_bills_on_hot_bill_category_id ON bills USING btree (hot_bill_category_id);


--
-- Name: index_bills_on_id_and_session; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_bills_on_id_and_session ON bills USING btree (id, session);


--
-- Name: index_bills_on_introduced; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_bills_on_introduced ON bills USING btree (introduced);


--
-- Name: index_bills_on_session; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_bills_on_session ON bills USING btree (session);


--
-- Name: index_bookmarks_on_bookmarkable_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_bookmarks_on_bookmarkable_id ON bookmarks USING btree (bookmarkable_id);


--
-- Name: index_bookmarks_on_bookmarkable_type; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_bookmarks_on_bookmarkable_type ON bookmarks USING btree (bookmarkable_type);


--
-- Name: index_bookmarks_on_user_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_bookmarks_on_user_id ON bookmarks USING btree (user_id);


--
-- Name: index_cclft_cclid; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_cclft_cclid ON contact_congress_letters_formageddon_threads USING btree (contact_congress_letter_id);


--
-- Name: index_cclft_ftid; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_cclft_ftid ON contact_congress_letters_formageddon_threads USING btree (formageddon_thread_id);


--
-- Name: index_comment_scores_on_comment_id_and_ip_address; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_comment_scores_on_comment_id_and_ip_address ON comment_scores USING btree (comment_id, ip_address);


--
-- Name: index_commentaries_on_commentariable_id_and_commentariable_type; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_commentaries_on_commentariable_id_and_commentariable_type ON commentaries USING btree (commentariable_id, commentariable_type, is_ok, is_news);


--
-- Name: index_commentaries_on_commentariable_type_and_date_and_is_ok_an; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_commentaries_on_commentariable_type_and_date_and_is_ok_an ON commentaries USING btree (commentariable_type, date, is_ok, is_news);


--
-- Name: index_commentaries_on_status; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_commentaries_on_status ON commentaries USING btree (status);


--
-- Name: index_comments_on_commentable_id_and_commentable_type; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_comments_on_commentable_id_and_commentable_type ON comments USING btree (commentable_id, commentable_type);


--
-- Name: index_comments_on_commentable_type; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_comments_on_commentable_type ON comments USING btree (commentable_type);


--
-- Name: index_comments_on_created_at_and_commentable_type; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_comments_on_created_at_and_commentable_type ON comments USING btree (created_at, commentable_type);


--
-- Name: index_comments_on_ok; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_comments_on_ok ON comments USING btree (ok);


--
-- Name: index_comments_on_parent_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_comments_on_parent_id ON comments USING btree (parent_id);


--
-- Name: index_comments_on_root_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_comments_on_root_id ON comments USING btree (root_id);


--
-- Name: index_comments_on_user_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_comments_on_user_id ON comments USING btree (user_id);


--
-- Name: index_committees_on_thomas_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_committees_on_thomas_id ON committees USING btree (thomas_id);


--
-- Name: index_congress_sessions_on_date; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_congress_sessions_on_date ON congress_sessions USING btree (date);


--
-- Name: index_crp_contrib_individual_to_candidate_on_crp_interest_group; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_crp_contrib_individual_to_candidate_on_crp_interest_group ON crp_contrib_individual_to_candidate USING btree (crp_interest_group_osid);


--
-- Name: index_crp_contrib_individual_to_candidate_on_recipient_osid; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_crp_contrib_individual_to_candidate_on_recipient_osid ON crp_contrib_individual_to_candidate USING btree (recipient_osid);


--
-- Name: index_crp_contrib_pac_to_candidate_on_crp_interest_group_osid; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_crp_contrib_pac_to_candidate_on_crp_interest_group_osid ON crp_contrib_pac_to_candidate USING btree (crp_interest_group_osid);


--
-- Name: index_crp_contrib_pac_to_candidate_on_recipient_osid; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_crp_contrib_pac_to_candidate_on_recipient_osid ON crp_contrib_pac_to_candidate USING btree (recipient_osid);


--
-- Name: index_crp_interest_groups_on_osid; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_crp_interest_groups_on_osid ON crp_interest_groups USING btree (osid);


--
-- Name: index_email_congress_letter_seeds_on_confirmation_code; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_email_congress_letter_seeds_on_confirmation_code ON email_congress_letter_seeds USING btree (confirmation_code);


--
-- Name: index_facebook_templates_on_template_name; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_facebook_templates_on_template_name ON facebook_templates USING btree (template_name);


--
-- Name: index_formageddon_delivery_attempts_on_formageddon_letter_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_formageddon_delivery_attempts_on_formageddon_letter_id ON formageddon_delivery_attempts USING btree (formageddon_letter_id);


--
-- Name: index_formageddon_form_captcha_images_on_formageddon_form_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_formageddon_form_captcha_images_on_formageddon_form_id ON formageddon_form_captcha_images USING btree (formageddon_form_id);


--
-- Name: index_formageddon_form_fields_on_formageddon_form_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_formageddon_form_fields_on_formageddon_form_id ON formageddon_form_fields USING btree (formageddon_form_id);


--
-- Name: index_formageddon_forms_on_formageddon_contact_step_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_formageddon_forms_on_formageddon_contact_step_id ON formageddon_forms USING btree (formageddon_contact_step_id);


--
-- Name: index_formageddon_letters_on_formageddon_thread_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_formageddon_letters_on_formageddon_thread_id ON formageddon_letters USING btree (formageddon_thread_id);


--
-- Name: index_fundraisers_on_person_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_fundraisers_on_person_id ON fundraisers USING btree (person_id);


--
-- Name: index_geo_ips_on_start_ip_and_end_ip; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_geo_ips_on_start_ip_and_end_ip ON geo_ips USING btree (start_ip, end_ip);


--
-- Name: index_group_members_on_group_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_group_members_on_group_id ON group_members USING btree (group_id);


--
-- Name: index_group_members_on_user_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_group_members_on_user_id ON group_members USING btree (user_id);


--
-- Name: index_lower_tag_names; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_lower_tag_names ON tags USING btree (lower((name)::text));


--
-- Name: index_notebook_items_on_censored; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_notebook_items_on_censored ON notebook_items USING btree (censored);


--
-- Name: index_notebook_items_on_political_notebook_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_notebook_items_on_political_notebook_id ON notebook_items USING btree (political_notebook_id);


--
-- Name: index_notebook_items_on_spam; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_notebook_items_on_spam ON notebook_items USING btree (spam);


--
-- Name: index_notification_aggregates_on_user_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_notification_aggregates_on_user_id ON notification_aggregates USING btree (user_id);


--
-- Name: index_notification_distributors_on_notification_aggregate_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_notification_distributors_on_notification_aggregate_id ON notification_distributors USING btree (notification_aggregate_id);


--
-- Name: index_notification_distributors_on_notification_outbound_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_notification_distributors_on_notification_outbound_id ON notification_distributors USING btree (notification_outbound_id);


--
-- Name: index_notification_items_on_activities_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_notification_items_on_activities_id ON notification_items USING btree (activities_id);


--
-- Name: index_notification_items_on_notification_aggregate_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_notification_items_on_notification_aggregate_id ON notification_items USING btree (notification_aggregate_id);


--
-- Name: index_people_on_cspan_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_people_on_cspan_id ON people USING btree (cspan_id);


--
-- Name: index_people_on_district; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_people_on_district ON people USING btree (district);


--
-- Name: index_people_on_fec_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_people_on_fec_id ON people USING btree (fec_id);


--
-- Name: index_people_on_govtrack_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_people_on_govtrack_id ON people USING btree (govtrack_id);


--
-- Name: index_people_on_lis_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_people_on_lis_id ON people USING btree (lis_id);


--
-- Name: index_people_on_state; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_people_on_state ON people USING btree (state);


--
-- Name: index_people_on_thomas_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_people_on_thomas_id ON people USING btree (thomas_id);


--
-- Name: index_people_on_title; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_people_on_title ON people USING btree (title);


--
-- Name: index_person_identifiers_on_bioguideid; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_person_identifiers_on_bioguideid ON person_identifiers USING btree (bioguideid);


--
-- Name: index_political_notebooks_on_group_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_political_notebooks_on_group_id ON political_notebooks USING btree (group_id);


--
-- Name: index_privacy_options_on_user_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_privacy_options_on_user_id ON user_privacy_options USING btree (user_id);


--
-- Name: index_roles_on_enddate; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_roles_on_enddate ON roles USING btree (enddate);


--
-- Name: index_roles_on_person_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_roles_on_person_id ON roles USING btree (person_id);


--
-- Name: index_roles_on_role_type; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_roles_on_role_type ON roles USING btree (role_type);


--
-- Name: index_roles_on_startdate; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_roles_on_startdate ON roles USING btree (startdate);


--
-- Name: index_roll_call_votes_on_roll_call_id_and_vote; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_roll_call_votes_on_roll_call_id_and_vote ON roll_call_votes USING btree (roll_call_id, vote);


--
-- Name: index_roll_calls_on_amendment_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_roll_calls_on_amendment_id ON roll_calls USING btree (amendment_id);


--
-- Name: index_roll_calls_on_bill_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_roll_calls_on_bill_id ON roll_calls USING btree (bill_id);


--
-- Name: index_roll_calls_on_where_and_number_and_date; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_roll_calls_on_where_and_number_and_date ON roll_calls USING btree ("where", number, date);


--
-- Name: index_searches_lower_search_text; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_searches_lower_search_text ON searches USING btree (lower((search_text)::text));


--
-- Name: index_searches_on_created_at; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_searches_on_created_at ON searches USING btree (created_at);


--
-- Name: index_taggings_on_tag_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_taggings_on_tag_id ON taggings USING btree (tag_id);


--
-- Name: index_taggings_on_taggable_id_and_taggable_type_and_context; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_taggings_on_taggable_id_and_taggable_type_and_context ON taggings USING btree (taggable_id, taggable_type, context);


--
-- Name: index_unoi_on_uno_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_unoi_on_uno_id ON user_notification_option_items USING btree (user_notification_option_id);


--
-- Name: index_user_notification_option_items_on_activity_option_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_user_notification_option_items_on_activity_option_id ON user_notification_option_items USING btree (activity_option_id);


--
-- Name: index_user_notification_option_items_on_bookmark_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_user_notification_option_items_on_bookmark_id ON user_notification_option_items USING btree (bookmark_id);


--
-- Name: index_user_options_on_email_notifications; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_user_options_on_email_notifications ON user_options USING btree (email_notifications);


--
-- Name: index_user_options_on_feed_key; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_user_options_on_feed_key ON user_options USING btree (feed_key);


--
-- Name: index_user_options_on_opencongress_mail; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_user_options_on_opencongress_mail ON user_options USING btree (opencongress_mail);


--
-- Name: index_user_options_on_partner_mail; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_user_options_on_partner_mail ON user_options USING btree (partner_mail);


--
-- Name: index_user_options_on_sms_notifications; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_user_options_on_sms_notifications ON user_options USING btree (sms_notifications);


--
-- Name: index_user_options_on_user_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_user_options_on_user_id ON user_options USING btree (user_id);


--
-- Name: index_user_po_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_user_po_id ON user_privacy_option_items USING btree (privacy_object_id);


--
-- Name: index_user_po_type; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_user_po_type ON user_privacy_option_items USING btree (privacy_object_type);


--
-- Name: index_user_privacy_option_items_on_user_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_user_privacy_option_items_on_user_id ON user_privacy_option_items USING btree (user_id);


--
-- Name: index_user_profiles_on_user_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_user_profiles_on_user_id ON user_profiles USING btree (user_id);


--
-- Name: index_user_profiles_on_zipcode; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_user_profiles_on_zipcode ON user_profiles USING btree (zipcode);


--
-- Name: index_user_profiles_on_zipcode_and_zip_four; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_user_profiles_on_zipcode_and_zip_four ON user_profiles USING btree (zipcode, zip_four);


--
-- Name: index_users_on_facebook_uid; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_users_on_facebook_uid ON users USING btree (facebook_uid);


--
-- Name: index_users_on_login; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_users_on_login ON users USING btree (login);


--
-- Name: index_users_on_status; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_users_on_status ON users USING btree (status);


--
-- Name: index_videos_on_bill_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_videos_on_bill_id ON videos USING btree (bill_id);


--
-- Name: index_videos_on_embed; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_videos_on_embed ON videos USING btree (embed);


--
-- Name: index_videos_on_person_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_videos_on_person_id ON videos USING btree (person_id);


--
-- Name: index_videos_on_url; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_videos_on_url ON videos USING btree (url);


--
-- Name: panel_referrers_panel_type_index; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX panel_referrers_panel_type_index ON panel_referrers USING btree (panel_type);


--
-- Name: panel_referrers_referrer_url_index; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX panel_referrers_referrer_url_index ON panel_referrers USING btree (referrer_url);


--
-- Name: people_cycle_contributions_person_id_index; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX people_cycle_contributions_person_id_index ON people_cycle_contributions USING btree (person_id);


--
-- Name: people_firstname_index; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX people_firstname_index ON people USING btree (firstname, lastname);


--
-- Name: people_fti_names_index; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX people_fti_names_index ON people USING gist (fti_names);


--
-- Name: roll_call_votes_person_id_index; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX roll_call_votes_person_id_index ON roll_call_votes USING btree (person_id);


--
-- Name: roll_call_votes_roll_call_id_index; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX roll_call_votes_roll_call_id_index ON roll_call_votes USING btree (roll_call_id);


--
-- Name: sidebarable_poly_idx; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX sidebarable_poly_idx ON sidebar_boxes USING btree (sidebarable_id, sidebarable_type);


--
-- Name: site_texts_text_type_index; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX site_texts_text_type_index ON site_texts USING btree (text_type);


--
-- Name: subject_fti_names_index; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX subject_fti_names_index ON subjects USING gist (fti_names);


--
-- Name: subject_relations_subject_id_index; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX subject_relations_subject_id_index ON subject_relations USING btree (subject_id, related_subject_id, relation_count);


--
-- Name: subjects_term_index; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX subjects_term_index ON subjects USING btree (term);


--
-- Name: u_email; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX u_email ON users USING btree (email);


--
-- Name: u_users; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX u_users ON users USING btree (login);


--
-- Name: unique_schema_migrations; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX unique_schema_migrations ON schema_migrations USING btree (version);


--
-- Name: upcoming_bill_fti_names_index; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX upcoming_bill_fti_names_index ON upcoming_bills USING gist (fti_names);


--
-- Name: users_lower_email_index; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX users_lower_email_index ON users USING btree (lower((email)::text));


--
-- Name: users_lower_login_index; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX users_lower_login_index ON users USING btree (lower((login)::text));


--
-- Name: users_state_district_index; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX users_state_district_index ON users USING btree (state, district);


--
-- Name: users_state_index; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX users_state_index ON users USING btree (state);


--
-- Name: aggregate_bill_votes_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER aggregate_bill_votes_trigger AFTER INSERT ON bill_votes FOR EACH ROW EXECUTE PROCEDURE aggregate_increment();


--
-- Name: aggregate_bookmark_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER aggregate_bookmark_trigger AFTER INSERT ON bookmarks FOR EACH ROW EXECUTE PROCEDURE aggregate_increment();


--
-- Name: aggregate_comment_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER aggregate_comment_trigger AFTER INSERT ON comments FOR EACH ROW EXECUTE PROCEDURE aggregate_increment();


--
-- Name: aggregate_commentaries_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER aggregate_commentaries_trigger AFTER INSERT ON commentaries FOR EACH ROW EXECUTE PROCEDURE aggregate_increment();


--
-- Name: article_tsvectorupdate; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER article_tsvectorupdate BEFORE INSERT OR UPDATE ON articles FOR EACH ROW EXECUTE PROCEDURE tsearch2('fti_names', 'article');


--
-- Name: bill_titles_tsvectorupdate; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER bill_titles_tsvectorupdate BEFORE INSERT OR UPDATE ON bill_titles FOR EACH ROW EXECUTE PROCEDURE tsearch2('fti_titles', 'title');


--
-- Name: bill_tsvectorupdate; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER bill_tsvectorupdate BEFORE INSERT OR UPDATE ON bill_fulltext FOR EACH ROW EXECUTE PROCEDURE tsearch2('fti_names', 'fulltext');


--
-- Name: commentary_tsvectorupdate; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER commentary_tsvectorupdate BEFORE INSERT OR UPDATE ON commentaries FOR EACH ROW EXECUTE PROCEDURE tsearch2('fti_names', 'title', 'excerpt', 'source');


--
-- Name: comments_tsvectorupdate; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER comments_tsvectorupdate BEFORE INSERT ON comments FOR EACH ROW EXECUTE PROCEDURE tsearch2('fti_names', 'comment');


--
-- Name: committee_tsvectorupdate; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER committee_tsvectorupdate BEFORE INSERT OR UPDATE ON committees FOR EACH ROW EXECUTE PROCEDURE tsearch2('fti_names', 'name', 'subcommittee_name');


--
-- Name: people_tsvectorupdate; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER people_tsvectorupdate BEFORE INSERT OR UPDATE ON people FOR EACH ROW EXECUTE PROCEDURE tsearch2('fti_names', 'name', 'firstname', 'lastname', 'nickname', 'unaccented_name');


--
-- Name: subject_tsvectorupdate; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER subject_tsvectorupdate BEFORE INSERT OR UPDATE ON subjects FOR EACH ROW EXECUTE PROCEDURE tsearch2('fti_names', 'term');


--
-- Name: upcoming_bill_tsvectorupdate; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER upcoming_bill_tsvectorupdate BEFORE INSERT OR UPDATE ON upcoming_bills FOR EACH ROW EXECUTE PROCEDURE tsearch2('fti_names', 'title', 'summary');


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user",public;

INSERT INTO schema_migrations (version) VALUES ('20080715215558');

INSERT INTO schema_migrations (version) VALUES ('20080827015858');

INSERT INTO schema_migrations (version) VALUES ('20080903003226');

INSERT INTO schema_migrations (version) VALUES ('20080907060146');

INSERT INTO schema_migrations (version) VALUES ('20080909001523');

INSERT INTO schema_migrations (version) VALUES ('20080911013335');

INSERT INTO schema_migrations (version) VALUES ('20080920112404');

INSERT INTO schema_migrations (version) VALUES ('20080925163620');

INSERT INTO schema_migrations (version) VALUES ('20081006011103');

INSERT INTO schema_migrations (version) VALUES ('20081009022845');

INSERT INTO schema_migrations (version) VALUES ('20081009022933');

INSERT INTO schema_migrations (version) VALUES ('20081014232042');

INSERT INTO schema_migrations (version) VALUES ('20081111025433');

INSERT INTO schema_migrations (version) VALUES ('20081113024227');

INSERT INTO schema_migrations (version) VALUES ('20081117030534');

INSERT INTO schema_migrations (version) VALUES ('20081117235038');

INSERT INTO schema_migrations (version) VALUES ('20081120012826');

INSERT INTO schema_migrations (version) VALUES ('20081120013057');

INSERT INTO schema_migrations (version) VALUES ('20081205060112');

INSERT INTO schema_migrations (version) VALUES ('20081229015856');

INSERT INTO schema_migrations (version) VALUES ('20081231021047');

INSERT INTO schema_migrations (version) VALUES ('20090101045551');

INSERT INTO schema_migrations (version) VALUES ('20090107164906');

INSERT INTO schema_migrations (version) VALUES ('20090107194724');

INSERT INTO schema_migrations (version) VALUES ('20090114032254');

INSERT INTO schema_migrations (version) VALUES ('20090116012326');

INSERT INTO schema_migrations (version) VALUES ('20090117175416');

INSERT INTO schema_migrations (version) VALUES ('20090121035742');

INSERT INTO schema_migrations (version) VALUES ('20090127025149');

INSERT INTO schema_migrations (version) VALUES ('20090131202631');

INSERT INTO schema_migrations (version) VALUES ('20090211014032');

INSERT INTO schema_migrations (version) VALUES ('20090216070042');

INSERT INTO schema_migrations (version) VALUES ('20090218020012');

INSERT INTO schema_migrations (version) VALUES ('20090224013934');

INSERT INTO schema_migrations (version) VALUES ('20090227040428');

INSERT INTO schema_migrations (version) VALUES ('20090304022259');

INSERT INTO schema_migrations (version) VALUES ('20090307153137');

INSERT INTO schema_migrations (version) VALUES ('20090325033857');

INSERT INTO schema_migrations (version) VALUES ('20090407234228');

INSERT INTO schema_migrations (version) VALUES ('20090417195827');

INSERT INTO schema_migrations (version) VALUES ('20090503234738');

INSERT INTO schema_migrations (version) VALUES ('20090512214848');

INSERT INTO schema_migrations (version) VALUES ('20090527004131');

INSERT INTO schema_migrations (version) VALUES ('20090527004445');

INSERT INTO schema_migrations (version) VALUES ('20090527014302');

INSERT INTO schema_migrations (version) VALUES ('20090602062417');

INSERT INTO schema_migrations (version) VALUES ('20090604142844');

INSERT INTO schema_migrations (version) VALUES ('20090604201433');

INSERT INTO schema_migrations (version) VALUES ('20090622211253');

INSERT INTO schema_migrations (version) VALUES ('20090626002723');

INSERT INTO schema_migrations (version) VALUES ('20090706235137');

INSERT INTO schema_migrations (version) VALUES ('20090722010931');

INSERT INTO schema_migrations (version) VALUES ('20090724212938');

INSERT INTO schema_migrations (version) VALUES ('20090725235957');

INSERT INTO schema_migrations (version) VALUES ('20090727163317');

INSERT INTO schema_migrations (version) VALUES ('20090730113924');

INSERT INTO schema_migrations (version) VALUES ('20090804203516');

INSERT INTO schema_migrations (version) VALUES ('20090804203939');

INSERT INTO schema_migrations (version) VALUES ('20090807221541');

INSERT INTO schema_migrations (version) VALUES ('20090908235658');

INSERT INTO schema_migrations (version) VALUES ('20090909000743');

INSERT INTO schema_migrations (version) VALUES ('20091109001926');

INSERT INTO schema_migrations (version) VALUES ('20091201223051');

INSERT INTO schema_migrations (version) VALUES ('20091204191227');

INSERT INTO schema_migrations (version) VALUES ('20091207182604');

INSERT INTO schema_migrations (version) VALUES ('20100122185532');

INSERT INTO schema_migrations (version) VALUES ('20100225005011');

INSERT INTO schema_migrations (version) VALUES ('20100227110831');

INSERT INTO schema_migrations (version) VALUES ('20100228211106');

INSERT INTO schema_migrations (version) VALUES ('20100401235324');

INSERT INTO schema_migrations (version) VALUES ('20100515215737');

INSERT INTO schema_migrations (version) VALUES ('20100630211146');

INSERT INTO schema_migrations (version) VALUES ('20100707180635');

INSERT INTO schema_migrations (version) VALUES ('20100707183122');

INSERT INTO schema_migrations (version) VALUES ('20100727093528');

INSERT INTO schema_migrations (version) VALUES ('20100921190837');

INSERT INTO schema_migrations (version) VALUES ('20101001114446');

INSERT INTO schema_migrations (version) VALUES ('20101017042656');

INSERT INTO schema_migrations (version) VALUES ('20101023022759');

INSERT INTO schema_migrations (version) VALUES ('20101114023941');

INSERT INTO schema_migrations (version) VALUES ('20101209200331');

INSERT INTO schema_migrations (version) VALUES ('20110130211130');

INSERT INTO schema_migrations (version) VALUES ('20110217225301');

INSERT INTO schema_migrations (version) VALUES ('20110306192052');

INSERT INTO schema_migrations (version) VALUES ('20110507004548');

INSERT INTO schema_migrations (version) VALUES ('20110518182519');

INSERT INTO schema_migrations (version) VALUES ('20110518233248');

INSERT INTO schema_migrations (version) VALUES ('20110526181158');

INSERT INTO schema_migrations (version) VALUES ('20110526194928');

INSERT INTO schema_migrations (version) VALUES ('20110610045033');

INSERT INTO schema_migrations (version) VALUES ('20110610165044');

INSERT INTO schema_migrations (version) VALUES ('20110614175640');

INSERT INTO schema_migrations (version) VALUES ('20110710171354');

INSERT INTO schema_migrations (version) VALUES ('20110715185602');

INSERT INTO schema_migrations (version) VALUES ('20110727204907');

INSERT INTO schema_migrations (version) VALUES ('20110727212839');

INSERT INTO schema_migrations (version) VALUES ('20110823164612');

INSERT INTO schema_migrations (version) VALUES ('20111108013246');

INSERT INTO schema_migrations (version) VALUES ('20120221205815');

INSERT INTO schema_migrations (version) VALUES ('20120223065756');

INSERT INTO schema_migrations (version) VALUES ('20120316192137');

INSERT INTO schema_migrations (version) VALUES ('20120328034800');

INSERT INTO schema_migrations (version) VALUES ('20120411194442');

INSERT INTO schema_migrations (version) VALUES ('20120418060145');

INSERT INTO schema_migrations (version) VALUES ('20121109062237');

INSERT INTO schema_migrations (version) VALUES ('20130510185903');

INSERT INTO schema_migrations (version) VALUES ('20130510195434');

INSERT INTO schema_migrations (version) VALUES ('20130513143249');

INSERT INTO schema_migrations (version) VALUES ('20130513161056');

INSERT INTO schema_migrations (version) VALUES ('20130513161057');

INSERT INTO schema_migrations (version) VALUES ('20130513161058');

INSERT INTO schema_migrations (version) VALUES ('20130513161059');

INSERT INTO schema_migrations (version) VALUES ('20130513161101');

INSERT INTO schema_migrations (version) VALUES ('20130513161102');

INSERT INTO schema_migrations (version) VALUES ('20130513161103');

INSERT INTO schema_migrations (version) VALUES ('20130513161104');

INSERT INTO schema_migrations (version) VALUES ('20130515155725');

INSERT INTO schema_migrations (version) VALUES ('20130515155804');

INSERT INTO schema_migrations (version) VALUES ('20130515202944');

INSERT INTO schema_migrations (version) VALUES ('20130520194814');

INSERT INTO schema_migrations (version) VALUES ('20130520215026');

INSERT INTO schema_migrations (version) VALUES ('20130529202250');

INSERT INTO schema_migrations (version) VALUES ('20130603162527');

INSERT INTO schema_migrations (version) VALUES ('20130610204402');

INSERT INTO schema_migrations (version) VALUES ('20130611184728');

INSERT INTO schema_migrations (version) VALUES ('20130612173123');

INSERT INTO schema_migrations (version) VALUES ('20130612173328');

INSERT INTO schema_migrations (version) VALUES ('20130612173500');

INSERT INTO schema_migrations (version) VALUES ('20130618200447');

INSERT INTO schema_migrations (version) VALUES ('20130619104901');

INSERT INTO schema_migrations (version) VALUES ('20130619151801');

INSERT INTO schema_migrations (version) VALUES ('20130621154335');

INSERT INTO schema_migrations (version) VALUES ('20130711201905');

INSERT INTO schema_migrations (version) VALUES ('20130715212051');

INSERT INTO schema_migrations (version) VALUES ('20130719202154');

INSERT INTO schema_migrations (version) VALUES ('20130719214306');

INSERT INTO schema_migrations (version) VALUES ('20130722153332');

INSERT INTO schema_migrations (version) VALUES ('20130722153333');

INSERT INTO schema_migrations (version) VALUES ('20130722153334');

INSERT INTO schema_migrations (version) VALUES ('20130723171431');

INSERT INTO schema_migrations (version) VALUES ('20130729212119');

INSERT INTO schema_migrations (version) VALUES ('20130730152004');

INSERT INTO schema_migrations (version) VALUES ('20130731175925');

INSERT INTO schema_migrations (version) VALUES ('20130802184955');

INSERT INTO schema_migrations (version) VALUES ('20130802185104');

INSERT INTO schema_migrations (version) VALUES ('20130806140701');

INSERT INTO schema_migrations (version) VALUES ('20130806193347');

INSERT INTO schema_migrations (version) VALUES ('20130809181846');

INSERT INTO schema_migrations (version) VALUES ('20130827172637');

INSERT INTO schema_migrations (version) VALUES ('20130828203512');

INSERT INTO schema_migrations (version) VALUES ('20130828204121');

INSERT INTO schema_migrations (version) VALUES ('20130828210341');

INSERT INTO schema_migrations (version) VALUES ('20130905183202');

INSERT INTO schema_migrations (version) VALUES ('20130905183306');

INSERT INTO schema_migrations (version) VALUES ('20130916175720');

INSERT INTO schema_migrations (version) VALUES ('20130917182708');

INSERT INTO schema_migrations (version) VALUES ('20131002033053');

INSERT INTO schema_migrations (version) VALUES ('20131002201637');

INSERT INTO schema_migrations (version) VALUES ('20131003212901');

INSERT INTO schema_migrations (version) VALUES ('20131004154111');

INSERT INTO schema_migrations (version) VALUES ('20131011174853');

INSERT INTO schema_migrations (version) VALUES ('20131018171632');

INSERT INTO schema_migrations (version) VALUES ('20131019155004');

INSERT INTO schema_migrations (version) VALUES ('20131101021519');

INSERT INTO schema_migrations (version) VALUES ('20131114023854');

INSERT INTO schema_migrations (version) VALUES ('20140123201750');

INSERT INTO schema_migrations (version) VALUES ('20140123223304');

INSERT INTO schema_migrations (version) VALUES ('20140226164454');

INSERT INTO schema_migrations (version) VALUES ('20140226215155');

INSERT INTO schema_migrations (version) VALUES ('20140226215232');

INSERT INTO schema_migrations (version) VALUES ('20140227164554');

INSERT INTO schema_migrations (version) VALUES ('20140228205612');

INSERT INTO schema_migrations (version) VALUES ('20140303192501');

INSERT INTO schema_migrations (version) VALUES ('20140325180029');

INSERT INTO schema_migrations (version) VALUES ('20140327165723');

INSERT INTO schema_migrations (version) VALUES ('20140327185831');

INSERT INTO schema_migrations (version) VALUES ('20140327190733');

INSERT INTO schema_migrations (version) VALUES ('20140424162909');

INSERT INTO schema_migrations (version) VALUES ('20140424162910');

INSERT INTO schema_migrations (version) VALUES ('20140424191444');

INSERT INTO schema_migrations (version) VALUES ('20140428184119');

INSERT INTO schema_migrations (version) VALUES ('20140430212934');

INSERT INTO schema_migrations (version) VALUES ('20140501171622');

INSERT INTO schema_migrations (version) VALUES ('20140505200431');

INSERT INTO schema_migrations (version) VALUES ('20140505204300');

INSERT INTO schema_migrations (version) VALUES ('20140514213731');

INSERT INTO schema_migrations (version) VALUES ('20140516204547');

INSERT INTO schema_migrations (version) VALUES ('20140520154656');

INSERT INTO schema_migrations (version) VALUES ('20140523141728');

INSERT INTO schema_migrations (version) VALUES ('20140723174758');

INSERT INTO schema_migrations (version) VALUES ('20140731155926');

INSERT INTO schema_migrations (version) VALUES ('20140731184412');

INSERT INTO schema_migrations (version) VALUES ('20140827210416');

INSERT INTO schema_migrations (version) VALUES ('20140908175416');

INSERT INTO schema_migrations (version) VALUES ('20140910155039');

INSERT INTO schema_migrations (version) VALUES ('20140911165000');

INSERT INTO schema_migrations (version) VALUES ('20140911172552');

INSERT INTO schema_migrations (version) VALUES ('20140911215027');

INSERT INTO schema_migrations (version) VALUES ('20140916103555');

INSERT INTO schema_migrations (version) VALUES ('20140916113742');

INSERT INTO schema_migrations (version) VALUES ('20140926213853');

INSERT INTO schema_migrations (version) VALUES ('20140929213333');

INSERT INTO schema_migrations (version) VALUES ('20140929215301');

INSERT INTO schema_migrations (version) VALUES ('20141001173322');

INSERT INTO schema_migrations (version) VALUES ('20141006153954');

INSERT INTO schema_migrations (version) VALUES ('20141007163915');

INSERT INTO schema_migrations (version) VALUES ('20141008222429');

INSERT INTO schema_migrations (version) VALUES ('20141009154958');

INSERT INTO schema_migrations (version) VALUES ('20141010144456');

INSERT INTO schema_migrations (version) VALUES ('20141010192805');

INSERT INTO schema_migrations (version) VALUES ('20141020171359');

