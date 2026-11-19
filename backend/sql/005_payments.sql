-- Developed by Codesoftwares
-- Admin-managed payment details (one row) and Razorpay support on payments
CREATE TABLE IF NOT EXISTS payment_settings (
  id INT PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  upi_id TEXT, payee_name TEXT,
  amount_rupees INT CHECK (amount_rupees IS NULL OR amount_rupees BETWEEN 1 AND 100000),
  qr_key TEXT, updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
INSERT INTO payment_settings(id) VALUES (1) ON CONFLICT DO NOTHING;

ALTER TABLE payments ALTER COLUMN screenshot_key DROP NOT NULL;
ALTER TABLE payments ADD COLUMN IF NOT EXISTS method TEXT NOT NULL DEFAULT 'upi_screenshot' CHECK (method IN ('upi_screenshot','razorpay'));
ALTER TABLE payments ADD COLUMN IF NOT EXISTS amount_paise INT;
ALTER TABLE payments ADD COLUMN IF NOT EXISTS rzp_order_id TEXT UNIQUE;
ALTER TABLE payments ADD COLUMN IF NOT EXISTS rzp_payment_id TEXT UNIQUE;
ALTER TABLE payments DROP CONSTRAINT IF EXISTS payments_status_check;
ALTER TABLE payments ADD CONSTRAINT payments_status_check CHECK (status IN ('created','pending','verified','rejected'));
