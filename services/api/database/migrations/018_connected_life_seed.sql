INSERT INTO growth_challenges (title, description, target_days, category)
SELECT '30-Day Prayer Challenge', 'A daily prayer task with streak and completion tracking.', 30, 'Prayer'
WHERE NOT EXISTS (SELECT 1 FROM growth_challenges WHERE title='30-Day Prayer Challenge');

INSERT INTO service_campaigns (title, category, organization, description, location, starts_at, created_by)
SELECT seed.title, seed.category, seed.organization, seed.description, 'Addis Ababa',
  now() + seed.offset_days * interval '1 day', NULL
FROM (VALUES
  ('Campus Evangelism Week', 'Evangelism', 'Mulu Wongel', 'Campus outreach, prayer and follow-up.', 14),
  ('Outreach Team', 'Mission', 'Mulu Wongel Missions', 'Community service and gospel outreach team.', 21)
) AS seed(title, category, organization, description, offset_days)
ON CONFLICT (title) DO NOTHING;

INSERT INTO giving_funds (title, destination_type, destination_name, description) VALUES
  ('Mulu Wongel Mission Fund', 'church', 'Mulu Wongel', 'Supports local and regional mission work.'),
  ('Youth Conference Scholarship', 'ministry', 'Mulu Wongel Youth Ministry', 'Helps youth attend discipleship events.')
ON CONFLICT (title) DO NOTHING;

INSERT INTO events (title, location, starts_at, description, speakers, capacity, checkin_code)
SELECT 'Mulu Wongel Youth Conference', 'Addis Ababa', now() + interval '30 days',
  'Worship, discipleship and Christian fellowship.', ARRAY['Pastor Bereket', 'Rahel Bekele'], 500, 'MWYC-2026'
WHERE NOT EXISTS (SELECT 1 FROM events WHERE title='Mulu Wongel Youth Conference');

CREATE OR REPLACE FUNCTION notify_direct_message() RETURNS trigger AS $$
BEGIN
  INSERT INTO notifications (user_id, actor_id, type, title, body, target_type, target_id)
  SELECT cm.user_id, NEW.author_id, 'direct_message', 'New message',
         u.full_name || ' sent you a message.', 'conversation', NEW.conversation_id
  FROM conversation_members cm
  JOIN users u ON u.id=NEW.author_id
  WHERE cm.conversation_id=NEW.conversation_id AND cm.user_id<>NEW.author_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS direct_message_notification ON direct_messages;
CREATE TRIGGER direct_message_notification AFTER INSERT ON direct_messages
FOR EACH ROW EXECUTE FUNCTION notify_direct_message();
