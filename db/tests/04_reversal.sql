BEGIN;
\ir lib/setup.sql
SELECT plan(6);

SELECT pg_temp.post_entry('t04-prior',
  ARRAY[pg_temp.a('Liabilities:Visa-4417'), pg_temp.a('Expenses:Groceries:Dairy')],
  ARRAY[-1000, 1000]);

SELECT pg_temp.post_entry('t04-kroger',
  ARRAY[pg_temp.a('Liabilities:Visa-4417'),
        pg_temp.a('Expenses:Groceries:Dairy'),
        pg_temp.a('Expenses:Groceries:Produce'),
        pg_temp.a('Expenses:Groceries:Packaged'),
        pg_temp.a('Expenses:Tax')],
  ARRAY[-9136, 389, 1240, 7105, 402]);

SELECT lives_ok(
  $$ SELECT pg_temp.reverse_entry('t04-kroger', 't04-kroger-reversal') $$,
  'exact negation of an entry commits as a reversal'
);

SELECT is(pg_temp.balance(pg_temp.a('Expenses:Groceries:Dairy')), 1000::bigint,
  'dairy balance returns to its prior value');

SELECT is(pg_temp.balance(pg_temp.a('Liabilities:Visa-4417')), -1000::bigint,
  'card balance returns to its prior value');

SELECT is(
  (SELECT count(*) FROM journal_entries
    WHERE idempotency_key IN ('t04-kroger', 't04-kroger-reversal')),
  2::bigint,
  'original and reversal both remain on disk'
);

SELECT lives_ok(
  $$ SELECT pg_temp.post_entry('t04-kroger-corrected',
       ARRAY[pg_temp.a('Liabilities:Visa-4417'),
             pg_temp.a('Expenses:Groceries:Dairy'),
             pg_temp.a('Expenses:Groceries:Produce'),
             pg_temp.a('Expenses:Groceries:Packaged'),
             pg_temp.a('Expenses:Tax')],
       ARRAY[-9136, 489, 1240, 7005, 402]) $$,
  'corrected entry commits after the reversal'
);

SELECT is(pg_temp.balance(pg_temp.a('Expenses:Groceries:Dairy')), 1489::bigint,
  'dairy balance reflects only the corrected amount');

SELECT * FROM finish();
ROLLBACK;
