BEGIN;
\ir lib/setup.sql
SELECT plan(8);

SELECT throws_like(
  $$ SELECT pg_temp.post_entry('t05-empty', '{}'::bigint[], '{}'::bigint[]) $$,
  '%has 0 posting(s); at least 2 required%',
  'entry with no postings is rejected'
);

SELECT throws_like(
  $$ SELECT pg_temp.post_entry('t05-single',
       ARRAY[pg_temp.a('Expenses:Groceries:Dairy')], ARRAY[100]) $$,
  '%has 1 posting(s); at least 2 required%',
  'entry with a single posting is rejected'
);

SELECT throws_like(
  $$ SELECT pg_temp.post_entry('t05-zero',
       ARRAY[pg_temp.a('Liabilities:Visa-4417'), pg_temp.a('Expenses:Groceries:Dairy')],
       ARRAY[0, 0]) $$,
  '%postings_amount_cents_check%',
  'zero-amount posting is rejected'
);

SELECT throws_like(
  $$ SELECT pg_temp.post_entry('t05-cross-user',
       ARRAY[pg_temp.a('Liabilities:Visa-4417'), pg_temp.b('Expenses:Groceries:Dairy')],
       ARRAY[-100, 100]) $$,
  '%owned by another user%',
  'posting to another user''s account is rejected'
);

SELECT throws_like(
  $$ SELECT pg_temp.post_entry('t05-currency',
       ARRAY[pg_temp.a('Liabilities:Visa-4417'), pg_temp.a('Assets:Wallet-CAD')],
       ARRAY[-100, 100]) $$,
  '%mixes currencies%',
  'entry mixing USD and CAD accounts is rejected'
);

SELECT pg_temp.post_entry('t05-original',
  ARRAY[pg_temp.a('Liabilities:Visa-4417'), pg_temp.a('Expenses:Groceries:Dairy')],
  ARRAY[-700, 700]);

SELECT throws_ok(
  $$ SELECT pg_temp.post_entry('t05-original',
       ARRAY[pg_temp.a('Liabilities:Visa-4417'), pg_temp.a('Expenses:Groceries:Dairy')],
       ARRAY[-700, 700]) $$,
  '23505', NULL,
  'retry with the same idempotency key is rejected'
);

SELECT throws_like(
  $$ SELECT pg_temp.post_entry('t05-bad-reversal',
       ARRAY[pg_temp.a('Liabilities:Visa-4417'), pg_temp.a('Expenses:Groceries:Dairy')],
       ARRAY[600, -600], pg_temp.entry('t05-original')) $$,
  '%does not exactly negate%',
  'reversal that does not exactly negate the original is rejected'
);

SELECT pg_temp.reverse_entry('t05-original', 't05-reversal-1');

SELECT throws_ok(
  $$ SELECT pg_temp.reverse_entry('t05-original', 't05-reversal-2') $$,
  '23505', NULL,
  'an entry cannot be reversed twice'
);

SELECT * FROM finish();
ROLLBACK;
