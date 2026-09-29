BEGIN;
\ir lib/setup.sql
SELECT plan(3);

SELECT lives_ok(
  $$ SELECT pg_temp.post_entry('t02-kroger',
       ARRAY[pg_temp.a('Liabilities:Visa-4417'),
             pg_temp.a('Expenses:Groceries:Dairy'),
             pg_temp.a('Expenses:Groceries:Produce'),
             pg_temp.a('Expenses:Groceries:Packaged'),
             pg_temp.a('Expenses:Tax')],
       ARRAY[-9136, 389, 1240, 7105, 402]) $$,
  'balanced 5-posting receipt entry commits'
);

SELECT is(
  (SELECT count(*) FROM postings WHERE journal_entry_id = pg_temp.entry('t02-kroger')),
  5::bigint,
  'receipt entry has one posting per category plus the card'
);

SELECT results_eq(
  $$ SELECT a.name, sum(p.amount_cents)::bigint
       FROM postings p JOIN accounts a ON a.id = p.account_id
      WHERE p.journal_entry_id = pg_temp.entry('t02-kroger')
      GROUP BY a.name ORDER BY a.name $$,
  $$ VALUES ('Expenses:Groceries:Dairy',    389::bigint),
            ('Expenses:Groceries:Packaged', 7105::bigint),
            ('Expenses:Groceries:Produce',  1240::bigint),
            ('Expenses:Tax',                402::bigint),
            ('Liabilities:Visa-4417',       -9136::bigint) $$,
  'per-category amounts are recorded exactly'
);

SELECT * FROM finish();
ROLLBACK;
