-- Church-created events were inserted with organizer_type='platform' and a NULL
-- organizer_id, so church leaders failed canManageEvent — they couldn't view
-- registrations, approve requests, or run door check-in for their own events.
-- Link existing church events to their organizing church. (New events set this
-- at insert time.)
UPDATE events
SET organizer_type = 'church', organizer_id = church_id
WHERE church_id IS NOT NULL
  AND (organizer_id IS NULL OR organizer_type = 'platform');
