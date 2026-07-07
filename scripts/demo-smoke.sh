#!/usr/bin/env bash
set -euo pipefail

API_URL="${API_URL:-http://127.0.0.1:3000}"
PHONE="${DEMO_SMOKE_PHONE:-09$(date +%s | tail -c 9)}"
PASSWORD="password123"
TOKEN=""
USER_ID=""

json_get() {
  local expression="$1"
  node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const v=JSON.parse(s);const r=Function("v","return "+process.argv[1])(v);if(r===undefined||r===null)process.exit(2);process.stdout.write(String(r))})' "$expression"
}

request() {
  local method="$1" path="$2" data="${3:-}"
  local args=(-fsS -X "$method" "${API_URL}${path}" -H "Content-Type: application/json")
  [[ -n "$TOKEN" ]] && args+=(-H "Authorization: Bearer $TOKEN")
  [[ -n "$data" ]] && args+=(-d "$data")
  curl "${args[@]}"
}

step() { printf "[demo] %s\n" "$1"; }
first_id() { json_get "v[0].id"; }

assert_json() {
  local expression="$1" message="$2"
  if ! json_get "$expression" >/dev/null; then
    printf "[demo] assertion failed: %s\n" "$message" >&2
    exit 1
  fi
}

step "health and seeded catalog"
request GET /health >/dev/null
request GET /app/bootstrap >/dev/null

step "register a new believer"
request POST /journey/otp/request "{\"phoneNumber\":\"$PHONE\"}" >/dev/null
request POST /journey/otp/verify "{\"phoneNumber\":\"$PHONE\",\"code\":\"123456\"}" >/dev/null
auth="$(request POST /auth/register "{\"fullName\":\"Demo Journey User\",\"phoneNumber\":\"$PHONE\",\"password\":\"$PASSWORD\",\"language\":\"en\"}")"
TOKEN="$(printf "%s" "$auth" | json_get "v.token")"
USER_ID="$(printf "%s" "$auth" | json_get "v.user.id")"
request GET /auth/me >/dev/null

step "complete Samuel onboarding"
church_id="$(request GET /churches | json_get "v.find(x=>x.name==='Mulu Wongel').id")"
ministries="$(request GET /ministries)"
youth_id="$(printf "%s" "$ministries" | json_get "v.find(x=>x.name.includes('Youth')).id")"
media_id="$(printf "%s" "$ministries" | json_get "v.find(x=>x.name.includes('Media')).id")"
request POST /journey/onboarding "{\"photoUrl\":\"https://example.test/samuel.jpg\",\"city\":\"Addis Ababa\",\"occupation\":\"Software Engineer\",\"relationshipStatus\":\"single\",\"interests\":[\"Bible Study\",\"Evangelism\",\"Worship\",\"Courtship\"],\"churchId\":\"$church_id\",\"ministryIds\":[\"$youth_id\",\"$media_id\"]}" >/dev/null

step "verify standard login"
demo_login="$(TOKEN="" request POST /auth/login "{\"phoneNumber\":\"0910000001\",\"password\":\"$PASSWORD\"}")"
printf "%s" "$demo_login" | json_get "v.token" >/dev/null

step "church, group, and event participation"
request POST "/churches/$church_id/join" "{}" >/dev/null
request POST "/churches/$church_id/follow" "{}" >/dev/null
group_id="$(request GET /groups | first_id)"
request POST "/groups/$group_id/join" "{}" >/dev/null
event_id="$(request GET /events | first_id)"
request POST "/events/$event_id/register" "{}" >/dev/null
request POST "/events/$event_id/check-in" "{}" >/dev/null

step "social post, comment, like, share, and report"
post="$(request POST /posts "{\"body\":\"Grace carried me through this demo journey.\",\"language\":\"en\"}")"
post_id="$(printf "%s" "$post" | json_get "v.id")"
request POST "/posts/$post_id/like" "{}" >/dev/null
request POST "/posts/$post_id/comments" "{\"body\":\"Amen.\"}" >/dev/null
request POST "/posts/$post_id/share" "{}" >/dev/null
request POST "/journey/posts/$post_id/save" "{}" >/dev/null
request POST /moderation/reports "{\"targetType\":\"post\",\"targetId\":\"$post_id\",\"reason\":\"Demo moderation workflow\"}" >/dev/null

step "prayer, journal, prayer circle, and spiritual growth"
request POST /prayer/requests "{\"title\":\"Demo prayer\",\"body\":\"Pray for wisdom and service.\",\"anonymous\":false}" >/dev/null
prayer_id="$(request GET /prayer/requests | first_id)"
request POST "/journey/prayers/$prayer_id/prayed" "{}" >/dev/null
journal="$(request POST /prayer/journal "{\"title\":\"Morning prayer\",\"body\":\"Thanksgiving and guidance.\"}")"
journal_id="$(printf "%s" "$journal" | json_get "v.id")"
request PATCH "/prayer/journal/$journal_id/answer" "{\"answer\":\"Peace received.\"}" >/dev/null
chain_id="$(request GET /prayer/chains | first_id)"
request POST "/prayer/chains/$chain_id/join" "{}" >/dev/null
request POST "/prayer/chains/$chain_id/posts" "{\"body\":\"Praying with the community.\"}" >/dev/null
request POST /growth/checkins "{\"kind\":\"prayer\"}" >/dev/null

step "ministry operations"
ministry_id="$(request GET /ministries | first_id)"
request POST "/ministries/$ministry_id/join" "{}" >/dev/null
request POST "/ministries/$ministry_id/follow" "{}" >/dev/null
request POST "/ministries/$ministry_id/tasks" "{\"title\":\"Welcome new volunteers\"}" >/dev/null
request POST "/ministries/$ministry_id/chats" "{\"body\":\"Ready to serve.\"}" >/dev/null
request POST "/ministries/$ministry_id/attendance" "{}" >/dev/null

step "Bible study tools"
verse="For God so loved the world"
request POST /bible/bookmarks "{\"reference\":\"John 3:16\",\"verseText\":\"$verse\",\"language\":\"en\"}" >/dev/null
request POST /bible/highlights "{\"reference\":\"John 3:16\",\"verseText\":\"$verse\",\"color\":\"gold\",\"note\":\"Gospel summary\",\"language\":\"en\"}" >/dev/null
request POST /bible/notes "{\"reference\":\"John 3:16\",\"verseText\":\"$verse\",\"note\":\"Share this truth\",\"language\":\"en\"}" >/dev/null
request GET "/bible/search?q=love" >/dev/null
journey="$(request GET /journey/dashboard)"
plan_id="$(printf "%s" "$journey" | json_get "v.plans.find(x=>x.title.includes('90 Days')).id")"
request POST "/journey/plans/$plan_id/enroll" "{}" >/dev/null
request POST "/journey/plans/$plan_id/checkin" "{}" >/dev/null

step "mentorship, testimony, opportunity, talent, and giving"
mentor_id="$(request GET /mentors | first_id)"
request POST "/mentors/$mentor_id/follow" "{}" >/dev/null
request POST /mentorship/requests "{\"mentorId\":\"$mentor_id\",\"note\":\"Please guide my discipleship growth.\"}" >/dev/null
request POST /stories "{\"title\":\"Demo testimony\",\"body\":\"God has been faithful.\",\"language\":\"en\"}" >/dev/null
story_id="$(request GET /stories | first_id)"
request POST "/journey/stories/$story_id/replies" "{\"body\":\"Thank you for sharing this testimony.\"}" >/dev/null
opportunity_id="$(request GET /opportunities | first_id)"
request POST "/opportunities/$opportunity_id/apply" "{\"note\":\"I am available to serve.\"}" >/dev/null
request PUT /talent/me "{\"displayName\":\"Demo Creative\",\"category\":\"music\",\"churchName\":\"Grace Fellowship\",\"city\":\"Addis Ababa\",\"bio\":\"Worship musician\",\"contactInfo\":\"$PHONE\"}" >/dev/null
competition_id="$(request GET /talent/competitions | first_id)"
request POST "/talent/competitions/$competition_id/enter" "{}" >/dev/null
plan_id="$(request GET /payments/plans | first_id)"
request POST /payments/history "{\"planId\":\"$plan_id\"}" >/dev/null

step "friendship, learning, certificate, badge, and marketplace"
friend_id="$(request GET /users | json_get "v.find(x=>x.id!== '$USER_ID').id")"
request POST "/journey/friends/$friend_id/request" "{}" >/dev/null
journey="$(request GET /journey/dashboard)"
course_id="$(printf "%s" "$journey" | json_get "v.courses[0].id")"
request POST "/journey/courses/$course_id/enroll" "{}" >/dev/null
for _ in $(seq 1 8); do request POST "/journey/courses/$course_id/progress" "{}" >/dev/null; done
seller_listing_title="Demo marketplace guitar ${USER_ID:0:8} $$"
request POST /journey/marketplace "{\"title\":\"$seller_listing_title\",\"category\":\"Worship Resources\",\"description\":\"Clean worship guitar with strap, cable, and full pickup details for local believers.\",\"priceCents\":7500000,\"condition\":\"used_good\",\"location\":\"Addis Ababa\",\"phoneNumber\":\"$PHONE\",\"imageUrl\":\"https://example.test/guitar.jpg\"}" >/dev/null
marketplace="$(request GET /journey/marketplace)"
printf "%s" "$marketplace" | assert_json "v.some(x=>x.title==='$seller_listing_title') ? true : null" "seller marketplace listing was not published"
listing_id="$(printf "%s" "$marketplace" | json_get "v.find(x=>x.title==='$seller_listing_title').id")"
request POST "/journey/marketplace/$listing_id/order" "{}" >/dev/null

step "safe courtship profile, chat, search, and notifications"
request PUT /courtship/me "{\"churchName\":\"Grace Fellowship\",\"city\":\"Addis Ababa\",\"bio\":\"Faith-centered friendship first.\",\"interests\":\"Bible study, service\",\"faithStatement\":\"Jesus Christ is Lord and Scripture guides my life.\",\"ministryInvolvement\":\"Youth and Media Ministry\",\"lifeGoals\":\"Serve the church, grow professionally, and build a faithful home.\",\"marriageVision\":\"A prayerful marriage centered on Christ, service, and family.\",\"relationshipIntent\":\"serious\",\"visible\":true}" >/dev/null
receiver_id="$(request GET /courtship/profiles | json_get "v.find(x=>x.userId!== '$USER_ID')?.userId")"
request POST /courtship/interests "{\"receiverId\":\"$receiver_id\",\"note\":\"Open to a guided introduction.\"}" >/dev/null
request POST "/chat/messages?room=general" "{\"body\":\"Hello from the complete demo journey.\"}" >/dev/null
request GET "/search?q=grace" >/dev/null
request GET /notifications >/dev/null
request PATCH /notifications/read-all "{}" >/dev/null

step "connected-life groups, messaging, challenges, service, media, giving, and teen safety"
connected="$(request GET /connected-life/dashboard)"
request POST "/connected-life/groups/$group_id/posts" '{"body":"Romans study discussion from the Samuel journey."}' >/dev/null
request POST "/connected-life/groups/$group_id/resources" '{"title":"Romans study notes","resourceUrl":"https://example.test/romans-notes","resourceType":"link"}' >/dev/null
challenge_id="$(printf "%s" "$connected" | json_get "v.challenges.find(x=>x.title.includes('30-Day Prayer')).id")"
request POST "/connected-life/challenges/$challenge_id/enroll" "{}" >/dev/null
request POST "/connected-life/challenges/$challenge_id/checkin" "{}" >/dev/null
campaign_id="$(printf "%s" "$connected" | json_get "v.campaigns[0].id")"
request POST "/connected-life/campaigns/$campaign_id/join" "{}" >/dev/null
conversation="$(request POST /connected-life/conversations "{\"otherUserId\":\"$friend_id\",\"kind\":\"direct\"}")"
conversation_id="$(printf "%s" "$conversation" | json_get "v.id")"
request POST "/connected-life/conversations/$conversation_id/messages" '{"body":"Peace to you.","attachmentUrl":"https://example.test/schedule.pdf","attachmentType":"file"}' >/dev/null
request POST /connected-life/media '{"title":"Worship guitar recording","category":"Worship","description":"Samuel serves through music.","mediaUrl":"https://example.test/worship.mp3","mediaType":"audio"}' >/dev/null
fund_id="$(printf "%s" "$connected" | json_get "v.funds[0].id")"
request POST "/connected-life/funds/$fund_id/donate" '{"amount":125}' >/dev/null
request PUT /connected-life/teen-profile '{"isTeen":false,"guardianName":"","guardianApproved":false}' >/dev/null
step "verify persisted Samuel state"
journey="$(request GET /journey/dashboard)"
printf "%s" "$journey" | assert_json "v.profile.onboarding_complete===true && v.profile.city==='Addis Ababa' ? true : null" "onboarding profile was not persisted"
printf "%s" "$journey" | assert_json "v.savedPostIds.includes('$post_id') ? true : null" "saved post was not persisted"
printf "%s" "$journey" | assert_json "v.plans.some(x=>x.id==='$plan_id' || Number(x.completed_days)>=1) ? true : null" "reading-plan progress was not persisted"
printf "%s" "$journey" | assert_json "v.courses.some(x=>x.certificate_code) ? true : null" "course certificate was not awarded"
printf "%s" "$journey" | assert_json "v.badges.length>0 ? true : null" "completion badge was not awarded"
printf "%s" "$journey" | assert_json "v.orders.some(x=>x.receipt_number) ? true : null" "marketplace receipt was not persisted"
memberships="$(request GET /ministries/me/memberships)"
printf "%s" "$memberships" | assert_json "v.length>=2 ? true : null" "Youth and Media ministry memberships were not both persisted"
search_results="$(request GET "/search?q=Romans")"
printf "%s" "$search_results" | assert_json "v.some(x=>['group','bible','bible_note','resource','post'].includes(x.kind)) ? true : null" "Romans search returned no relevant ecosystem result"
connected="$(request GET /connected-life/dashboard)"
printf "%s" "$connected" | assert_json "v.challenges.some(x=>x.id==='$challenge_id' && Number(x.completedDays)>=1) ? true : null" "challenge progress was not persisted"
printf "%s" "$connected" | assert_json "v.campaigns.some(x=>x.id==='$campaign_id' && x.joined===true) ? true : null" "campaign membership was not persisted"
printf "%s" "$connected" | assert_json "v.conversations.some(x=>x.id==='$conversation_id') ? true : null" "direct conversation was not persisted"
printf "%s" "$connected" | assert_json "v.media.some(x=>x.title==='Worship guitar recording') ? true : null" "media submission was not persisted"
printf "%s" "$connected" | assert_json "v.donations.some(x=>x.receiptNumber) ? true : null" "donation receipt was not persisted"
group_activity="$(request GET "/connected-life/groups/$group_id/activity")"
printf "%s" "$group_activity" | assert_json "v.posts.some(x=>x.body.includes('Romans study')) && v.resources.some(x=>x.title==='Romans study notes') ? true : null" "group activity was not persisted"
messages="$(request GET "/connected-life/conversations/$conversation_id/messages")"
printf "%s" "$messages" | assert_json "v.some(x=>x.body==='Peace to you.' && x.attachmentType==='file') ? true : null" "direct message attachment metadata was not persisted"

printf "Demo journey passed for %s.\n" "$PHONE"
