-- Developed by Codesoftwares
-- Reason shown to a member when an admin suspends or rejects the profile
ALTER TABLE users ADD COLUMN IF NOT EXISTS status_reason TEXT;
