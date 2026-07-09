-- Super-likes: a stronger, visible expression of interest on the swipe deck.
ALTER TABLE courtship_interests
  ADD COLUMN IF NOT EXISTS super boolean NOT NULL DEFAULT false;
