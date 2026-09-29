CREATE FUNCTION assert_entry_balanced(p_entry_id bigint) RETURNS void
LANGUAGE plpgsql AS $$
DECLARE
  e           journal_entries%ROWTYPE;
  n_postings  int;
  total       bigint;
  n_foreign   int;
  n_currency  int;
BEGIN
  SELECT * INTO e FROM journal_entries WHERE id = p_entry_id;
  IF NOT FOUND THEN
    RETURN;
  END IF;

  SELECT count(*),
         coalesce(sum(p.amount_cents), 0),
         count(*) FILTER (WHERE a.user_id <> e.user_id),
         count(DISTINCT a.currency)
    INTO n_postings, total, n_foreign, n_currency
    FROM postings p
    JOIN accounts a ON a.id = p.account_id
   WHERE p.journal_entry_id = p_entry_id;

  IF n_postings < 2 THEN
    RAISE EXCEPTION 'journal entry % has % posting(s); at least 2 required', p_entry_id, n_postings
      USING ERRCODE = 'check_violation';
  END IF;

  IF total <> 0 THEN
    RAISE EXCEPTION 'journal entry % is unbalanced: postings sum to % cents', p_entry_id, total
      USING ERRCODE = 'check_violation';
  END IF;

  IF n_foreign > 0 THEN
    RAISE EXCEPTION 'journal entry % posts to % account(s) owned by another user', p_entry_id, n_foreign
      USING ERRCODE = 'check_violation';
  END IF;

  IF n_currency > 1 THEN
    RAISE EXCEPTION 'journal entry % mixes currencies', p_entry_id
      USING ERRCODE = 'check_violation';
  END IF;

  IF e.reverses_entry_id IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM journal_entries
                    WHERE id = e.reverses_entry_id AND user_id = e.user_id) THEN
      RAISE EXCEPTION 'journal entry % reverses an entry owned by another user', p_entry_id
        USING ERRCODE = 'check_violation';
    END IF;

    IF EXISTS (
      (SELECT account_id, -amount_cents FROM postings WHERE journal_entry_id = e.reverses_entry_id
       EXCEPT ALL
       SELECT account_id, amount_cents FROM postings WHERE journal_entry_id = p_entry_id)
      UNION ALL
      (SELECT account_id, amount_cents FROM postings WHERE journal_entry_id = p_entry_id
       EXCEPT ALL
       SELECT account_id, -amount_cents FROM postings WHERE journal_entry_id = e.reverses_entry_id)
    ) THEN
      RAISE EXCEPTION 'journal entry % does not exactly negate entry %', p_entry_id, e.reverses_entry_id
        USING ERRCODE = 'check_violation';
    END IF;
  END IF;
END;
$$;

CREATE FUNCTION postings_check_trigger() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP IN ('UPDATE', 'DELETE') THEN
    PERFORM assert_entry_balanced(OLD.journal_entry_id);
  END IF;
  IF TG_OP IN ('INSERT', 'UPDATE') THEN
    PERFORM assert_entry_balanced(NEW.journal_entry_id);
  END IF;
  RETURN NULL;
END;
$$;

CREATE FUNCTION journal_entries_check_trigger() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  PERFORM assert_entry_balanced(NEW.id);
  RETURN NULL;
END;
$$;

CREATE CONSTRAINT TRIGGER postings_balanced
  AFTER INSERT OR UPDATE OR DELETE ON postings
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW EXECUTE FUNCTION postings_check_trigger();

CREATE CONSTRAINT TRIGGER journal_entries_balanced
  AFTER INSERT OR UPDATE ON journal_entries
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW EXECUTE FUNCTION journal_entries_check_trigger();
