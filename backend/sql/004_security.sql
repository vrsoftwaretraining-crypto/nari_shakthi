-- Developed by Codesoftwares
-- 1) a 'setup' role: the built-in account that can only create the real admin
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_role_check;
ALTER TABLE users ADD CONSTRAINT users_role_check CHECK (role IN ('member','admin','setup'));

-- 2) three security questions per account (answers stored only as bcrypt hashes)
CREATE TABLE IF NOT EXISTS security_answers (
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  slot INT NOT NULL CHECK (slot BETWEEN 1 AND 3),
  question_id TEXT NOT NULL,
  answer_hash TEXT NOT NULL,
  PRIMARY KEY (user_id, slot)
);
CREATE TABLE IF NOT EXISTS security_attempts (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  failed INT NOT NULL DEFAULT 0,
  locked_until TIMESTAMPTZ
);

-- 3) the setup account (change the password below BEFORE running, or just keep it for local testing)
INSERT INTO users(email, password_hash, role, status)
VALUES ('admin@test.com', crypt('Admin@12345', gen_salt('bf')), 'setup', 'approved')
ON CONFLICT (email) DO UPDATE SET role = 'setup', status = 'approved';
