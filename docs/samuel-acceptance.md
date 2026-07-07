# Samuel Journey Acceptance Audit

Audit date: 2026-06-13. `Working` means persisted API behavior plus a usable mobile path. `Partial` means only part of the described experience exists. `Missing` means the scenario has no meaningful end-to-end implementation.

| Scenario | Status | Current evidence and gap |
| --- | --- | --- |
| Phone registration and OTP | Partial | Registration works; production/staging use crypto-random codes delivered via AfroMessage SMS (`SMS_PROVIDER=afromessage`), dev keeps demo OTP `123456`. Verify attempt limits and canonical phone-number identity remain. See [SMS/OTP](sms-otp.md). |
| Profile photo, city, occupation, status and interests | Partial | Journey onboarding persists a photo URL and profile fields. There is no binary image upload, crop, storage, or CDN. |
| Select Mulu Wongel and join Youth/Media | Working | Onboarding creates a pending church membership and ministry memberships. Mulu Wongel, Youth and Media are seeded. |
| Personalized home feed | Missing | Feed returns all posts. It is not ranked or scoped by church, ministry, friends, pastors, influencers, or follows. |
| Like, comment and share posts | Working | Persisted API and mobile feed actions exist. |
| Save posts | Partial | Persisted toggle endpoint exists and is tested, but the feed has no save button or saved-posts screen. |
| Stories and story replies | Partial | Story list/create UI exists. Reply persistence exists, but no reply action or reply inbox is exposed in mobile. |
| Following affects feed | Missing | User/church/ministry/mentor follows exist, but feed selection ignores follows. Worship-leader identity is not modeled. |
| Romans 8 Bible reading | Missing | Search, daily verses, notes, bookmarks and highlights exist; there is no complete chapter reader or licensed Bible corpus. |
| Bible notes, bookmarks and highlights | Working | Persisted API and mobile actions exist. |
| 90-day New Testament plan | Working | Enrollment, daily check-in, progress, streak and completion persistence are available in My Christian Journey. |
| Scoped prayer request and “I prayed” | Partial | Prayer creation works. “I prayed” persists through API only. Friends/prayer-group/youth-ministry audience selection is absent. |
| Prayer journal and answered prayer | Working | Journal creation and answered status/update are persisted and available in mobile. |
| Church service notification | Missing | Announcements exist, but no scheduled service reminder or announcement-to-notification pipeline exists. |
| Church page | Partial | Branches, schedules, announcements, sermons and members exist. Dedicated pastors, church ministries and church-specific events are incomplete. |
| Volunteer call and volunteer status | Partial | Opportunities and ministry joining exist. A volunteer assignment lifecycle, approval, hours and records are absent. |
| Assigned media task on dashboard | Partial | Ministry tasks support an assignee, but there is no authenticated “my assigned tasks” dashboard or leader permission enforcement. |
| Ministry chat, files and schedules | Partial | Text ministry chat and resource links exist. File upload, schedules, receipts, search and realtime chat are absent. |
| Four named groups | Partial | Named groups are seeded and joining works. The smoke test does not yet join all four from mobile. |
| Group posts, files, polls and events | Missing | Group detail currently focuses on membership. Group-owned content workflows are not implemented. |
| Direct messaging with media | Missing | Only text messages in named rooms exist. No direct conversations, voice notes, images, files, receipts or realtime transport. |
| Nearby youth and friend requests | Partial | Friend requests persist through API. Nearby discovery, recommendations, acceptance UI and fellowship-partner matching are absent. |
| Courtship profile | Partial | Church, city, bio, interests, intent and visibility persist. Faith statement, ministry, life goals and marriage vision are not structured fields. |
| Verified compatibility discovery | Missing | Visible profiles are listed, but there is no compatibility engine, shared-interest ranking, age/location filters or enforced verification. |
| Sara accepts and private chat opens | Missing | Interest request status can be updated, but no accepted-match conversation is created. |
| Report, block and moderation | Partial | Report and block persistence exists; admin moderation exists. Enforcement across feed/chat/discovery and audit history are incomplete. |
| Event registration and attendance | Working | Registration and check-in persist. |
| QR event check-in and speakers | Missing | No QR generation/scanning. Event schema does not model speakers or detailed agenda. |
| 30-day prayer challenge | Partial | Growth challenges and generic check-ins exist. Enrollment, daily task schedule and challenge-specific completion are incomplete. |
| Prayer Warrior badge | Missing | Generic growth badges exist, but the exact challenge completion rule and profile award are not implemented. |
| Worship recording upload and engagement | Missing | Media catalog entries exist, but user upload and media-specific likes/comments/shares do not. |
| Christian software project talent upload | Partial | Talent profile persists, but no portfolio/project upload, files, media, reactions or discovery ranking. |
| Evangelism campaign and mission team | Partial | Opportunities and ministry membership can approximate these. Campaign tasks, teams, participation and reports are not modeled end to end. |
| Discipleship course and certificate | Partial | Enrollment, lesson counters, completion certificate and badge work. Videos, PDFs, quizzes and assessment results are absent. |
| Mentor search and request | Partial | Mentor list/follow/request work. Professional matching, sessions, goals and progress tracking are absent. |
| Teen account safety | Missing | Teen Zone is static guidance. No age gate, guardian controls, restricted messaging or teen moderation policy enforcement. |
| Donation, receipt and history | Partial | Giving records persist. No payment provider, mission-fund destination, signed receipt, webhook or reconciliation. |
| Marketplace purchase | Partial | Listings, orders and receipt numbers persist. No real payment, inventory, fulfillment, refunds or order-detail UI. |
| Global Romans search | Partial | Search covers verses, sermons, groups, posts, private notes, events and more. Ranking, filters, pagination and guaranteed Romans content across every type are incomplete. |
| Notifications | Partial | Likes, comments and follows can notify. Messages, event reminders, ministry assignments, prayer updates, push delivery and preferences are absent. |
| Church admin | Missing | Current admin is mainly moderation/summary. Member approval, ministry leadership, event operations and broadcasts are not complete. |
| Pastor experience | Missing | No pastor role/RBAC workflow for publishing, Q&A, mentorship management or livestreaming. |
| Youth leader experience | Missing | No leader role/RBAC workflow for events, challenges, participation reports and targeted communication. |

## Automated Coverage

`npm run demo:smoke` validates the implemented core with a fresh user and now asserts persisted onboarding, two ministry memberships, saved post, reading progress, course certificate, badge, marketplace receipt and Romans search results.

It does not prove missing production integrations such as SMS, object storage, push notifications, payment processing, realtime messaging, QR scanning or licensed Bible content.
