BEGIN;
\ir lib/setup.sql
SELECT plan(3);

SELECT lives_ok(
  $$ SELECT pg_temp.post_entry('t01',
       ARRAY[pg_temp.a('Liabilities:Visa-4417'), pg_temp.a('Expenses:Groceries:Dairy')],
       ARRAY[-500, 500]) $$,
  'balanced 2-posting entry commits'
);

SELECT is(pg_temp.balance(pg_temp.a('Expenses:Groceries:Dairy')), 500::bigint,
  'expense account balance is derived as +500');

SELECT is(pg_temp.balance(pg_temp.a('Liabilities:Visa-4417')), -500::bigint,
  'card liability balance is derived as -500');

SELECT * FROM finish();
ROLLBACK;
