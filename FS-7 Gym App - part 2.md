# FS-7 Gym App – Product & Build Specification



## 18. Architecture: the layers and what each one handles

**Part 2 of this document (sections 18 to 26) explains how everything connects.** Sections 1 to 17 say *what* the app does; this part says *which component does it, in what order, and what it changes*. If any earlier section and this part seem to differ, this part wins for implementation.

**The golden rule:** business rules live on the server (database functions and scheduled jobs), never only in the app screens. The app collects input, calls one server function, and shows the result. This is the single most common reason builder AIs produce a broken app: they scatter rules across screens, and the rules disagree.

| Layer | Technology | Handles | Must never |
| --- | --- | --- | --- |
| 1. Screens (UI) | Flutter or React Native | Forms, lists, grids, charts, showing live calculated values while typing, navigation | Decide slot validity, change statuses, compute session counts, or enforce permissions |
| 2. App state and repositories | One repository class per module (Clients, Timetable, Attendance, Assessments, Inquiries, Staff, Reports) | Calls server functions, caches today's data for offline use, queues offline writes, exposes data to screens | Write directly to tables for anything that has a server function (section 20) |
| 3. Calculation module (shared) | One pure code file used by the assessment form and by the server | BMI, body fat, VO2max, scores (section 9) with unit conversion | Be duplicated; a second copy will drift. The server recalculates on save and its result is the one stored |
| 4. Auth | Supabase Auth with User ID mapped to an internal email such as `userid@fs7.local` | Login, password reset by admin, session, role claim in the token | Allow self sign-up |
| 5. Database | PostgreSQL | Tables from section 16, constraints, row-level security (section 24), server functions (section 20) | Hard delete anything |
| 6. Scheduled jobs | Supabase cron or Edge Functions | Nightly status job, daily reminder generation, weekly summary (section 21) | Run twice with different results; every job must be safe to re-run |
| 7. File storage | Private bucket with folders `consents`, `reports`, `photos`, `diet` | BCA, blood, consent PDF, photos, generated report PDFs | Use public URLs; always signed, expiring links |
| 8. Push notifications | Firebase Cloud Messaging, plus local scheduled notifications on the phone | Delivering messages created by the notifications table | Decide who gets what; that decision is made by the server when it creates the row |
| 9. Report generator | Edge Function or in-app PDF library | Building the Transformation Report PDF from stored assessment snapshots | Recalculate values; it only reads stored snapshots |

**How a normal action travels:**

1. User taps a button on a screen.
2. The screen calls its repository method.
3. The repository calls one server function (RPC) with a clear set of inputs.
4. The function checks the user's role, validates the rules, writes all affected tables in one transaction, writes the audit log, and creates any notification rows.
5. The function returns the new state or a clear error code.
6. The repository updates its cache; screens subscribed to that data refresh automatically (realtime).
7. If the phone is offline in step 3, the repository queues the call and replays it when online, in order.

If the function returns an error code, the screen shows the matching message from the error table in section 20. The screen never guesses.

## 19. Dependency map: what changes when something changes

Every module is linked to the others through a small number of shared facts. Build and test these links explicitly.

### 19.1 Where each fact lives (single source of truth)

| Fact | Stored only in | Derived values (never stored separately) |
| --- | --- | --- |
| Who a client is | clients | Age (from dob), full name |
| Which plan they are on and its dates | subscriptions (one active row per client at most) | Total sessions, days left, extension window |
| When they train | slots (linked to the subscription, not to the client) | Timetable grid, today's session list, free seats |
| Sessions used | attendance rows with status present or makeup | Sessions remaining = total sessions minus count of those rows |
| Client state | subscriptions.status, copied to clients.status by the server only | Status chips, Past Clients list, filters |
| Test results | assessments (inputs plus calculated\_json snapshot) | Reports, trends, FS-7 score history |
| Trainer or nutritionist of a client | clients.trainer\_id, clients.nutritionist\_id | What each staff member can see (security rules read these two columns) |
| Lead status | inquiries and inquiry\_followups | Today's calls list, analytics |

**Two rules that prevent most bugs:** (1) a slot belongs to a **subscription**, so ending the subscription frees the seat with no extra code; (2) a trainer's visibility comes only from `clients.trainer_id`, so reassigning a client instantly moves visibility with no extra code.

### 19.2 Event ripple table

When an event happens, the server function performs every change in its row, in one transaction.

| Event | Tables written | Other effects | Notifications created | Screens that refresh |
| --- | --- | --- | --- | --- |
| Admin creates client | clients, subscriptions, slots, consents, audit\_log, optionally documents | Timetable block appears; baseline assessment due date set (start + 7 days) | Trainer: new client assigned | Timetable, trainer's Today and My Clients, All Clients, dashboard |
| Trainer marks Present | attendance | Sessions remaining drops by 1; if remaining reaches 0 the subscription becomes Completed and the slot frees; if remaining is 3 or less the final assessment becomes due | Trainer: final assessment due (once); admin: plan completed | Client profile, Today, dashboard |
| Trainer marks Absent | attendance | Consecutive-absence counter recalculated | Trainer and admin if 3 absences in a row | Client profile, dashboard at-risk card |
| Admin marks Cancelled by gym | attendance | No session used | None | Today, client profile |
| Nightly job, end date passed | subscriptions, clients, audit\_log | Status becomes Extended; extension\_end\_date = end date + 14 days | Admin: client moved to Extended | All Clients, dashboard |
| Nightly job, extension passed | subscriptions, clients, slots, audit\_log | Status becomes Deactivated; slot row closed (valid\_to set); seat free | Admin: client deactivated; slot-matching suggestion for inquiries | Timetable, Past Clients, dashboard |
| Admin renews or reactivates | subscriptions (new row), slots (new row), clients, audit\_log | Old subscription stays as history; new dates and sessions start | Trainer: client renewed | Timetable, All Clients, Past Clients |
| Admin changes trainer | clients, slots, audit\_log | All future sessions move; visibility moves; old trainer loses access | New trainer: client assigned; old trainer: client removed | Both trainers' screens, timetable |
| Admin changes slot | slots (close old row, open new row), audit\_log | Today's list and grid change from the effective date | Trainer: slot changed | Timetable, Today |
| Trainer saves assessment | assessments, documents (if files), audit\_log | Server recalculates every auto value and the FS-7 score, stores snapshot; baseline or final due flag cleared | Admin: none; nutritionist: new assessment on assigned client | Client profile, reports |
| Admin assigns nutritionist | clients, audit\_log | Nutritionist gains access to this client | Nutritionist: new client assigned | Nutritionist's list |
| Inquiry follow-up logged | inquiry\_followups, inquiries (last\_followup\_date, next\_followup\_date, status) | Cancels the old reminder, schedules the new one | None | Inquiry dashboard, today's calls |
| Inquiry converted | inquiries, clients (new) with source\_inquiry\_id | Whole Add Client flow runs; inquiry linked permanently | Pending reminders for that inquiry cancelled | Inquiries, All Clients, source analytics |
| Staff attendance marked | staff\_attendance | If trainer absent: affected sessions list built | Admin: trainer absent impact | Staff attendance, dashboard |
| Staff deactivated | users | Login blocked, sessions revoked; blocked if the trainer has active clients | None | Team |

## 20. Server functions: the only way the app changes data

Each function runs as one database transaction: it either does everything or nothing. The app never inserts or updates these tables directly. Names are fixed so the builder and the screens agree.

### 20.1 Function list

| Function | Allowed role | Inputs | What it does |
| --- | --- | --- | --- |
| `create_staff` | admin | name, role, phone, email, user\_id, password, shift, weekly\_off | Creates auth user and users row; sets must\_change\_password |
| `reset_staff_password` | admin | user\_id, new\_password | Replaces password, sets must\_change\_password |
| `deactivate_staff` | admin | user\_id | Fails with `HAS_ACTIVE_CLIENTS` if trainer still has active clients; else blocks login |
| `reassign_clients` | admin | from\_trainer\_id, to\_trainer\_id, client\_ids, handover\_note | For each client re-runs `check_slot` against the new trainer; moves clients and slot rows; fails the whole call listing any client that does not fit |
| `check_slot` | admin | trainer\_id, hour\_start, pattern, exclude\_subscription\_id (optional) | Read only. Returns valid true or false with the reason (section 21.1) |
| `create_client` | admin | all profile fields, plan\_id, start\_date, trainer\_id, nutritionist\_id, hour\_start, pattern, payment\_method, consent data | Calls `check_slot`; inserts clients, subscriptions, slots, consents; builds consent PDF; sets baseline due date; writes audit; creates notification |
| `change_slot` | admin | subscription\_id, new\_trainer\_id, new\_hour\_start, new\_pattern, effective\_date | Calls `check_slot`; closes old slot row, opens new one |
| `assign_nutritionist` | admin | client\_id, nutritionist\_id or null | Updates clients.nutritionist\_id, audit, notification |
| `mark_attendance` | trainer (own clients), admin | client\_id, date, status (present, absent, makeup, cancelled), note | Upserts one attendance row per client per date; recalculates remaining sessions; applies auto-complete and due flags; enforces 24-hour edit limit for trainers |
| `hold_subscription` / `resume_subscription` | admin | subscription\_id, hold\_from, release\_slot (yes or no) | Sets status Hold; on resume shifts end\_date by days held and returns to Active, re-checking the slot if it was released |
| `run_status_job` | system (nightly) | none | Applies extension and deactivation (section 21.2) |
| `renew_subscription` | admin | client\_id, plan\_id, start\_date, hour\_start, pattern, trainer\_id | Closes any open subscription, creates a new subscription and slot after `check_slot`, sets client Active |
| `deactivate_client` | admin | client\_id, reason | Sets Deactivated, closes slot, stores required reason |
| `save_assessment` | trainer (own clients), admin | client\_id, subscription\_id, type, all input fields, remarks | Validates ranges, recalculates every auto value with the shared module, stores inputs plus `calculated_json` and fs7\_score, clears the due flag |
| `upload_document` | trainer, nutritionist (own or assigned), admin | client\_id, kind, file, doc\_date, notes | Stores file in the private bucket, inserts documents row |
| `add_note` | trainer, nutritionist, admin | client\_id, kind, visibility, body | Inserts a note; an edit inserts a new version linked to the old one |
| `generate_report` | trainer, nutritionist (view), admin | client\_id, subscription\_id | Reads baseline and final snapshots, builds the PDF, stores it, returns a signed link |
| `create_inquiry` | admin | all inquiry fields | Inserts inquiry, sets last\_followup\_date = inquiry\_date, schedules reminder |
| `log_followup` | admin | inquiry\_id, outcome, remarks, next date and time (optional if closing) | Inserts follow-up row, updates inquiry dates and status, replaces the scheduled reminder |
| `convert_inquiry` | admin | inquiry\_id, then the full `create_client` inputs | Runs `create_client`, then marks inquiry Converted and links client |
| `close_inquiry` / `reopen_inquiry` | admin | inquiry\_id, reason | Sets Lost or Not interested with reason, cancels reminders; reopen reverses |
| `mark_staff_attendance` | admin | user\_id, date, status, in\_time, out\_time, note | Upserts one row per person per date; sets late\_flag by shift and grace; if a trainer is absent, builds the affected-sessions list |
| `cancel_sessions_for_trainer` | admin | trainer\_id, date | Bulk marks that day's sessions Cancelled by gym |
| `get_dashboard` | admin, trainer | none | Returns every dashboard figure in one call (section 15) |
| `get_source_analytics` | admin | date range | Returns the table, chart data and insight cards from section 12 |

### 20.2 Error codes (the screen shows the message, never raw errors)

| Code | Meaning | Message shown |
| --- | --- | --- |
| `SLOT_FULL` | A day would have more than 2 clients | This hour is full for that pattern |
| `SLOT_PATTERN_TAKEN` | M1, M2, T1 or T2 already used in that hour | That seat is already taken |
| `SLOT_OUTSIDE_HOURS` | Hour is outside the trainer's working hours | Trainer does not work at this time |
| `HAS_ACTIVE_CLIENTS` | Trainer still has active clients | Move this trainer's clients first |
| `NOT_YOUR_CLIENT` | Role rule violation | You do not have access to this client |
| `EDIT_WINDOW_CLOSED` | Trainer editing attendance older than 24 hours | Only admin can change this now |
| `NO_SESSIONS_LEFT` | Marking Present when remaining is 0 | No sessions left on this plan |
| `OPEN_SUBSCRIPTION_EXISTS` | Creating a second active plan | This client already has an active plan |
| `PHONE_EXISTS` | Duplicate phone on client or open inquiry | This number already exists |
| `OUT_OF_RANGE` | Measurement outside allowed range | Please check this value |

## 21. Slot engine and nightly job: exact logic

These are the two pieces of logic builders most often get wrong. Implement them exactly as written, as server functions, and write the test cases below before building any screen.

### 21.1 check\_slot (slot validity)

Day codes: Mon=1, Tue=2, Wed=3, Thu=4, Fri=5, Sat=6. Sunday is closed.

```text
PATTERN_DAYS:
  A5 = {1,2,3,4,5}
  M1 = M2 = {1,3,5}
  T1 = T2 = {2,4,6}

check_slot(trainer, hour, new_pattern, exclude_subscription):
  1. If hour is outside the trainer's working hours       -> SLOT_OUTSIDE_HOURS
  2. existing = all OPEN slot rows for (trainer, hour)
               where valid_to is null or in the future,
               excluding the row of exclude_subscription
  3. If new_pattern in {M1,M2,T1,T2} and any row in existing
     has the same pattern                                  -> SLOT_PATTERN_TAKEN
  4. For each day d in PATTERN_DAYS[new_pattern]:
        count = number of rows in existing whose pattern covers day d
        if count + 1 > 2                                   -> SLOT_FULL
  5. Return valid
```

A slot row is "open" while its subscription is Active, Extended or Hold with release\_slot = no. Completed, Deactivated and released-hold subscriptions have valid\_to set, so they stop counting at once. The timetable grid and the free-slot finder both read the same open rows, so they can never disagree with `check_slot`.

| Existing in that hour | Adding | Result | Reason |
| --- | --- | --- | --- |
| nothing | A5 | valid |  |
| A5 | M1 | valid | Mon to Fri count = 2 |
| A5 + M1 | T1 | valid | Tue, Thu = 2, Sat = 1 |
| A5 + M1 | M2 | `SLOT_FULL` | Mon, Wed, Fri would be 3 |
| A5 + M1 | A5 | `SLOT_FULL` | Mon, Wed, Fri would be 3 |
| A5 + A5 | any | `SLOT_FULL` | Mon to Fri already 2 |
| M1 | M1 | `SLOT_PATTERN_TAKEN` | Same seat code |
| M1 + M2 + T1 | T2 | valid | Completes M1+M2+T1+T2 |
| M1 + M2 | A5 | `SLOT_FULL` | Mon, Wed, Fri would be 3 |

The grid shows each block under its pattern's days. For a partly filled hour, the free options shown on screen are exactly the patterns for which `check_slot` returns valid; the screen calls `check_slot` for each of the five patterns and enables the ones that pass.

### 21.2 Today's session list

A client is due on date D for their trainer when all of these are true:

1. The client has an open slot row whose pattern covers weekday(D) and whose valid\_from is on or before D and valid\_to is empty or on or after D.
2. D is on or after the subscription start\_date and on or before end\_date (or extension\_end\_date when Extended).
3. The subscription is Active or Extended (not Hold, Completed or Deactivated).
4. The gym is not marked closed on D, and the trainer's staff attendance on D is not Absent or Leave (those clients go to the "Affected sessions" list instead).

The list is sorted by hour. An attendance row for that client and date, if it exists, shows as the current state; otherwise the row is "Not marked".

### 21.3 mark\_attendance side effects

```text
mark_attendance(client, date, status, note):
  1. Check caller is the client's trainer or admin           -> NOT_YOUR_CLIENT
  2. If caller is trainer and date is older than 24 hours    -> EDIT_WINDOW_CLOSED
  3. Upsert ONE attendance row for (client, date)
  4. used      = count of rows with status present or makeup in this subscription
     remaining = total_sessions - used
     If status is present or makeup and remaining would go below 0 -> NO_SESSIONS_LEFT
  5. If remaining == 0:
        subscription.status = completed ; close slot (valid_to = date) ; client.status = completed
        notify admin "plan completed"
  6. If remaining <= 3 or days_left <= 7, and no final assessment exists:
        set final_assessment_due = true ; notify trainer once
  7. Recount consecutive absences; if 3 -> notify trainer and admin
  8. Write audit_log
```

### 21.4 run\_status\_job (nightly, 00:30 IST)

```text
run_status_job(today):
  A. For every subscription with status = active and end_date < today:
       if remaining > 0:
          status = extended
          extension_end_date = end_date + 14 days     (set only if still empty)
          client.status = extended ; notify admin
       else:
          status = completed ; close slot ; client.status = completed
  B. For every subscription with status = extended and extension_end_date < today:
       if remaining > 0:
          status = deactivated ; deactivation_reason = "plan expired"
       else:
          status = completed
       close slot (valid_to = extension_end_date) ; client.status accordingly
       notify admin ; run slot matching for the freed seat
  C. For every subscription with status = hold and hold_to < today:
       leave unchanged (admin must resume); notify admin "hold overdue"
  D. Write one audit_log row per change
```

**Idempotent:** running the job twice in one night changes nothing the second time, because every step only acts on rows still in the earlier state. If a night is missed, the next run catches up because every test uses "before today" rather than "equals yesterday". Dates are compared in India Standard Time, not UTC.

**Only one extension ever:** the extension\_end\_date is set once and never changed; a Deactivated or Completed subscription cannot become Extended again.

## 22. Workflows A to F

Read each as: screen action, then the function called, then what changes, then what the user sees. The builder should implement and test one workflow end to end before starting the next.

### Workflow A: Setting up the gym (first run)

1. A seeded admin account exists after deployment (user ID and password given by the owner). Login screen calls Auth; the token carries `role = admin`.
2. Admin opens Settings and confirms units, BMI standard, reminder times, gym location and consent text. These save to `settings`.
3. Admin checks the four plan rows and the inquiry source list (seeded from sections 7.2 and 12.1) and edits if needed.
4. Admin opens Team, taps Add Trainer, fills the form including User ID and password. `create_staff` runs. The trainer row appears in Team and as a new row in the Timetable (empty).
5. Same for the nutritionist and extra staff (staff role has no login and no password).
6. Admin loads existing clients and inquiries through the one-time Excel import, or adds them by hand.

### Workflow B: Adding a client (the longest chain)

1. Admin taps Clients, then Add. The wizard keeps all answers in memory and saves nothing until the last step.
2. Steps 1 to 5 collect profile, emergency contact, program, trainer and optional nutritionist.
3. Plan step: admin picks a plan and start date. The screen shows total sessions and the end date calculated by the shared date rule (start plus months minus one day).
4. Slot step: the screen loads the chosen trainer's open slots, draws the grid, and for the tapped hour calls `check_slot` for all five patterns to enable or disable them. The admin chooses one.
5. Consent step: client and trainer sign on screen; signatures are held as images.
6. Review step: admin taps Save. The app calls `create_client` once with everything.
7. On the server, in one transaction: re-run `check_slot` (someone else may have booked it meanwhile; if it fails the wizard returns to the slot step with the error), insert the client, subscription (status Active), slot row and consent; store the consent PDF; set baseline due date to start date plus 7 days; write audit; create the notification for the trainer.
8. The app shows the new profile with a card "Start baseline assessment". The timetable block exists immediately.

### Workflow C: A normal training day

1. Morning: the trainer's phone receives the session summary notification (created by the daily reminder job) and the Today screen is already cached for offline use.
2. Trainer opens Today; the list follows the rules in section 21.2.
3. After each session the trainer taps Present or Absent. The repository calls `mark_attendance`. If offline, the call goes to the queue and the row shows a small clock icon until synced.
4. The server applies section 21.3. The client's counters update on every screen subscribed to that client.
5. If the trainer forgets, the end-of-day reminder fires for unmarked sessions, and admin gets a notification an hour after the last slot.

### Workflow D: Night-time status changes

1. At 00:30 IST the cron triggers `run_status_job` (section 21.4).
2. Plans with sessions left move to Extended; plans past their extension move to Deactivated or Completed.
3. For each change the job writes audit rows and creates admin notifications, and closes the slot so the seat is free in the morning.
4. At 08:00 the notification job turns pending notification rows into pushes (FCM) and schedules local notifications on devices.
5. Next morning the admin sees the changes on the dashboard and in Past Clients.

### Workflow E: Renewing or restarting a client

1. Admin opens Past Clients (or the profile of an Extended client) and taps Renew.
2. The screen pre-fills the same plan, trainer and slot. It calls `check_slot` for the old slot. If free, it is kept; if taken, the grid opens so the admin picks another.
3. Admin confirms the start date and taps Save. The app calls `renew_subscription`.
4. The server closes any open subscription, creates a new one with fresh total sessions and dates, creates the slot row, sets the client Active and writes audit.
5. Old attendance and assessments stay attached to the old subscription. The new subscription gets its own Baseline due date. The client profile history tab now lists both plans.

### Workflow F: Fitness assessment

1. Trainer opens a client, then Assessments, then Start Baseline (or Final). The app checks `type` against the subscription so only one Baseline and one Final can exist.
2. The form reads age, gender, goal and last weight from the profile. The trainer enters the values in the units chosen in Settings.
3. While typing, the shared calculation module converts units and shows every auto value on screen.
4. Trainer taps Save. The app calls `save_assessment` with raw inputs only (not calculated values).
5. The server validates ranges, recalculates everything with the same module, stores inputs, `calculated_json` and fs7\_score, clears the due flag, writes audit.
6. If the trainer attaches a BCA or blood report, `upload_document` stores the file and links it to this assessment.
7. When the Final assessment saves, the profile shows a "Generate Transformation Report" button; `generate_report` builds the PDF from the stored Baseline and Final snapshots and returns a signed link to share.

## 23. Workflows G to L

### Workflow G: Inquiry to client

1. Admin taps Add Inquiry. `create_inquiry` checks the phone for duplicates (`PHONE_EXISTS` shows the existing record with a link instead of saving a duplicate). It sets last\_followup\_date equal to inquiry\_date and status New.
2. The server schedules a reminder row for the next follow-up date (time if given, otherwise the morning digest).
3. Every morning the digest job counts inquiries where next\_followup\_date is today and where it is overdue, and creates one admin notification with the count and first names. A separate row is created for each timed follow-up, 15 minutes before its time.
4. Admin opens Inquiries, which opens on today's calls. Tapping Call opens the phone dialer; WhatsApp opens a chat with the number. Afterwards admin taps Log follow-up.
5. `log_followup` inserts the follow-up row, sets last\_followup\_date to today, copies the new next follow-up date and time to the inquiry, sets status Follow-up, and replaces the old reminder row with a new one.
6. If the outcome is Converted, the app opens the Add Client wizard (Workflow B) pre-filled; on a successful `create_client`, `convert_inquiry` stores converted\_client\_id, sets status Converted and cancels reminders. If the wizard is abandoned, the inquiry stays open.
7. If the outcome is Not interested, `close_inquiry` requires a reason from the list and cancels reminders.
8. Source analytics read from inquiries and follow-ups only; they update on the next open of the Analytics tab (no separate calculation to maintain).

### Workflow H: Admin marks staff attendance

1. Admin opens Staff Attendance; the screen loads all active users for the chosen date with any existing rows.
2. Mark all present creates a draft in the app; the admin changes exceptions, then taps Save. The app calls `mark_staff_attendance` once per changed person (or one batch call).
3. The server sets late\_flag by comparing in\_time with shift\_start plus grace minutes.
4. If a trainer is Absent or Leave, the server builds the affected sessions list for that trainer and date (section 21.2) and creates an admin notification with the count.
5. The dashboard card Staff present today reads the same rows.

### Workflow I: Trainer is absent (links staff attendance to client sessions)

1. After Workflow H marks a trainer Absent, admin taps the notification. The Affected sessions screen lists each client with hour and pattern.
2. For each client admin chooses **Reassign for the day** (pick another trainer who is free that hour; the screen uses `check_slot`-style availability for that day only) or **Cancel by gym**.
3. Cancel calls `mark_attendance` with status cancelled, which uses no session. Reassign for the day inserts a one-day override so the client appears on the other trainer's Today screen for that date only; attendance is then marked by that trainer.
4. The client's plan dates do not change, because a cancelled session simply leaves sessions remaining unchanged and the automatic extension covers any shortfall.

### Workflow J: Moving a client to another trainer

1. Admin opens the client or Team, taps Reassign, picks the new trainer and writes the handover note.
2. The screen shows the new trainer's grid. If the current hour and pattern are free it is kept; otherwise admin picks a free slot.
3. `reassign_clients` (or `change_slot`) runs `check_slot` against the new trainer, updates clients.trainer\_id, closes the old slot row and opens the new one, stores the handover note, writes audit, notifies both trainers.
4. Row-level security reads clients.trainer\_id, so the old trainer loses access and the new trainer gains it at the same moment, with no extra code.
5. Removing a trainer from the gym uses the same function in bulk; `deactivate_staff` only succeeds after the trainer has zero active clients.

### Workflow K: Nutrition

1. Admin assigns or removes a nutritionist on a client with `assign_nutritionist`.
2. The nutritionist's My Clients list is a direct query of clients where nutritionist\_id equals their user ID; nothing else needs to change.
3. The nutritionist opens a client, reads assessments and reports (read only), adds notes with `add_note` (shared or private) and uploads files with `upload_document`.
4. Notes marked shared appear in the trainer's Notes tab; private notes never appear to anyone except the author and admin.
5. Check-in reminders and plan-ending alerts for the nutritionist are generated by the daily reminder job using the same plan dates as the trainer sees.
6. When the client's plan ends (Workflow D) the nutritionist keeps read access to the history, but no new notes can be added unless the client is active again.

### Workflow L: How notifications are made and delivered

1. Any server function or job that needs to tell someone something inserts a row in `notifications` with user\_id, type, payload and scheduled\_for.
2. A delivery job runs every minute, picks rows where scheduled\_for is due and sent\_at is empty, sends them through FCM to the user's registered device tokens, and sets sent\_at.
3. Each device registers its token at login and removes it at logout. Opening the app also schedules local notifications for the next 24 hours of pending rows, so follow-up reminders still appear offline.
4. Tapping a notification opens the exact screen from its payload (for example the follow-ups list or a client profile).
5. Rows are never deleted; read\_at is set when the user opens it, which also drives the badge count.
6. Changing a follow-up, closing an inquiry, or deactivating a user cancels that person's pending rows by setting a cancelled flag, so nobody receives outdated reminders.

## 24. Data model additions and row-level permission rules

### 24.1 Additions the workflows need (add to section 16)

| Table or column | Purpose |
| --- | --- |
| `session_overrides` (client\_id, date, trainer\_id, hour\_start, created\_by) | One-day trainer swap when a trainer is absent (Workflow I). The Today list (section 21.2) shows the client under the override trainer on that date |
| `trainer_handovers` (client\_id, from\_trainer\_id, to\_trainer\_id, note, at) | Handover note when reassigning (Workflow J) |
| `notifications.cancelled` (boolean) | Lets the server cancel outdated reminders (Workflow L) |
| `device_tokens` (user\_id, token, platform) | Push delivery targets |
| `subscriptions.baseline_due_date`, `subscriptions.final_assessment_due` (boolean) | Drive assessment reminders and badges |
| `clients.consecutive_absences` (integer) | Fast at-risk check, maintained by `mark_attendance` |
| `app_settings.gym_closed_dates` | Holidays that suppress the Today list and attendance expectations |

### 24.2 Row-level security (enforced in the database)

Turn on row-level security for every table. The role comes from the signed login token, never from a value sent by the app. "Own client" means `clients.trainer_id = current user`; "assigned client" means `clients.nutritionist_id = current user`.

| Table | Admin | Trainer | Nutritionist | Staff (no login) |
| --- | --- | --- | --- | --- |
| users | Read and write all | Read own row; read names of other trainers (for display only) | Read own row | None |
| clients | All | Read and update own clients | Read assigned clients | None |
| subscriptions, slots | All | Read for own clients only; the trainer's timetable shows only their own row | Read for assigned clients | None |
| attendance | All | Read and write for own clients (24 hour edit limit enforced in `mark_attendance`) | Read for assigned clients | None |
| assessments | All | Read and write for own clients | Read for assigned clients | None |
| documents | All | Read and add for own clients | Read and add for assigned clients | None |
| consents | All | Read for own clients | None | None |
| notes | All | Read and write own notes; read shared notes of own clients | Read and write own notes; read shared notes of assigned clients | None |
| diet\_plans, nutrition\_checkins | All | Read for own clients | Read and write for assigned clients | None |
| inquiries, inquiry\_followups, inquiry\_sources, marketing\_spend | All | None | None | None |
| staff\_attendance | All | Read own rows | Read own rows | None |
| norm\_tables, plans, settings | Read and write | Read | Read | None |
| notifications | Read own and all | Read own | Read own | None |
| audit\_log | Read | None | None | None |

The storage bucket follows the same rules: a file can be opened only if the person could read the document row that points to it, and links expire after 10 minutes.

**Test every rule from outside the app:** log in as a trainer and try to read another trainer's client through the API directly; it must return nothing. The same for a nutritionist and unassigned clients, and for any non-admin trying to read inquiries.

## 25. Screen to function map and live refresh

Each screen has exactly one data source and a short list of actions. If a screen needs something not listed, add it here first.

| Screen | Reads (query or view) | Actions (functions called) | Live refresh | Offline |
| --- | --- | --- | --- | --- |
| Login | Auth | sign in, first-login password change | None | No |
| Admin Home | `get_dashboard` | None (taps open lists) | Re-fetch on attendance, status or inquiry change | Cached last result |
| Timetable | open slot rows for all trainers plus client names, for the visible week | `check_slot`, `change_slot`, `reassign_clients` | Subscribe to slots | Cached |
| Clients list | clients with current subscription summary, filters | Open profile, Add | Subscribe to clients | Cached |
| Add Client wizard | plans, trainers, nutritionists, open slots | `check_slot` (many), `create_client` | None | No (needs live slot check) |
| Client profile: Overview, Plan and Attendance | client, current subscription, attendance rows | `mark_attendance`, `hold_subscription`, `resume_subscription`, `renew_subscription`, `deactivate_client` | Subscribe to this client's attendance and subscription | Cached |
| Client profile: Assessments | assessments, documents | `save_assessment`, `upload_document`, `generate_report` | Subscribe to assessments | Form works offline, saves when online |
| Client profile: Notes, Nutrition | notes, diet\_plans, nutrition\_checkins | `add_note`, `assign_nutritionist`, `upload_document` | Subscribe to notes | Cached |
| Today (trainer) | Today list (section 21.2) | `mark_attendance` | Subscribe to attendance for own clients | **Yes, fully** |
| My Timetable (trainer) | own open slot rows | None | Subscribe to slots | Cached |
| Past Clients | clients with status completed or deactivated | `renew_subscription` | Subscribe to clients | Cached |
| Inquiries: Today's calls and list | inquiries filtered by dates and status | `create_inquiry`, `log_followup`, `convert_inquiry`, `close_inquiry` | Subscribe to inquiries | Cached for today |
| Inquiries: Analytics | `get_source_analytics` | None | Re-fetch on open | No |
| Staff Attendance | users plus staff\_attendance for date | `mark_staff_attendance`, `cancel_sessions_for_trainer` | None | Queue writes |
| Team | users | `create_staff`, `reset_staff_password`, `deactivate_staff` | Subscribe to users | Cached |
| Reports (admin) | assessments and attendance aggregates | `generate_report` | Re-fetch on open | No |
| Settings | settings, plans, sources, norm\_tables | Direct edits allowed here only (admin) | None | No |
| Notifications | notifications of this user | Mark read | Subscribe | Cached |

**Refresh rules the builder must follow:**

- After any successful function call the repository invalidates the affected queries, so the screen shows server truth and not an assumed result. Optimistic updates are allowed only for `mark_attendance` and must roll back on an error code.
- Every list screen supports pull to refresh.
- Offline queue items replay in the order created. If one fails with a business error (for example `NO_SESSIONS_LEFT`), the queue stops that item, marks it red, and tells the user; it never retries a business error silently.
- Dates shown and compared in the app use India Standard Time. The database stores dates as `date` and times as `timestamptz`; the app never builds dates from text.

## 26. Builder guardrails: mistakes to prevent and how to prompt

### 26.1 Rules the builder must follow

1. **Backend first, screens second.** Create the database schema, row-level security, server functions and cron jobs (sections 16, 20, 21, 24) and test them with no UI at all. Only then build screens.
2. **No business rule in a screen.** Slot validity, status changes, session counts, extension dates and permissions exist only on the server. A screen may show a preview, but the server decides.
3. **One calculation module.** The assessment form and the server use the same formulas (section 9). Do not write the formulas twice.
4. **Slots belong to subscriptions.** Never attach a slot directly to a client. Ending a subscription must close its slot rows.
5. **One active subscription per client.** Enforce with a database constraint, not only in code.
6. **No hard deletes.** Use `archived` or status changes. History (attendance, assessments, audit) must survive deactivation and renewal.
7. **All dates in India Standard Time** for comparisons and the nightly job; store `date` and `timestamptz`, never text dates.
8. **Permissions from the token.** Never trust a role or user ID sent by the app. Test with direct API calls.
9. **Idempotent jobs.** The nightly job and the notification delivery job can run twice without double effects.
10. **No placeholder logic.** If a function in section 20 is not built, the screen that needs it is not built. Do not fake results with sample data.
11. **Use only the names in this document** for tables, columns, statuses, patterns and functions. Do not rename `A5`, `M1`, `M2`, `T1`, `T2` or invent extra patterns.
12. **Units:** store cm and kg always; convert only for display and entry.

### 26.2 Mistakes this app is most likely to suffer

| Likely mistake | Correct behaviour |
| --- | --- |
| Allowing three clients in one trainer-hour (for example A5, M1, M2) | `check_slot` per section 21.1; run the nine test cases first |
| Treating A5 as Mon to Sat | A5 is Monday to Friday only |
| Slot stays occupied after the plan ends | Slot closes when the subscription becomes Completed or Deactivated |
| Extension applied more than once, or from the wrong date | Set once to end date plus 14 days; never changed |
| Session count stored as a number that drifts | Always count attendance rows; never keep a separate counter |
| Absent or Cancelled sessions reducing the total | Only Present and Make-up count as used |
| Trainer can see everyone because filtering is only in the app | Row-level security on the server (section 24) |
| Assessment values recalculated differently on the report | Report reads the stored `calculated_json` snapshot |
| VO2max uses minutes as mm.ss | Convert 11:34 to 11.567 decimal minutes first |
| Waist and neck mixed between cm and inch in body fat | Convert to cm before the formula |
| Inquiry last follow-up date empty on creation | Default to the inquiry date |
| Old follow-up remarks overwritten | Insert a new follow-up row each time |
| Reminders still fire for a closed or converted inquiry | Cancel pending notification rows on change |
| Staff attendance confused with client attendance | Separate tables and screens |
| Nutritionist sees clients without nutrition | Visibility only where `nutritionist_id` equals their ID |

### 26.3 How to give this document to the builder AI

Do not paste the whole document and ask for "the full app" in one go; that produces the mistakes you saw. Work in modules, and with every prompt include sections 1, 18, 19 and 26 (rules and connections) plus the sections for that module.

| Step | Give the builder | Ask it to produce | Done when |
| --- | --- | --- | --- |
| 1. Foundation | Sections 2, 3, 4, 16, 24 | Project setup, theme and logo, login, roles, tables, row-level rules, seeded admin | Admin and trainer can log in; a trainer cannot read another trainer's data through the API |
| 2. Slot engine | Sections 6, 21.1 | `check_slot`, timetable grid | All nine test cases in 21.1 pass and the grid matches the owner's spreadsheet |
| 3. Clients and plans | Sections 7, 20, 22 (A to B) | `create_client`, wizard, client profile, consent PDF | A client created in the wizard appears in the timetable |
| 4. Attendance and status job | Sections 7.3, 7.4, 21.2 to 21.4, 22 (C to E) | `mark_attendance`, Today screen, `run_status_job`, renew and reactivate | Test by moving the system date: extension at day end plus 1, deactivation at extension end plus 1, seat freed |
| 5. Assessments | Sections 8, 9, 10, 22 (F) | Shared calculation module, assessment form, uploads, report PDF | Sample inputs give VO2max about 42.1; report shows correct improvement arrows |
| 6. Inquiries | Sections 12, 23 (G) | Inquiry screens, follow-ups, convert, analytics, reminders | A follow-up due today appears in today's calls and in the 9:00 AM notification |
| 7. Staff and nutrition | Sections 11, 13, 23 (H to K) | Staff attendance, trainer absence impact, nutrition screens | Marking a trainer absent lists affected clients |
| 8. Notifications and dashboard | Sections 15, 23 (L), 25 | Notification tables, delivery job, FCM, dashboard | A push arrives on a real iOS and a real Android phone |
| 9. Extras and release | Section 14 (Phase 1), 17 | Remaining features, offline sync, export, testing | Every test in section 17.3 passes |

**A prompt that works for every step:**

> You are building module \[name\] of the FS-7 gym app. Use only the specification text below. Do not change names of tables, columns, statuses or functions. Implement the server functions and security rules first and show me the SQL. Then build the screens, which must call only the functions listed in section 25. After building, run the test list for this step and report each result as pass or fail. If anything in the specification is unclear, stop and ask instead of guessing.

### 26.4 If the builder still gets something wrong

- Point to the exact section number and quote the rule, for example "section 21.1 step 4 says a day must not exceed 2 clients".
- Ask it to write a failing test first, then fix the code until the test passes.
- Never let it fix a bug by changing the rule; the rules in this document are the owner's decisions.
- When a screen shows wrong numbers, check the database rows first. If the rows are right, the screen is wrong; if the rows are wrong, the server function is wrong.
