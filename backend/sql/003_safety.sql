-- Developed by Codesoftwares
CREATE TABLE blocks (
  blocker UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  blocked UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (blocker, blocked), CHECK (blocker <> blocked)
);
CREATE TABLE reports (
  id BIGSERIAL PRIMARY KEY,
  reporter UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  target UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reason TEXT NOT NULL CHECK (reason IN ('fake_profile','harassment','inappropriate_content','asking_for_money','other')),
  details TEXT CHECK (details IS NULL OR char_length(details) <= 500),
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','dismissed','actioned')),
  resolved_by UUID REFERENCES users(id) ON DELETE SET NULL, resolved_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ON reports (status, id);
CREATE TABLE password_resets (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  code_hash TEXT NOT NULL, expires_at TIMESTAMPTZ NOT NULL,
  attempts INT NOT NULL DEFAULT 0, used BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ON password_resets (user_id, used);
