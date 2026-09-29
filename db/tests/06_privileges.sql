BEGIN;
\ir lib/setup.sql
SELECT plan(9);

SELECT table_privs_are('public', 'journal_entries', 'ledgible_app', ARRAY['SELECT', 'INSERT'],
  'app role has only SELECT, INSERT on journal_entries');
SELECT table_privs_are('public', 'postings', 'ledgible_app', ARRAY['SELECT', 'INSERT'],
  'app role has only SELECT, INSERT on postings');
SELECT table_privs_are('public', 'accounts', 'ledgible_app', ARRAY['SELECT', 'INSERT'],
  'app role has only SELECT, INSERT on accounts');

SELECT throws_ok($$ SELECT pg_temp.as_app('DELETE FROM postings') $$,
  '42501', NULL, 'app role cannot DELETE postings');
SELECT throws_ok($$ SELECT pg_temp.as_app('UPDATE postings SET amount_cents = 1') $$,
  '42501', NULL, 'app role cannot UPDATE postings');
SELECT throws_ok($$ SELECT pg_temp.as_app('DELETE FROM journal_entries') $$,
  '42501', NULL, 'app role cannot DELETE journal entries');
SELECT throws_ok($$ SELECT pg_temp.as_app('UPDATE journal_entries SET description = ''x''') $$,
  '42501', NULL, 'app role cannot UPDATE journal entries');

SELECT lives_ok(
  $$ SELECT pg_temp.as_app(
       'INSERT INTO accounts (user_id, name, type) VALUES (''pgtap_a'', ''Expenses:Household'', ''expense'')') $$,
  'app role can INSERT accounts'
);

SELECT lives_ok(
  $$ SELECT pg_temp.as_app($sql$
       WITH e AS (
         INSERT INTO journal_entries (user_id, occurred_at, description, idempotency_key)
         VALUES ('pgtap_a', now(), 'pgtap as app', 't06-app-entry')
         RETURNING id
       )
       INSERT INTO postings (journal_entry_id, account_id, amount_cents)
       SELECT e.id, acct.id, x.amt
         FROM e
         CROSS JOIN (VALUES ('Liabilities:Visa-4417', -250), ('Expenses:Groceries:Dairy', 250)) AS x(name, amt)
         JOIN accounts acct ON acct.user_id = 'pgtap_a' AND acct.name = x.name
     $sql$) $$,
  'app role can post a balanced entry, commit-time check included'
);

SELECT * FROM finish();
ROLLBACK;
