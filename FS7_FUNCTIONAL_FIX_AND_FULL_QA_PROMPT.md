# FS-7 APP: FUNCTIONAL BUG FIX AND COMPLETE FEATURE VERIFICATION

You are the lead engineer and QA lead for the FS-7 gym app (Flutter, Supabase, staff-only: Admin, Trainer, Nutritionist). The owner tested the app and found that **many core features do not work as specified**. Your task: find and fix **every** functional defect, not only the examples below, and prove each feature works for each role.

This is a **functional pass**. Security hardening is a separate later pass, but do not break or weaken security while fixing (no role checks removed, no direct table writes added to the app).

**Quality bar:** every feature must be verified by an automated test or a recorded real run, for every role. "I think it works" is not accepted. If you cannot verify something, write UNVERIFIED and say what you need.

---

## 0. RULES FOR THIS PASS

1. **Do not patch symptoms. Find the root cause.** Many of the reported problems come from the same few root causes (navigation and role guards, shared global state across logins, screens loading data from stale lists instead of the database, data not refreshed after saving). Fix the cause once, correctly, then re-test everything it touches.
2. **No manual data entry by the owner.** Create a seed script with fake data (admin, 3 trainers, 1 nutritionist, 2 staff, about 40 clients in every status, attendance history, assessments, inquiries). It must refuse to run in production. Then test with automated tests. The owner must not have to click through the app.
3. **Reproduce first.** For each reported bug (section 1), write a failing automated test or a recorded reproduction **before** fixing, then show it passing after.
4. **No silent failures.** Remove every `catch (_) {}` and similar. Every failure shows a clear message, never a blank screen, never "not found" for a record that exists.
5. **No mock data in the app.** All data comes from the database through the repositories and functions already defined in the project specification. Business rules (slot validity, session counting, status changes, permissions) stay on the server.
6. **Keep the spec.** Behaviour must match the specification the owner supplied (the FS-7 Product and Build Specification and the earlier FINAL BUILDER PROMPT). If this file and the spec differ, ask the owner; do not guess.
7. **Work in order**, commit in small steps, run `flutter analyze` (zero warnings) and all tests before each commit.
8. **Report honestly** with the format in section 8. Do not mark anything fixed without evidence.

---

## 1. BUGS REPORTED BY THE OWNER (reproduce, find root cause, fix, regression-test)

| ID | What the owner saw | What it must do | Where to investigate first |
|---|---|---|---|
| B1 | **Admin taps Add Client, then the app says "client not found".** This is the main feature of the app | The wizard completes, saves, shows a success message, and opens the new client's profile with **all** information (details, plan, slot, trainer, consent, tabs). A valid client never produces "not found" | After saving, the app navigates to a profile that looks the client up from an old cached list or by a wrong or empty id. Check: the id returned by `create_client`; the route parameter; whether the profile loads by id from the database; whether providers are refreshed after the save; whether the wizard passes an object that is lost on navigation; whether `create_client` actually succeeded or failed silently; whether row-level security blocks reading the new row |
| B2 | **Trainer profile screen is empty**: no logout, no details, nothing | Trainer Profile shows photo, name, role, phone, email, working hours, own monthly attendance (read only), change password, notification settings, app version, and a **Logout** button (with confirmation) | The profile screen reads from admin-only data (blocked by security rules) or is not wired to the logged-in user; missing logout widget for the trainer role |
| B3 | **Trainer sees an Add Client button**, and clicking it **opens the admin page** automatically | A trainer must never see Add Client, Add Inquiry, Team, Staff Attendance, Inquiries, Settings, Reports, Past Clients (all clients), or any admin-only action. A trainer must never reach any `/admin/...` screen, even by deep link or back button | One shared widget or screen used by all roles without role checks; router redirects that send everyone to the admin home; a global "current role" that is wrong; missing route guards |
| B4 | **Attendance for other days does not work** | The Today screen has a date strip or picker. The trainer (and admin) can open any date and see exactly the clients due that day (section 3.4), mark Present / Absent / Make-up / Cancelled where allowed, and the counts update | The screen is hard-coded to today; the date change does not reload; the day-of-week rule is wrong; past/future rules not implemented; the query ignores the selected date |
| B5 | **Logins are not isolated**: one login's data or screens show up in another | After logout and login as another user, **nothing** from the previous user is visible: no data, no cached lists, no routes, no back-stack, no providers holding the old user. Each role sees only its own permitted data | Global or static variables, providers that are not reset on sign-out, caches not keyed by user id, router state kept across sessions, a single shared `currentUser` object, local storage not cleared |
| B6 | **Attendance problems** (not saving, wrong counts, wrong list) | Attendance follows section 3.4 exactly | See B4; counts must be derived from attendance rows, never a stored counter |
| B7 | **Client problems** (lists, details, edits missing or wrong) | Everything in section 3.3 works for the right roles | Provider invalidation, wrong filters, missing fields |
| B8 | **"Many other things not working"** | Every item in the feature matrix (section 4) passes | This is why you will check **everything** |

---

## 2. STEP 1: BUILD THE COMPLETE FEATURE INVENTORY (before changing code)

1. List **every route/screen** in the app, every button, tab, menu item, form field, list and dialog. Output `docs/FEATURE_MATRIX.md` with one row per item:

`Role | Screen / route | Element or action | Expected behaviour (from spec) | Current status (Working / Broken / Missing / Wrongly visible) | Evidence`

2. List every provider/repository and every Supabase call it makes, and which screen uses it.
3. Draw the **navigation map** per role (which screens each tab opens, how to go back). Mark any dead end, duplicate screen, wrong redirect or screen reachable by the wrong role.
4. Fill the "Current status" column by actually running the app on seeded data, per role, on an Android emulator or phone and an iOS simulator. Take a screenshot of every screen for each role and save them in `docs/screens/<role>/`.

Do not start fixing until the matrix is complete. The matrix becomes the checklist for the whole pass.

---

## 3. THE CONTRACT: HOW EACH ROLE'S APP MUST WORK

### 3.1 Navigation and role isolation (applies everywhere)

| Role | Bottom tabs | Opens on |
|---|---|---|
| Admin | Home, Timetable, Clients, Inquiries, More | Home dashboard |
| Trainer | Today, My Timetable, My Clients, Profile | Today |
| Nutritionist | My Clients, Profile | My Clients |

- **Admin "More"**: Team, Staff Attendance, Past Clients, Reports and Analytics, Documents, Settings, Audit Log, Logout.
- **Router rules:** routes are grouped by role (`/admin/...`, `/trainer/...`, `/nutritionist/...`). A single redirect function checks: not logged in goes to login; must-change-password goes to the change-password screen; a user opening a route of another role is redirected to **their own** home (never to another role's home); inactive user is signed out. Detail screens (client profile, assessment, inquiry) are shared only where all roles legitimately need them, and then **show or hide actions by role** and the data is limited by security rules.
- **Detail screens load by id from the database** (never from a list held in memory). They show a loading state, then data, or a clear error with a Retry button.
- **Back button / swipe back** goes to the previous screen in the same role, never to another role or to login after login.
- **Logout** (admin: More; trainer and nutritionist: Profile) asks for confirmation, signs out, **clears every provider, cache, local database, queued data except pending offline attendance of that same user, device token**, and returns to Login. After logging in as someone else, no data from the previous user may appear (test in section 6).
- **No user-visible screen shows data of a role it should not.** Hiding a button is not enough: the data itself must be blocked by the database rules; verify both.

### 3.2 What each role can see and do

| Feature | Admin | Trainer | Nutritionist |
|---|---|---|---|
| Dashboard | Full | Own Today summary only | None |
| Timetable | All trainers | Own row only (read only) | None |
| Clients | All, search, filters, add, edit, status actions | Own clients only, **no Add Client**, can edit own client's profile details | Assigned clients only, read only (plus notes and uploads) |
| Add Client wizard | Yes | **No** | **No** |
| Change plan, renew, reactivate, hold, deactivate, change slot or trainer, assign nutritionist | Yes | **No** | **No** |
| Mark client attendance | Yes (any date) | Own clients (24 hour edit window) | No |
| Assessments | Add, edit, view | Add, edit, view for own clients | View only |
| BCA and blood report uploads | Yes | Own clients | Assigned clients |
| Notes | All | Own notes and shared notes of own clients | Own notes and shared notes of assigned clients |
| Nutrition tab (diet plan placeholder, check-ins) | Yes | View | Add and edit for assigned clients |
| Inquiries and analytics | Yes | **No** | **No** |
| Staff attendance (marking) | Yes | Own record, read only | Own record, read only |
| Team (add, edit, reset password, deactivate) | Yes | **No** | **No** |
| Past clients | All | Own, read only | Assigned, read only |
| Settings, Reports, Audit log | Yes | No | No |
| Profile and change password | Yes | Yes | Yes |

### 3.3 Client features (must all work)

1. **Add Client wizard (admin)**, ten steps: personal details, emergency contact, program type, trainer, optional nutritionist, plan and start date (shows total sessions and end date), slot (timetable grid for that trainer; only valid patterns enabled), payment method (Cash or Online), consent with two signatures and PDF, review and save. One save at the end. On success: confirmation, the client opens with all data, the timetable shows the block, and the trainer sees the client in My Clients. On failure: a specific message (slot taken, duplicate phone, and so on) and the wizard keeps the entered data.
2. **Clients list:** search by name or phone; filters by trainer, nutritionist, plan, status, slot; status chips Active, Extended, Completed, Deactivated; each row shows name, trainer, plan, sessions used out of total, end date. Counts are consistent with the dashboard.
3. **Client profile tabs:** Overview, Plan and Attendance, Assessments, Reports and Documents, Notes, Nutrition, History. Every tab loads real data; empty tabs show a helpful empty state.
4. **Edit client profile:** admin and the client's trainer. Changes save and appear everywhere.
5. **Plan actions (admin):** renew, reactivate, hold and resume, deactivate with required reason, change slot, change trainer with handover note, assign or remove nutritionist. Each updates every related screen immediately.
6. **Status rules (server-side):** Active, Extended (automatic 2 weeks, once, only when sessions remain), Completed (all sessions used), Deactivated (extension ended with sessions left). Expired and not renewed means the slot is free on the timetable. Verify with time-travel tests.
7. **Past Clients:** completed and deactivated; Reactivate or Renew from the row.

### 3.4 Attendance features (must all work)

**Client session attendance**
- **Today screen (trainer) and Attendance view (admin)** have a **date strip** (previous day, next day, tap to pick any date; "Today" button). Changing the date reloads the list for that date.
- The list for a date shows exactly the clients due that day: slot pattern covers the weekday (A5 Monday to Friday, M Monday Wednesday Friday, T Tuesday Thursday Saturday), within the plan dates (or extension dates), subscription Active or Extended, not a closed date, not Sunday, and respecting trainer leave and one-day overrides. Sorted by hour.
- Per client row: name, hour, pattern, current state (Not marked, Present, Absent, Make-up, Cancelled by gym), sessions used out of total.
- Marking: one tap Present or Absent, optional note; Make-up (extra day) and Cancelled by gym (admin) available. **Only Present and Make-up use a session.**
- **Rules:** trainers can mark and edit only their own clients and only for dates within the last 24 hours; they can **view** older and future days but marking is disabled with an explanation; admin can edit any date (with an audit entry). Marking Present when no sessions remain is refused with a clear message.
- After marking: the row, the client profile counters and calendar, the dashboard and the sessions-remaining value update at once. Reaching zero remaining marks the plan Completed and frees the slot. Three absences in a row triggers an at-risk alert.
- Works offline for the trainer (queued, clock icon, synced later).
- Test every weekday Monday to Sunday and a closed date.

**Staff attendance (admin only):** date strip; employee list; one tap Present, Absent, Half day, Leave, Week off, Holiday; optional in and out times; late flag from shift plus grace; Mark all present; trainer absence shows the affected clients with options to reassign for the day or cancel the sessions; monthly calendar and summary; Excel or PDF export. Trainers and nutritionist see only their own monthly attendance (read only) in Profile.

### 3.5 Other modules (must all work)

- **Timetable:** grid of trainers by hour; coloured blocks with client names; week and day view; filters; tap a block to open the client; free-slot finder; only valid patterns selectable; free seats after expiry. Trainer sees only own row.
- **Assessments:** Baseline and Final (and optional Checkpoint) per plan; live auto-calculated values while typing; unit selection cm or inch and kg or lb; save; compare baseline vs final; improvement arrows; Transformation Report PDF with logo; BCA and blood report upload, open and share; permitted roles only.
- **Nutrition:** admin assigns a nutritionist per client; the nutritionist's list shows only assigned clients; notes (shared or author only); uploads; diet plan file and notes placeholder.
- **Inquiries (admin):** add inquiry (last follow-up date defaults to inquiry date), today's calls, overdue, upcoming, log follow-up with remarks timeline, convert to client (pre-filled wizard), close with reason, reopen, search and filters, source analytics with insight cards, duplicate phone warning.
- **Team (admin):** add trainer, nutritionist, staff with User ID and password; edit; reset password; deactivate (blocked while a trainer has active clients); working hours.
- **Dashboard (admin):** every card matches the underlying lists exactly (follow-up calls today, overdue, plans ending in 14 days, extension, new inquiries, conversion, active, deactivated this month, free seats, staff present, assessments pending).
- **Notifications:** list, unread badge, tap opens the right screen; push on real devices.
- **Settings (admin):** units, plans, inquiry sources, reminder times, consent text, gym location.
- **Profile (all roles):** details, change password, logout.

---

## 4. STEP 2: AUTOMATED FEATURE-BY-FEATURE VERIFICATION

Create the seed data and automated tests so that **every row of `FEATURE_MATRIX.md` is exercised by a test**. Use integration tests that drive the real UI (Flutter `integration_test` or Maestro) plus database/API tests, running against a local or staging Supabase, never production.

### 4.1 Seed data (fake, deterministic, idempotent, refuses to run in production)
- Users: 1 admin, trainers Faraz, Suyog, Khalfan, 1 nutritionist, 2 staff.
- Timetable: every valid combination of A5, M1, M2, T1, T2 across hours, including full hours and hours with one open seat.
- About 40 clients across all states: new, midway, ending within 14 days, extended, completed, deactivated, on hold; with and without nutritionist; each trainer has a mix.
- Attendance history over three months with present, absent, make-up and cancelled; one client with 3 absences in a row.
- Baseline and final assessments for some clients; BCA and blood files (dummy PDFs).
- Inquiries in every status and source, due today, overdue and upcoming.
- Staff attendance for two months including a trainer absence.

### 4.2 Test groups (all required)
1. **Authentication per role:** each role logs in, lands on its own home with the right tabs; wrong password, deactivated user, must-change-password flow.
2. **Role isolation (UI):** for every route of every other role, a deep link and a manual navigation attempt must end on the user's own home. Trainer does not see: Add Client, Add Inquiry, Team, Staff Attendance, Inquiries, Settings, Reports.
3. **Role isolation (data):** trainer A cannot see trainer B's clients in any screen, in search, in the dashboard or by calling the database directly; nutritionist only assigned clients; non-admin gets zero inquiry rows.
4. **Logout and re-login:** log in as admin, open client lists and inquiries, log out, log in as trainer: no admin data or screens appear anywhere, back button does not return to admin, providers were reset. Repeat trainer to nutritionist to admin and the reverse order.
5. **Add Client end to end (the B1 test):** admin completes all 10 steps with seeded plan and slot; the profile opens with all data; the new client appears in Clients, in the timetable and in the trainer's My Clients; the same flow with a taken slot shows a clear error and keeps the form data; the flow with a duplicate phone number shows PHONE_EXISTS. Repeat 20 times in a row to catch intermittent failures.
6. **Attendance by weekday:** for each of Monday to Sunday and a closed date, the list for that date contains exactly the expected clients (compare against an independent calculation from the seed). Mark each status; counters, calendar, dashboard update; 24 hour rule for trainers; admin edits any date; NO_SESSIONS_LEFT; auto-complete at zero; offline queue and sync; make-up and cancelled.
7. **Status and time travel:** day after end date with sessions left becomes Extended for exactly 14 days; day after the extension becomes Deactivated and the slot is freed; all sessions used becomes Completed; running the job twice changes nothing; renew and reactivate restore Active with history kept.
8. **Slot rules:** the nine cases (A5; A5+M1; A5+M1+T1 valid; A5+M1+M2 full; A5+M1+A5 full; A5+A5+any full; M1+M1 taken; M1+M2+T1+T2 valid; M1+M2+A5 full) through the UI and the database.
9. **Every client action** in section 3.3, per role, including the actions that must be refused for trainers and nutritionists (expect the button hidden **and** the server refusing a direct call).
10. **Assessments and calculations:** golden vectors (male 34, 107.7 kg, 11:34, pulse 178 gives VO2max about 42.1; 84.6 kg and 163 cm gives BMI 31.84; waist, neck, height gives Navy body fat about 34.1 percent), unit toggle conversions, baseline vs final comparison, PDF generation, uploads and permissions.
11. **Inquiries:** full flow including convert to client and analytics numbers checked against the seed.
12. **Team:** creating a trainer with ID and password then logging in as that trainer on a second session; reset password; deactivation blocked with active clients, allowed after reassignment.
13. **Dashboard reconciliation:** each card equals the count obtained by the matching list screen.
14. **Data consistency checks (run after every test group):** for every subscription, `used + remaining = total`; no slot exists for a Completed or Deactivated subscription; no hour has more than 2 clients on any day; each client has at most one open subscription; every client's status equals the status of its current subscription; no orphan rows.
15. **Navigation crawler:** for each role, visit every reachable screen via taps; fail on any exception, red error screen, blank screen, failed network call, "not found" for an existing record, or overflow warning.
16. **Error and edge states:** network off, server error, expired session, double tap on every save button (must not create duplicates), rotating the device, long names, empty lists, 1000 rows scroll performance.
17. **Visual check:** screenshot of every screen per role saved and reviewed; no overlapping text, no cut-off buttons, correct theme (gray, orange, black) and logo.

### 4.3 Proof the tests are real
For the critical rules (role isolation, add client, attendance rules, slot rule, status transitions) deliberately break the code temporarily and confirm a test fails, then revert. List which were checked.

---

## 5. STEP 3: FIX EVERYTHING FOUND

- Fix by root cause, grouped (navigation and role guards, state reset, data loading by id, refresh after save, date handling, missing screens or buttons, wrong visibility).
- Anything in the spec that is **missing** must be built, not skipped. Anything **wrongly visible** to a role must be removed from the UI **and** blocked on the server.
- After each group of fixes, re-run all tests. A fix is accepted only if the earlier failing test now passes and no other test broke.
- Remove dead screens, duplicate screens, unused routes and leftover demo code.

---

## 6. SPECIFIC ACCEPTANCE SCENARIOS (all must pass on a real Android phone and an iOS device or simulator)

1. Admin adds a client with Faraz as trainer, plan 3 months and 12 sessions, slot 7 AM pattern A5. The client profile opens with everything filled in. Faraz logs in on another device and sees the client under My Clients, with no Add Client button anywhere.
2. Faraz opens the Profile tab: sees his details, own attendance, change password, and Logout. He taps Logout and returns to Login.
3. Faraz logs in again, then taps every tab and every button; none opens an admin screen. He pastes or navigates to an admin route and lands back on his own Today screen.
4. Faraz opens the date strip, selects each day of the coming week; the list changes correctly for each day (Sunday shows closed). He marks yesterday's session (allowed) and a session from three days ago (refused with an explanation).
5. Admin logs out, Suyog logs in: Suyog sees none of Faraz's clients or notes.
6. A nutritionist logs in: sees only assigned clients, can add a note and upload a blood report, cannot see the timetable, inquiries, Add Client or staff attendance.
7. Admin moves time forward in the test environment by plan end date plus one day: the client is Extended; plus 15 days: Deactivated and the slot is free on the timetable; admin renews the client with the same slot, status is Active again, old history remains.
8. Admin adds an inquiry, logs a follow-up, converts it to a client; the client appears with source and inquiry date.
9. Admin marks a trainer absent; the affected clients list appears; admin reassigns one client for the day and cancels another; both behave correctly on the trainers' Today screens.
10. Dashboard numbers equal the list counts after all of the above.

---

## 7. NON-NEGOTIABLE UI BEHAVIOUR (check on every screen)

- Every screen has loading, empty and error states. Errors are specific and have Retry.
- Every save button is disabled while saving (no double submit) and shows success or a clear failure.
- After every successful save, the affected lists and detail screens refresh without restarting the app.
- Forms keep the entered data after a failed save.
- Dates, weekdays and times use India Standard Time and are shown consistently.
- No raw exception text, stack traces or "null" visible to users.
- Role-specific actions are hidden for roles that cannot use them, **and** the server refuses them.
- Theme: gray, orange, black; FS-7 logo on login, splash and report headers.

---

## 8. WHAT TO DELIVER

1. `docs/FEATURE_MATRIX.md`: every screen, button and feature per role, with status before and after and evidence.
2. A bug table: `ID | Description | Root cause | Fix (file and commit) | Test that proves it`. Include B1 to B8 and every other defect found.
3. The seed script, the automated test suites and a one-command runner (`make test-all` or `npm run` or `flutter test` equivalents) with instructions in `TESTING.md`.
4. Test run output: total tests, passed, failed, and the data consistency checks result.
5. Screenshots of every screen for each role from a real Android device and an iOS device or simulator.
6. A short plain-language summary for the owner: what was broken, what was fixed, what is still open and why.
7. A list of anything UNVERIFIED or not implemented, with the reason.

**Do not say the app works unless the tests and the real-device run show it.** If a feature from the specification is not built, say so and build it.
