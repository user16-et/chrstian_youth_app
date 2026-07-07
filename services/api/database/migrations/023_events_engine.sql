ALTER TABLE events
  ADD COLUMN IF NOT EXISTS organizer_type text NOT NULL DEFAULT 'platform',
  ADD COLUMN IF NOT EXISTS organizer_id uuid,
  ADD COLUMN IF NOT EXISTS category text NOT NULL DEFAULT 'fellowship',
  ADD COLUMN IF NOT EXISTS event_type text NOT NULL DEFAULT 'open',
  ADD COLUMN IF NOT EXISTS ends_at timestamptz,
  ADD COLUMN IF NOT EXISTS visibility text NOT NULL DEFAULT 'public',
  ADD COLUMN IF NOT EXISTS registration_type text NOT NULL DEFAULT 'open',
  ADD COLUMN IF NOT EXISTS registration_deadline timestamptz,
  ADD COLUMN IF NOT EXISTS contact_person text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS contact_phone text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS ticket_type text NOT NULL DEFAULT 'free',
  ADD COLUMN IF NOT EXISTS ticket_price numeric(12,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS livestream_url text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'published',
  ADD COLUMN IF NOT EXISTS latitude numeric(10,7),
  ADD COLUMN IF NOT EXISTS longitude numeric(10,7),
  ADD COLUMN IF NOT EXISTS saved_count int NOT NULL DEFAULT 0;

ALTER TABLE event_registrations
  ADD COLUMN IF NOT EXISTS id uuid DEFAULT gen_random_uuid(),
  ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'registered',
  ADD COLUMN IF NOT EXISTS ticket_code text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS qr_payload text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS approved_by uuid REFERENCES users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS approved_at timestamptz,
  ADD COLUMN IF NOT EXISTS cancelled_at timestamptz;
UPDATE event_registrations SET id=gen_random_uuid() WHERE id IS NULL;
UPDATE event_registrations SET ticket_code='TKT-' || substr(md5(event_id::text || user_id::text),1,10) WHERE ticket_code='';
UPDATE event_registrations SET qr_payload='event:' || event_id::text || ':user:' || user_id::text || ':ticket:' || ticket_code WHERE qr_payload='';
CREATE UNIQUE INDEX IF NOT EXISTS event_registrations_id_idx ON event_registrations(id);
CREATE UNIQUE INDEX IF NOT EXISTS event_registrations_ticket_idx ON event_registrations(ticket_code);

CREATE TABLE IF NOT EXISTS event_volunteers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role text NOT NULL DEFAULT 'volunteer',
  status text NOT NULL DEFAULT 'applied',
  note text NOT NULL DEFAULT '',
  approved_by uuid REFERENCES users(id) ON DELETE SET NULL,
  approved_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(event_id,user_id,role)
);

CREATE TABLE IF NOT EXISTS event_teams (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  name text NOT NULL,
  leader_id uuid REFERENCES users(id) ON DELETE SET NULL,
  description text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS event_team_members (
  team_id uuid NOT NULL REFERENCES event_teams(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role text NOT NULL DEFAULT 'member',
  joined_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY(team_id,user_id)
);

CREATE TABLE IF NOT EXISTS event_tasks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  team_id uuid REFERENCES event_teams(id) ON DELETE SET NULL,
  assigned_to uuid REFERENCES users(id) ON DELETE SET NULL,
  created_by uuid REFERENCES users(id) ON DELETE SET NULL,
  title text NOT NULL,
  description text NOT NULL DEFAULT '',
  due_at timestamptz,
  priority text NOT NULL DEFAULT 'normal',
  status text NOT NULL DEFAULT 'pending',
  created_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz
);

CREATE TABLE IF NOT EXISTS event_speakers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  name text NOT NULL,
  title text NOT NULL DEFAULT '',
  bio text NOT NULL DEFAULT '',
  church text NOT NULL DEFAULT '',
  photo_url text NOT NULL DEFAULT '',
  social_links jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS event_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  speaker_id uuid REFERENCES event_speakers(id) ON DELETE SET NULL,
  title text NOT NULL,
  description text NOT NULL DEFAULT '',
  starts_at timestamptz NOT NULL,
  ends_at timestamptz,
  location text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS event_resources (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  title text NOT NULL,
  description text NOT NULL DEFAULT '',
  resource_url text NOT NULL,
  resource_type text NOT NULL DEFAULT 'link',
  visibility text NOT NULL DEFAULT 'registered',
  uploaded_by uuid REFERENCES users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS event_media (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  uploaded_by uuid REFERENCES users(id) ON DELETE SET NULL,
  title text NOT NULL,
  media_url text NOT NULL,
  media_type text NOT NULL DEFAULT 'image',
  like_count int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS event_discussions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  author_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title text NOT NULL,
  body text NOT NULL DEFAULT '',
  status text NOT NULL DEFAULT 'open',
  reply_count int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS event_discussion_replies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  discussion_id uuid NOT NULL REFERENCES event_discussions(id) ON DELETE CASCADE,
  author_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  body text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS event_feedback (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  rating int NOT NULL CHECK(rating BETWEEN 1 AND 5),
  body text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(event_id,user_id)
);

CREATE TABLE IF NOT EXISTS saved_events (
  event_id uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY(event_id,user_id)
);

CREATE TABLE IF NOT EXISTS event_notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  title text NOT NULL,
  body text NOT NULL DEFAULT '',
  channel text NOT NULL DEFAULT 'in_app',
  send_at timestamptz NOT NULL DEFAULT now(),
  sent_at timestamptz,
  created_by uuid REFERENCES users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

WITH first_user AS (SELECT id FROM users ORDER BY created_at LIMIT 1),
first_church AS (SELECT id FROM churches ORDER BY created_at LIMIT 1),
first_ministry AS (SELECT id FROM ministries ORDER BY created_at LIMIT 1)
INSERT INTO events(title,location,starts_at,ends_at,description,speakers,capacity,checkin_code,organizer_type,organizer_id,category,event_type,registration_required,registration_type,contact_person,ticket_type,status)
SELECT seed.title,seed.location,seed.starts_at,seed.ends_at,seed.description,seed.speakers,seed.capacity,seed.checkin_code,seed.organizer_type,seed.organizer_id,seed.category,seed.event_type,true,seed.registration_type,seed.contact_person,seed.ticket_type,'published'
FROM (
  SELECT 'Youth Conference 2027'::text title,'Megenagna, Addis Ababa'::text location,now()+interval '45 days' starts_at,now()+interval '45 days 8 hours' ends_at,'A church and ministry conference with worship, teaching, networking, volunteers, sessions, resources and QR attendance.'::text description,ARRAY['Pastor Samuel','Sara Worship Team']::text[] speakers,1200 capacity,'YC2027'::text checkin_code,'ministry'::text organizer_type,(SELECT id FROM first_ministry) organizer_id,'conference'::text category,'youth_conference'::text event_type,'open'::text registration_type,'Youth Ministry Office'::text contact_person,'free'::text ticket_type
  UNION ALL SELECT 'Christian Developers Meetup','Kazanchis, Addis Ababa',now()+interval '18 days',now()+interval '18 days 3 hours','Community technology meetup for believers building useful products for churches and ministries.',ARRAY['Christian Software Architect'],180,'DEVMEET','community',(SELECT id FROM first_user),'training','meetup','open','Community Team','free'
  UNION ALL SELECT 'Sunday Revival Program','Mulu Wongel Main Hall',now()+interval '5 days',now()+interval '5 days 4 hours','Church-wide worship, prayer and teaching service with attendance tracking.',ARRAY['Senior Pastor'],900,'REVIVAL','church',(SELECT id FROM first_church),'prayer','revival','open','Church Admin','free'
) seed
WHERE NOT EXISTS (SELECT 1 FROM events e WHERE e.title=seed.title);

WITH e AS (SELECT id FROM events WHERE title='Youth Conference 2027' LIMIT 1), u AS (SELECT id FROM users ORDER BY created_at LIMIT 1)
INSERT INTO event_teams(event_id,name,leader_id,description)
SELECT e.id,team.name,u.id,team.description FROM e,u,(VALUES
  ('Registration Team','Handles QR tickets, entrance and attendee support.'),
  ('Media Team','Photography, livestream and post-event gallery.'),
  ('Worship Team','Worship sessions and rehearsal coordination.'),
  ('Logistics Team','Venue, seating, transport and supplies.')
) AS team(name,description)
WHERE NOT EXISTS (SELECT 1 FROM event_teams et WHERE et.event_id=e.id AND et.name=team.name);

WITH e AS (SELECT id FROM events WHERE title='Youth Conference 2027' LIMIT 1), u AS (SELECT id FROM users ORDER BY created_at LIMIT 1)
INSERT INTO event_tasks(event_id,assigned_to,created_by,title,description,due_at,priority,status)
SELECT e.id,u.id,u.id,task.title,task.description,now()+task.task_offset,task.priority,'pending'
FROM e,u,(VALUES
  ('Prepare QR registration desk','Print attendee list and test QR scanner.',interval '30 days','high'),
  ('Sound and livestream setup','Prepare sound board, cameras and stream link.',interval '40 days','high'),
  ('Upload conference notes','Publish PDFs and session handouts.',interval '46 days','normal')
) AS task(title,description,task_offset,priority)
WHERE NOT EXISTS (SELECT 1 FROM event_tasks t WHERE t.event_id=e.id AND t.title=task.title);

WITH e AS (SELECT id,starts_at FROM events WHERE title='Youth Conference 2027' LIMIT 1)
INSERT INTO event_speakers(event_id,name,title,bio,church)
SELECT e.id,s.name,s.title,s.bio,s.church FROM e,(VALUES
  ('Pastor Samuel','Youth Pastor','Teaches discipleship, calling and faithful service.','Mulu Wongel'),
  ('Sara Worship Team','Worship Leader','Leads worship and mentors young worship servants.','Addis Worship Fellowship')
) AS s(name,title,bio,church)
WHERE NOT EXISTS (SELECT 1 FROM event_speakers sp WHERE sp.event_id=e.id AND sp.name=s.name);

WITH e AS (SELECT id,starts_at FROM events WHERE title='Youth Conference 2027' LIMIT 1), sp AS (SELECT id FROM event_speakers WHERE name='Pastor Samuel' LIMIT 1)
INSERT INTO event_sessions(event_id,speaker_id,title,description,starts_at,ends_at,location)
SELECT e.id,sp.id,session.title,session.description,e.starts_at+session.start_offset,e.starts_at+session.end_offset,'Main Hall'
FROM e,sp,(VALUES
  ('Opening Worship','Corporate worship and prayer.',interval '0 minutes',interval '60 minutes'),
  ('Teaching: Called to Serve','Main teaching session.',interval '75 minutes',interval '150 minutes'),
  ('Workshop: Ministry and Career','Practical discussion for young professionals.',interval '180 minutes',interval '250 minutes')
) AS session(title,description,start_offset,end_offset)
WHERE NOT EXISTS (SELECT 1 FROM event_sessions es WHERE es.event_id=e.id AND es.title=session.title);

WITH e AS (SELECT id FROM events WHERE title='Youth Conference 2027' LIMIT 1), u AS (SELECT id FROM users ORDER BY created_at LIMIT 1)
INSERT INTO event_resources(event_id,title,description,resource_url,resource_type,uploaded_by)
SELECT e.id,'Conference Notes','PDF notes for teaching and workshops.','https://example.com/youth-conference-notes.pdf','pdf',u.id FROM e,u
WHERE NOT EXISTS (SELECT 1 FROM event_resources r WHERE r.event_id=e.id AND r.title='Conference Notes');

WITH e AS (SELECT id FROM events WHERE title='Youth Conference 2027' LIMIT 1), u AS (SELECT id FROM users ORDER BY created_at LIMIT 1)
INSERT INTO event_discussions(event_id,author_id,title,body)
SELECT e.id,u.id,'Transportation and arrival','Share transport plans and arrival questions here.' FROM e,u
WHERE NOT EXISTS (SELECT 1 FROM event_discussions d WHERE d.event_id=e.id AND d.title='Transportation and arrival');

CREATE INDEX IF NOT EXISTS events_starts_idx ON events(starts_at);
CREATE INDEX IF NOT EXISTS events_category_idx ON events(category);
CREATE INDEX IF NOT EXISTS event_tasks_event_idx ON event_tasks(event_id,status);
CREATE INDEX IF NOT EXISTS event_sessions_event_idx ON event_sessions(event_id,starts_at);
CREATE INDEX IF NOT EXISTS event_discussions_event_idx ON event_discussions(event_id,created_at DESC);
