CREATE TYPE account_type AS ENUM (
  'asset', 'liability', 'income', 'expense', 'envelope', 'equity'
);

CREATE TABLE accounts (
  id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id    text         NOT NULL,
  name       text         NOT NULL,
  type       account_type NOT NULL,
  currency   char(3)      NOT NULL DEFAULT 'USD' CHECK (currency ~ '^[A-Z]{3}$'),
  created_at timestamptz  NOT NULL DEFAULT now(),
  UNIQUE (user_id, name)
);
