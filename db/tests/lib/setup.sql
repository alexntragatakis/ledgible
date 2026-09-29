CREATE EXTENSION IF NOT EXISTS pgtap;

INSERT INTO accounts (user_id, name, type, currency) VALUES
  ('pgtap_a', 'Liabilities:Visa-4417',       'liability', 'USD'),
  ('pgtap_a', 'Expenses:Groceries:Dairy',    'expense',   'USD'),
  ('pgtap_a', 'Expenses:Groceries:Produce',  'expense',   'USD'),
  ('pgtap_a', 'Expenses:Groceries:Packaged', 'expense',   'USD'),
  ('pgtap_a', 'Expenses:Tax',                'expense',   'USD'),
  ('pgtap_a', 'Assets:Wallet-CAD',           'asset',     'CAD'),
  ('pgtap_b', 'Expenses:Groceries:Dairy',    'expense',   'USD');

CREATE FUNCTION pg_temp.a(p_name text) RETURNS bigint LANGUAGE sql STABLE AS
$$ SELECT id FROM accounts WHERE user_id = 'pgtap_a' AND name = p_name $$;

CREATE FUNCTION pg_temp.b(p_name text) RETURNS bigint LANGUAGE sql STABLE AS
$$ SELECT id FROM accounts WHERE user_id = 'pgtap_b' AND name = p_name $$;

CREATE FUNCTION pg_temp.entry(p_key text) RETURNS bigint LANGUAGE sql STABLE AS
$$ SELECT id FROM journal_entries WHERE idempotency_key = p_key $$;

CREATE FUNCTION pg_temp.balance(p_account bigint) RETURNS bigint LANGUAGE sql STABLE AS
$$ SELECT coalesce(sum(amount_cents), 0)::bigint FROM postings WHERE account_id = p_account $$;

CREATE FUNCTION pg_temp.insert_entry(
  p_key text, p_accounts bigint[], p_amounts bigint[], p_reverses bigint DEFAULT NULL
) RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE
  v_id bigint;
BEGIN
  INSERT INTO journal_entries (user_id, occurred_at, description, idempotency_key, reverses_entry_id)
  VALUES ('pgtap_a', now(), 'pgtap ' || p_key, p_key, p_reverses)
  RETURNING id INTO v_id;

  INSERT INTO postings (journal_entry_id, account_id, amount_cents)
  SELECT v_id, acct, amt FROM unnest(p_accounts, p_amounts) AS u(acct, amt);

  RETURN v_id;
END;
$$;

CREATE FUNCTION pg_temp.check_now() RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  SET CONSTRAINTS ALL IMMEDIATE;
  SET CONSTRAINTS ALL DEFERRED;
END;
$$;

CREATE FUNCTION pg_temp.post_entry(
  p_key text, p_accounts bigint[], p_amounts bigint[], p_reverses bigint DEFAULT NULL
) RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE
  v_id bigint;
BEGIN
  v_id := pg_temp.insert_entry(p_key, p_accounts, p_amounts, p_reverses);
  PERFORM pg_temp.check_now();
  RETURN v_id;
END;
$$;

CREATE FUNCTION pg_temp.reverse_entry(p_original_key text, p_key text) RETURNS bigint
LANGUAGE plpgsql AS $$
DECLARE
  v_accounts bigint[];
  v_amounts  bigint[];
BEGIN
  SELECT array_agg(account_id ORDER BY id), array_agg(-amount_cents ORDER BY id)
    INTO v_accounts, v_amounts
    FROM postings WHERE journal_entry_id = pg_temp.entry(p_original_key);
  RETURN pg_temp.post_entry(p_key, v_accounts, v_amounts, pg_temp.entry(p_original_key));
END;
$$;

CREATE FUNCTION pg_temp.as_app(p_sql text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  SET LOCAL ROLE ledgible_app;
  EXECUTE p_sql;
  SET CONSTRAINTS ALL IMMEDIATE;
  SET CONSTRAINTS ALL DEFERRED;
  RESET ROLE;
END;
$$;
