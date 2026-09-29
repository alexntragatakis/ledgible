\getenv app_password APP_DB_PASSWORD

SELECT 'CREATE ROLE ledgible_app LOGIN'
 WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'ledgible_app')
\gexec

ALTER ROLE ledgible_app PASSWORD :'app_password';

REVOKE ALL ON ALL TABLES IN SCHEMA public FROM ledgible_app;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC;
GRANT USAGE ON SCHEMA public TO ledgible_app;
GRANT EXECUTE ON FUNCTION assert_entry_balanced(bigint) TO ledgible_app;

GRANT SELECT, INSERT ON accounts TO ledgible_app;

GRANT SELECT, INSERT ON journal_entries, postings TO ledgible_app;
