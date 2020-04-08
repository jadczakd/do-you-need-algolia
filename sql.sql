/* Vectors on the fly */
select * from movies where to_tsvector(title || overview || original_title) @@ to_tsquery('Batman');

select * from cards where to_tsvector(name || coalesce(text,'') ) @@ to_tsquery('Island');

/* separate columns */
alter table movies add column tsv tsvector;
update movies set tsv = to_tsvector(title || overview || original_title);

alter table cards add column tsv tsvector;
update cards set tsv = to_tsvector(name || coalesce(text, ''));

/* explain */
select * from cards where name ilike '%island%' or text ilike '%island%';
select * from cards where tsv @@ to_tsquery('Island');

explain analyze select * from cards where to_tsvector(name || coalesce(text, '')) @@ to_tsquery('Island');
explain analyze select * from cards where tsv @@ to_tsquery('Island');
explain analyze select * from cards where name ~ '%island%' or text ~ '%island%';

/* index */
create index tsv_idx_cards on cards using gin(tsv);
create index tsv_idx_movies on movies using gin(tsv);

select * from movies where to_tsvector(title || overview || original_title) @@ to_tsquery('Batman');
alter table movies add column tsv2 tsvector;
update movies set tsv2 = to_tsvector(title || overview || original_title);
explain analyze select * from movies where tsv2 @@ to_tsquery('King');
explain analyze select * from movies where tsv @@ to_tsquery('King');

/* sorting by ranking */

select * from cards where tsv @@ to_tsquery('island') order by ts_rank(tsv, to_tsquery('island'));

/* adding weights */
alter table cards add column tsv_weights tsvector;
update cards set tsv_weights = setweight(to_tsvector(name), 'B') || setweight(to_tsvector(text), 'A');
select ts_rank(tsv_weights, to_tsquery('Island')), * from cards where tsv_weights @@ to_tsquery('Island') order by ts_rank(tsv_weights, to_tsquery('Island')) desc;
/* update by trigger */
CREATE FUNCTION card_tsvector_trigger ()
	RETURNS TRIGGER
	AS $$
begin new.tsv_weights :=setweight(to_tsvector(name), 'B') || setweight(to_tsvector(coalesce(text, '')), 'A');
return new;
END
$$
LANGUAGE plpgsql;

CREATE TRIGGER tsvweightsupdate
	BEFORE INSERT
	OR UPDATE ON cards FOR EACH ROW
	EXECUTE PROCEDURE card_tsvector_trigger ();

/* multi word queries */
select * from cards where tsv @@ to_tsquery('Sw:*<->Mou:*');
select * from cards where tsv @@ to_tsquery('Sw:*<->Fore:*');
select * from cards where tsv @@ to_tsquery('Sw:*<2>Fore:*');
/* materialized view */
CREATE MATERIALIZED VIEW cards_search AS 
SELECT ... 
REFRESH MATERIALIZED VIEW search_index;.