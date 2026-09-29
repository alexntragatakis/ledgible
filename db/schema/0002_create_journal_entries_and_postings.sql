CREATE TABLE journal_entries (
  id                bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id           text        NOT NULL,
  occurred_at       timestamptz NOT NULL,
  recorded_at       timestamptz NOT NULL DEFAULT now(),
  description       text        NOT NULL,
  source_receipt_id bigint,
  idempotency_key   text        NOT NULL UNIQUE,
  reverses_entry_id bigint REFERENCES journal_entries (id),
  CHECK (reverses_entry_id <> id)
);

CREATE UNIQUE INDEX journal_entries_reversed_once
  ON journal_entries (reverses_entry_id)
  WHERE reverses_entry_id IS NOT NULL;

CREATE INDEX journal_entries_user_occurred ON journal_entries (user_id, occurred_at);
CREATE INDEX journal_entries_source_receipt ON journal_entries (source_receipt_id)
  WHERE source_receipt_id IS NOT NULL;

CREATE TABLE postings (
  id               bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  journal_entry_id bigint NOT NULL REFERENCES journal_entries (id),
  account_id       bigint NOT NULL REFERENCES accounts (id),
  amount_cents     bigint NOT NULL CHECK (amount_cents <> 0)
);

CREATE INDEX postings_entry ON postings (journal_entry_id);
CREATE INDEX postings_account ON postings (account_id);
