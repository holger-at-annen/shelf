-- Self-hosted defaults, run on every app start (idempotent).
--
-- Shelf unlocks its paid features when ENABLE_PREMIUM_FEATURES=false, except two per-workspace add-ons:
-- its permission layer reads the raw "barcodesEnabled" / "auditsEnabled" flags, which default to false.
-- This turns both on, so they work like every other feature on a self-hosted instance.

-- 1. Existing workspaces: once only (first run = trigger not created yet), so a later
--    "off" in the admin dashboard is not undone by a restart.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'selfhost_enable_addons') THEN
    UPDATE "Organization"
    SET "barcodesEnabled" = true,
        "barcodesEnabledAt" = COALESCE("barcodesEnabledAt", now()),
        "auditsEnabled" = true,
        "auditsEnabledAt" = COALESCE("auditsEnabledAt", now());
  END IF;
END $$;

-- 2. New workspaces: switched on as they are created.
CREATE OR REPLACE FUNCTION public.selfhost_enable_addons() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  NEW."barcodesEnabled" := true;
  NEW."barcodesEnabledAt" := COALESCE(NEW."barcodesEnabledAt", now());
  NEW."auditsEnabled" := true;
  NEW."auditsEnabledAt" := COALESCE(NEW."auditsEnabledAt", now());
  RETURN NEW;
END $$;

CREATE OR REPLACE TRIGGER selfhost_enable_addons
  BEFORE INSERT ON "Organization"
  FOR EACH ROW EXECUTE FUNCTION public.selfhost_enable_addons();
