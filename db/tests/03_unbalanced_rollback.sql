BEGIN;
\ir lib/setup.sql
SELECT plan(4);

SELECT throws_like(
  $$ SELECT pg_temp.post_entry('t03-off-by-one',
       ARRAY[pg_temp.a('Liabilities:Visa-4417'), pg_temp.a('Expenses:Groceries:Dairy')],
       ARRAY[-9136, 9135]) $$,
  '%is unbalanced: postings sum to -1 cents%',
  'entry off by one cent is rejected'
);

SELECT is(pg_temp.entry('t03-off-by-one'), NULL,
  'rejected entry left no journal row behind');

SELECT lives_ok(
  $$ SELECT pg_temp.insert_entry('t03-deferred',
       ARRAY[pg_temp.a('Liabilities:Visa-4417'), pg_temp.a('Expenses:Groceries:Dairy')],
       ARRAY[-100, 50]) $$,
  'unbalanced rows are accepted at INSERT time'
);

-- Keep last: the rows above stay queued for the commit-time check.
SELECT throws_like(
  $$ SELECT pg_temp.check_now() $$,
  '%is unbalanced: postings sum to -50 cents%',
  'unbalanced entry is rejected at COMMIT, not at INSERT'
);

SELECT * FROM finish();
ROLLBACK;
