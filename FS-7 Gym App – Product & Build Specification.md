# FS-7 Gym App – Product & Build Specification

This is the final build specification for the FS-7 app: a staff-only business management app for iOS and Android, with no client login, covering timetable, clients, assessments, nutrition, inquiries and staff attendance.

## 1. Decisions locked and what is still open

Every rule below was confirmed by the gym owner and is final; the builder should not re-ask them.

| Topic | Final decision |
| --- | --- |
| Client access | No client login, ever. The app is for staff only (admin, trainers, nutritionist). |
| Slot patterns | A5 = Monday to Friday. M1/M2 = Monday, Wednesday, Friday. T1/T2 = Tuesday, Thursday, Saturday. |
| Valid slot combinations | Per trainer per hour only: A5+M1+T1, A5+A5, or M1+M2+T1+T2. A5 never goes with two other clients. |
| Plan extension | If sessions are not completed by the plan end date, the plan is extended automatically by 2 weeks, once. Still incomplete after that: plan deactivated, client moves to Past Clients. |
| Plan expired and not renewed | The client's slot becomes empty on the timetable at once. |
| Restarting a client | Admin can reactivate or renew a client from Past Clients; the status changes to Active again after a fresh slot check. |
| Prices and billing | None in the app. Plans carry no price. Admin only manages client status. |
| Employee attendance | Marked by the admin only. |
| Logins | Admin creates trainer and nutritionist profiles with a user ID and password at creation time. |
| Nutritionist | Admin assigns clients to a nutritionist exactly like a trainer. Not every client gets nutrition. The nutritionist sees only assigned clients, writes notes and uploads reports. |
| Fitness assessment | Done at the start and at the end of every plan. Reports show improvement and analysis. |
| Documents | BCA test report and blood report can be uploaded to a client profile. |
| Units | Selectable: cm or inch, kg or lb. Stored internally in cm and kg. |
| VO2max | Rockport 1-mile walk test, the widely validated Kline formula (section 9). |
| Branding | FS-7, gray, orange and black, logo supplied by the owner. |

**Still open (builder uses the stated default until the owner answers):**

1. Diet plan: the owner will describe the diet plan feature later. Version 1 holds a placeholder: upload a diet plan file and write notes (section 11).
2. Staff covered by employee attendance: default is trainers, nutritionist and any extra staff admin adds (reception, housekeeping).
3. Flexibility grading: default is Poor, Fair, Good, Excellent. The sheet showed only the letters P and F.

## 2. Product scope and tech stack

FS-7 is one staff-only mobile app that replaces the gym's spreadsheets, paper forms and memory: who trains when, who has sessions left, who needs a follow-up call, and how each client is improving.

| Item | Specification |
| --- | --- |
| App name | FS-7 |
| Platforms | iOS and Android from one codebase. Tablet layout supported for the front desk. |
| Users | Admin (1 or more), Trainers (3 now, add or remove any time), Nutritionist(s), Staff (attendance only, no login needed). |
| Recommended stack | Flutter (or React Native) for the app. Supabase (PostgreSQL, Auth, Storage, Row Level Security, scheduled jobs) or Firebase for the backend. Firebase Cloud Messaging for push notifications. |
| Security rule | All permissions are enforced on the server by row-level rules, never only by hiding screens. A trainer must be unable to read another trainer's client even through direct API calls. |
| Authentication | User ID plus password for all staff. Optional biometric unlock (Face ID, fingerprint) after first login. |
| File storage | Private storage bucket for consent PDFs, BCA reports, blood reports and progress photos. Access by signed links only. |
| Time zone and language | India Standard Time. English. |
| Offline | Today's schedule, client list and attendance marking work offline and sync when the connection returns. |

**Modules:** Timetable, Clients, Assessments and Reports, Nutrition, Inquiries, Staff Attendance, Team, Dashboard, Settings.

## 3. Brand and design system

The look is modern, minimal and premium: near-black surfaces, gray structure, and orange used only where the eye should land.

**Logo:** the supplied file (PNG-01.png) is a transparent PNG with white lettering and an orange "7" with orange divider bars, so it must always sit on a dark background (white parts disappear on white). Use it on the splash screen, login screen, app header and PDF report headers. Ask the owner for an SVG or high-resolution version for the app icon, and a dark-text version for printed PDFs on white paper.

| Token | Value | Use |
| --- | --- | --- |
| Background | #0E0E0E | App background |
| Surface | #1A1A1A, border #2A2A2A | Cards, sheets |
| Surface raised | #262626 | Inputs, selected rows |
| Text primary | #F5F5F5 | Headings, values |
| Text secondary | #9A9A9A | Labels, hints |
| Brand orange | #F58000 (sampled from the logo), pressed #D96F00 | Primary buttons, active tab, key numbers, selected slot |
| Success / Warning / Error | #3FB950 / #F2A93B / #E5484D | Status chips, improvement arrows |

- **Typography:** Inter or Poppins. Large bold numbers for metrics, small gray labels.
- **Shape and space:** 14 px rounded cards, generous padding, one primary action per screen, no gradients or heavy shadows.
- **Dark mode is the default.** A light theme is optional and comes later.
- **Slot pattern colours** in the timetable grid only: A5 red, M1 yellow, M2 magenta, T1 cyan, T2 white or light gray, slightly muted for the dark background. This keeps the grid familiar to the staff.
- **Motion:** subtle only (200 ms fades, progress rings animating once). No decorative animation.
- **Empty states** use the logo mark in gray with one helpful line, for example "No follow-ups today".

## 4. Roles, logins and permissions

Admin creates every account and decides who sees what; nobody can register themselves.

**Creating a trainer or nutritionist profile (admin):** name, phone, email, photo, role, working hours and weekly off, **User ID and password** set by the admin on the same form. The new staff member logs in with those. Admin can reset the password at any time. The staff member can change their own password and is asked to do so at first login (setting on by default). Passwords are stored hashed, and admin cannot read a password after saving it.

| Capability | Admin | Trainer | Nutritionist |
| --- | --- | --- | --- |
| Create, edit, deactivate trainers, nutritionists, staff | Yes | No | No |
| Reset staff passwords | Yes | No | No |
| Create clients, assign trainer and nutritionist, choose plan and slot | Yes | No | No |
| See all clients and the full timetable | Yes | Own clients and own row | Assigned clients only |
| Edit client profile | Yes | Own clients | No |
| Mark client session attendance | Yes (with audit) | Own clients | No |
| Add and edit assessments | Yes | Own clients | No (view only) |
| Upload BCA and blood reports | Yes | Own clients | Assigned clients |
| Write client notes | Yes | Own clients | Assigned clients (nutrition notes) |
| Change client status, extend, deactivate, reactivate, renew | Yes | No | No |
| Inquiries and inquiry analytics | Yes | No | No |
| Staff attendance | Yes | Sees own record | Sees own record |
| Past clients | Yes | Own past clients, read only | Assigned past clients, read only |
| Reports, exports, settings | Yes | Own client reports only | Assigned client reports only |

**Removing a trainer:** blocked while the trainer has active clients. Admin must first move those clients to another trainer using a bulk reassign tool that re-checks the slot rules. Removed staff keep their history but cannot log in.

**Audit trail:** every edit to attendance, assessments, status and plan dates is logged with who, when, and the old and new value. Admin can view the log per client.

## 5. Screens and navigation

Each role gets a short bottom tab bar; everything else is one or two taps away.

| Role | Bottom tabs | Opens on |
| --- | --- | --- |
| Admin | Home, Timetable, Clients, Inquiries, More | Home dashboard |
| Trainer | Today, My Timetable, My Clients, Profile | Today's sessions |
| Nutritionist | My Clients, Profile | Assigned client list |

**Admin "More" menu:** Team (trainers, nutritionists, staff), Staff Attendance, Past Clients, Reports and Analytics, Documents, Settings, Audit Log.

| Screen | What it shows and does |
| --- | --- |
| Login | Logo, User ID, password, biometric option |
| Home (admin) | Dashboard cards from section 15 and quick actions: Add Client, Add Inquiry, Mark Staff Attendance |
| Timetable | Full grid from section 6, filter by trainer, week or day view |
| Clients list | Search, filters (trainer, nutritionist, plan, status, slot), status chips |
| Client profile | Tabs: Overview, Plan and Attendance, Assessments, Reports and Documents, Notes, Nutrition, History |
| Add Client wizard | Steps in section 7 |
| Assessment form | Start or End assessment entry with live calculations (section 8) |
| Assessment report | Before and after comparison and analysis (section 10) |
| Today (trainer) | Clients due now in time order, one-tap Present or Absent |
| Inquiries | Today's calls, overdue, all inquiries, analytics (section 12) |
| Staff Attendance | Date strip, employee list, one-tap status (section 13) |
| Team | Staff list, add or edit profile, reset password, working hours |
| Past Clients | Deactivated and completed clients with Reactivate or Renew |
| Settings | Units, plan types, inquiry sources, reminder times, gym location, consent text |

**Global search** (top of every list) finds clients, inquiries and staff by name or phone number.

## 6. Timetable and slot engine

The timetable recreates the owner's spreadsheet: trainers as rows, hours as columns, and coloured blocks holding the client name and pattern code. It is the heart of the app.

**Grid:** one row per active trainer (Faraz, Suyog, Khalfan now; admin can add or remove rows). Default hour columns are 6 to 7 AM through 11 AM to 12 PM, then 5 to 6 PM through 9 to 10 PM; the midday break is hidden. Working hours are configurable per trainer. Sunday is closed by default and configurable.

| Pattern | Days | Seat use |
| --- | --- | --- |
| A5 | Mon, Tue, Wed, Thu, Fri | 1 seat on each of those days |
| M1 | Mon, Wed, Fri | 1 seat on those days (first MWF seat) |
| M2 | Mon, Wed, Fri | 1 seat on those days (second MWF seat) |
| T1 | Tue, Thu, Sat | 1 seat on those days (first TTS seat) |
| T2 | Tue, Thu, Sat | 1 seat on those days (second TTS seat) |

**The one rule the engine enforces:** every trainer-hour has 2 seats per day. Each pattern occupies a seat on its days, and the total on any day can never exceed 2. M1, M2, T1 and T2 may each be used once per trainer-hour; A5 may be used up to twice. This produces exactly the owner's allowed combinations and nothing else:

| Valid full combination | Why it works |
| --- | --- |
| A5 + M1 + T1 | Mon to Fri has 2 seats filled; Saturday has 1 |
| A5 + A5 | Mon to Fri full |
| M1 + M2 + T1 + T2 | MWF has 2 seats, TTS has 2 seats |

Invalid examples the app must reject: A5 + M1 + M2 (Monday would have 3), A5 + T1 + T2 (Tuesday would have 3), M1 twice in the same hour.

**Booking behaviour:**

- When admin taps an hour for a trainer, only patterns that keep every day within 2 seats are enabled; the rest are greyed out with the reason.
- Partly filled hours show the open seat pattern, for example "A5 taken: M1 or T1 or A5 still free".
- Tapping a block opens the client profile. Long-press offers Move slot, Change trainer, Swap with another client (each re-validated).
- **Empty slot rule:** when a plan ends without renewal (deactivated or completed), the block disappears from the grid immediately and the seat is free for new clients. Reactivating or renewing the client re-checks availability and may require choosing a new slot.
- **Views:** Week view (the pattern grid above) and Day view (who is actually due on a specific date, taking trainer leave and make-up sessions into account).
- **Free slot finder:** admin picks a pattern (for example M1) and optionally a time range, and the app lists every trainer-hour where it is free.
- **Occupancy:** each trainer row shows a percentage of seats filled; the legend shows pattern colours.

## 7. Client lifecycle

A client moves through one fixed path: created by admin, trained and marked present each day, extended once if sessions are left, then deactivated, completed or renewed.

### 7.1 Add Client wizard (admin)

1. **Personal details:** first name, last name, address, date of birth (age is calculated), gender (Male or Female), primary phone, secondary phone, email, profile photo (optional).
2. **Emergency contact:** first name, last name, address, primary phone.
3. **Program type:** Personal Training, Nutrition, Yoga or Group Program (as on the consent form). Default Personal Training.
4. **Trainer:** dropdown of active trainers.
5. **Nutritionist (optional):** dropdown; leave empty if the client has no nutrition plan. Can be added later.
6. **Plan:** pick a plan (7.2) and a start date. The app shows total sessions and the computed end date.
7. **Slot:** the exact timetable grid for the chosen trainer appears. Admin taps a free hour and a pattern (A5, M1, M2, T1, T2). Invalid choices are disabled (section 6).
8. **Payment method:** Cash or Online, stored only as a record on the profile (no amounts anywhere in the app).
9. **Consent and waiver:** the FS-7 informed consent text is shown, with a field for the client's name inside the sentence. Capture member signature and trainer signature on screen. The app creates a signed PDF stored in the client's Documents tab. The consent text is a versioned template editable in Settings, taken from the uploaded PTConsent\_TermsCondition.docx.
10. **Review and Save:** the client becomes Active and the block appears in the timetable at once. The app then offers "Start baseline assessment now" or "Later".

### 7.2 Plans (no prices)

Plans live in a table that admin can extend in Settings without any code change. Fields: name, duration in months, sessions per month, active flag.

| Plan | Months | Sessions per month | Total sessions |
| --- | --- | --- | --- |
| 3 Months, 12 sessions | 3 | 12 | 36 |
| 3 Months, 20 sessions | 3 | 20 | 60 |
| 6 Months, 12 sessions | 6 | 12 | 72 |
| 6 Months, 20 sessions | 6 | 20 | 120 |

End date = start date plus the duration in calendar months, minus one day.

### 7.3 Daily session attendance (trainer or admin)

- The **Today** screen lists the trainer's clients due today, in time order, built from each client's slot pattern and plan dates.
- One tap sets **Present** or **Absent**, with an optional note. Present uses up 1 session. Absent uses none.
- **Make-up session:** a client can attend on a non-scheduled day; the trainer adds it as Make-up and it counts as 1 session.
- **Cancelled by gym:** if a trainer is on leave or the gym is closed, admin marks the day Cancelled. It uses no session and is never counted against the client.
- Trainers can edit attendance for 24 hours; after that only admin can. Every change goes to the audit log.
- The client profile shows: sessions completed, remaining, absent, days left, and a calendar with green (present), red (absent) and gray (cancelled) dots.

### 7.4 Status rules

| Status | When | Slot on timetable | What happens next |
| --- | --- | --- | --- |
| Active | Within plan dates, sessions remaining | Occupied | Normal training |
| Extended | End date passed with sessions remaining | Occupied | Automatic 2 week extension, once only |
| Completed | All sessions used before or during the plan or extension | Freed | Admin may Renew in one tap |
| Deactivated | Extension ended and sessions still remain, or admin deactivates | Freed | Client appears in Past Clients |
| Hold (optional feature) | Admin freezes the plan for travel or injury | Occupied or freed (admin chooses) | End date shifts by the hold length; resume restores Active |

A nightly scheduled job applies the transitions: on the day after the end date it sets Extended and the extension end date to end date plus 14 days; on the day after the extension it sets Deactivated. Only one extension is ever given per plan.

**Reactivate or Renew (admin, from Past Clients or the profile):** pick a plan, start date and slot. The app re-checks slot availability (the old slot may be taken). The client returns to Active, a new subscription row starts, and all old subscriptions, attendance and assessments stay in history.

### 7.5 All Clients and Past Clients

- **All Clients:** search by name or phone; filter by trainer, nutritionist, plan, status and slot. Each row shows name, trainer, plan, sessions used out of total, end date and a status chip (Active green, Extended amber, Completed gray, Deactivated red).
- **Past Clients:** Completed and Deactivated clients with full history. Reactivate or Renew sits on every row.
- Admin can export any list to Excel.

## 8. Fitness assessment (start and end of every plan)

Every subscription has two assessments: a **Baseline** at the start and a **Final** at the end. An optional **Checkpoint** can be added mid-plan. Trainers (own clients) and admin enter them; the nutritionist can view them.

**Timing rules:** the app reminds the trainer to complete the Baseline within the first 7 days of a plan, and the Final when 3 or fewer sessions remain or 7 or fewer days are left. A plan without a Final assessment shows an amber "Assessment pending" badge. After a renewal, the previous Final becomes the next Baseline reference, but a fresh Baseline is still taken.

**Entry rules:** the form uses large numeric inputs, shows units next to each field, and updates every calculated value live while the trainer types. Calculated fields are read-only and marked with a small orange "Auto" tag. **Units:** a setting switches entry between cm and inch and between kg and lb; data is stored in cm and kg. Dates default to today.

| Section | Input fields | Auto-calculated |
| --- | --- | --- |
| Basics | Test date, body weight, height, goal (Fat loss, Muscle gain, Strength, Endurance, General fitness, Other) | Name, age, gender (from profile); BMI, BMI category, healthy weight range |
| Blood pressure | Resting heart rate, systolic, diastolic | BP category, with a doctor-referral warning for crisis values |
| Body measurements | Neck, chest, upper abdomen, waist (widest part), waist (narrowest, natural), hip, arm left and right, thigh left and right, calf left and right | Waist-to-hip ratio and risk, waist-to-height ratio, left-right differences, body fat %, fat mass, lean mass |
| Cardio fitness (Rockport 1-mile walk) | Time (mm:ss), end-of-test pulse | VO2max, fitness category, max heart rate, heart rate zones |
| Recovery (YMCA 3-minute step test) | Recovery heart rate after 1 minute | Recovery category (Excellent to Very poor) |
| Muscular endurance | Push-ups in 60 sec, bodyweight squats in 60 sec, pull-ups (count and time window in seconds) | Rating for each (Poor, Fair, Good, Excellent) |
| Flexibility | Quadriceps, hamstrings, hip flexors, shoulder reach, each graded Poor, Fair, Good or Excellent | Flexibility score out of 100 |
| Overall | Trainer remarks | **FS-7 Fitness Score** out of 100 (section 9) |

The owner's old sheet repeated weight, age and gender inside the cardio test; the app pulls these from the profile and the Basics section so nobody types them twice.

**Documents and photos (per client, tagged to an assessment):**

- **BCA report** (body composition analysis): upload PDF or photo, with a date and notes.
- **Blood report:** upload PDF or photo, with a date and notes.
- **Other documents:** doctor notes, prescriptions, anything else.
- **Progress photos** (optional): front, side and back, shown side by side in the report.
- Files can be opened in-app, shared, and deleted by admin only. Trainer and nutritionist see only their own clients' files. Files are private and never publicly linked.

## 9. Auto-calculations and formulas

Nothing is calculated by hand. All formulas live in one calculations module, run instantly while typing, and are stored as a snapshot with each assessment so old results never change if a norm table is edited later.

### 9.1 VO2max: Rockport 1-mile walk test

Use the Rockport formula from Kline et al. (1987), the most widely used validated estimate for this test.

```latex
VO_2max = 132.853 - 0.0769\,W - 0.3877\,A + 6.315\,G - 3.2649\,T - 0.1565\,H
```

W = weight in pounds (kg x 2.20462), A = age in years, G = 1 for male and 0 for female, T = walk time in decimal minutes (11:34 becomes 11.567), H = heart rate in beats per minute at the end of the walk. Result is in ml/kg/min. The test was validated for ages 30 to 69; for clients outside that range the app still calculates but shows "estimate, outside validated age range".

**Check against the old sheet:** the sample inputs (male, age 34, 107.7 kg, 11:34, pulse 178) give about 42.1 with this formula, while the old spreadsheet showed 38.11. The sheet's formula could not be verified, so the app uses the published one above.

### 9.2 All calculated values

| Output | Formula or rule | Source |
| --- | --- | --- |
| Age | Whole years from date of birth to test date |  |
| BMI | weight (kg) / height (m) squared | WHO |
| BMI category | Under 18.5 Underweight; 18.5 to 24.9 Normal; 25 to 29.9 Overweight; 30 and above Obese. Setting switches to Asia-Pacific cut-offs (23 and 27.5) | WHO, WHO Asia-Pacific |
| Healthy weight range | 18.5 x height squared up to 24.9 x height squared (kg) | WHO |
| BP category | Normal: under 120 and under 80. Elevated: 120 to 129 and under 80. Stage 1: 130 to 139 or 80 to 89. Stage 2: 140 or more, or 90 or more. Crisis: above 180 or above 120, show "refer to doctor" warning | ACC/AHA 2017 |
| Waist-to-hip ratio | waist / hip, using the narrowest waist if entered, else the widest. Raised risk: men 0.90 or more, women 0.85 or more | WHO |
| Waist-to-height ratio | waist / height. Raised risk at 0.5 or more | NICE |
| Body fat % (men) | 495 / (1.0324 - 0.19077 x log10(waist - neck) + 0.15456 x log10(height)) - 450, all in cm | US Navy method |
| Body fat % (women) | 495 / (1.29579 - 0.35004 x log10(waist + hip - neck) + 0.22100 x log10(height)) - 450, all in cm | US Navy method |
| Body fat category | Men: essential 2 to 5, athletes 6 to 13, fitness 14 to 17, average 18 to 24, obese 25 and above. Women: essential 10 to 13, athletes 14 to 20, fitness 21 to 24, average 25 to 31, obese 32 and above | ACE |
| Fat mass, lean mass | fat mass = weight x body fat %; lean mass = weight - fat mass |  |
| Left-right difference | absolute difference and % of the larger side for arms, thighs, calves. Flag at 5% or more (setting) |  |
| Max heart rate | 208 - 0.7 x age | Tanaka et al. |
| Heart rate zones | Karvonen: ((max HR - resting HR) x intensity) + resting HR for 50-60, 60-70, 70-80, 80-90, 90-100 percent | Karvonen |
| VO2max category | Look up age band and gender in the norm table: Very poor, Poor, Fair, Good, Excellent, Superior | ACSM / Cooper Institute tables |
| Recovery category | Look up recovery heart rate by age band and gender: Excellent, Good, Above average, Average, Below average, Poor, Very poor | YMCA 3-minute step test table |
| Push-up rating | Look up count by age band and gender | ACSM norms |
| Squat and pull-up rating | Look up count in a table the gym's head trainer sets in Settings. Until it is set, show the raw count and the change from baseline only | Gym standard |
| Flexibility score | Poor 25, Fair 50, Good 75, Excellent 100 per test; score = average of the four |  |
| BMR (for nutritionist) | Men: 10 x kg + 6.25 x cm - 5 x age + 5. Women: same minus 161 | Mifflin-St Jeor |
| Daily calories (maintenance) | BMR x activity factor chosen by the nutritionist (1.2 sedentary, 1.375 light, 1.55 moderate, 1.725 very active) | Standard |
| Sessions remaining | total sessions - Present - Make-up |  |
| Plan end date | start + months - 1 day; extension end = end + 14 days |  |

All norm tables are stored as editable configuration rows so the gym can correct them without a new app release. The builder must load the published ACSM/Cooper VO2max, YMCA step and ACSM push-up tables into the starting configuration and cite them in the Settings screen.

### 9.3 FS-7 Fitness Score (0 to 100)

A single friendly number that makes improvement easy to show. Each component's category is converted to points: Very poor 10, Poor 30, Fair 50, Good 70, Excellent 90, Superior 100. Body fat category points: Athletes 100, Fitness 90, Average 60, Essential 70, Obese 25.

| Component | Weight |
| --- | --- |
| Cardio fitness (VO2max category) | 25% |
| Body composition (body fat category) | 25% |
| Muscular endurance (average of push-up, squat, pull-up ratings) | 25% |
| Flexibility score | 15% |
| Heart rate recovery | 10% |

If a component was not tested, its weight is shared proportionally among the rest. The score is a motivational indicator for the gym and is labelled "not a medical score" in the app and reports.

## 10. Progress reports and analysis

The report is the moment that impresses the client, so it must look premium. Since clients have no login, staff generate it in the app and share it as a branded PDF or image through WhatsApp, email or print.

**Transformation Report (one per plan, Baseline vs Final):**

1. **Cover:** FS-7 logo, client name, trainer, plan dates, sessions completed out of total, attendance percentage.
2. **Headline result:** large FS-7 Fitness Score from baseline to final with an animated ring and the change (for example 54 to 71, up 17).
3. **Auto-written summary:** 3 to 5 plain sentences generated from the data, for example "Waist reduced by 4.2 cm, body fat down 3.1 points, VO2max up from 38 to 44, push-ups up from 18 to 31."
4. **Before and after table:** every metric with Baseline, Final, change, and a green up or down arrow when it improved, red when it worsened, gray when unchanged.
5. **Fitness profile radar chart:** five axes (cardio, body composition, strength endurance, flexibility, recovery), baseline outline against final outline.
6. **Body measurement chart:** bars for neck to calf changes in cm or inch.
7. **Photos:** optional before and after photos side by side.
8. **Trainer remarks and next goal.**

**Direction of improvement (the app must know which way is good):**

| Lower is better | Higher is better | Closer to a target |
| --- | --- | --- |
| Weight (for fat loss goal), BMI, body fat %, waist, waist-to-hip, waist-to-height, resting heart rate, recovery heart rate, blood pressure | VO2max, push-ups, squats, pull-ups, flexibility score, lean mass, FS-7 Fitness Score | Weight (set by goal: loss, gain or maintain), left-right differences toward zero |

**Analysis screens inside the client profile:**

- **Trend charts** across all assessments of the client (including earlier plans): weight, body fat, waist, VO2max, resting heart rate, FS-7 score.
- **Compare any two assessments** side by side.
- **Consistency view:** attendance percentage and a monthly calendar, so a trainer can link results to effort.
- **Gym-wide analysis (admin):** average improvement per trainer, average FS-7 score change per plan type, and the percentage of clients who improved on each metric. This shows which trainers and programs deliver results.

If a Final assessment is missing, the report is generated with the latest available data and marked "Provisional".

## 11. Nutrition module

Nutrition is an add-on, not part of every client's plan, so it works like trainer assignment: admin chooses who gets it.

- **Assignment:** on the Add Client wizard or any time later, admin selects a nutritionist for the client (or removes one). Admin can bulk-reassign clients when a nutritionist leaves. The client list can be filtered by nutritionist, and the profile shows a "Nutrition: Active" chip only for assigned clients.
- **Nutritionist's view:** only assigned clients appear. Inside a client they can see the profile, goals, all assessments and calculated values (BMI, body fat, BMR, maintenance calories), BCA and blood reports, and the trainer's notes marked as shared.
- **Notes:** the nutritionist writes dated notes on the client. Each note has a visibility option: *Shared with trainer* (default) or *Nutritionist only*. Notes are never edited silently: an edit creates a new version and the history is kept. Trainers can also write training notes visible to the nutritionist.
- **Uploads:** the nutritionist can upload blood reports, BCA reports and any other file for assigned clients (section 8 rules).
- **Check-ins (optional):** the nutritionist records follow-up date, current weight and compliance rating (Poor, Fair, Good) for a simple adherence trend.
- **Reminders:** nutritionist gets a notification for clients whose nutrition check-in is due, and a prompt when a client's plan is within 14 days of ending.
- **Diet plan (placeholder, to be defined by the owner):** version 1 provides a Diet Plan section in the client profile where the nutritionist uploads a diet plan file (PDF or image) with start date and notes. A structured diet builder (meals, quantities, calories, macros) is reserved for the next phase once the owner describes the format. The data model already includes a `diet_plans` table (section 16) so nothing needs rebuilding later.
- **Visibility:** admin sees everything. Nutritionists cannot see unassigned clients, the timetable, inquiries or staff attendance.

## 12. Inquiry follow-up and source analytics (admin only)

Goal: no inquiry is ever forgotten, and the owner can see which marketing channel actually brings paying clients.

### 12.1 Add Inquiry

| Field | Rule |
| --- | --- |
| Name | Required |
| Mobile number | Required. Warns if the number already exists as an inquiry or client |
| Source of inquiry | Dropdown set in Settings: Walk-in, Instagram, Facebook, Google, Website, Justdial, Hoarding or board, Poster or flyer, Referral, Other |
| Reference name | Shown when the source is Referral. Can link to an existing client |
| Inquiry date | Defaults to today, editable |
| Last follow-up date | **Defaults to the inquiry date**, then updates each time a follow-up is logged |
| Next follow-up date | Required while the inquiry is open |
| Next follow-up time | **Optional**. Without it the reminder uses the morning digest time |
| Interested in | Personal Training, Nutrition, Yoga, Group Program (optional) |
| Preferred time and pattern | Optional (for example "7 AM, MWF"), used for slot matching in 12.4 |
| Status | New, Follow-up, Converted, Not interested or Lost (reason required) |
| Remarks | Free text; every remark is also saved in the follow-up timeline |

### 12.2 Follow-up flow

- Each inquiry card has three quick buttons: **Call** (opens the dialer), **WhatsApp** (opens a chat with the number) and **Log follow-up**.
- **Log follow-up** records outcome (Spoke, No answer, Call back later, Visit scheduled, Converted, Not interested), remarks, and the next follow-up date and optional time. The last follow-up date becomes today. Old remarks stay in a timeline and are never overwritten.
- **Convert to Client:** one tap opens the Add Client wizard with name, phone, source and interest pre-filled. After saving, the inquiry is marked Converted and linked to the new client permanently.
- A closed inquiry can be reopened.

### 12.3 Inquiry dashboard

1. **Today's follow-up calls:** names, number, time if set, last remark, with Call, WhatsApp and Done buttons.
2. **Overdue:** missed follow-ups in red at the top.
3. **Upcoming 7 days** grouped by date, and **new inquiries never contacted**.
4. **Search and filters** by status, source, date range and converted or not; export to Excel; bulk import from Excel.

### 12.4 Source analytics: where to put the marketing money

An Analytics tab in Inquiries answers one question: which source is worth investing in. Date range filter: this month, last 3 months, this year, custom.

| Metric per source | Meaning |
| --- | --- |
| Inquiries | Count received |
| Converted | Became clients |
| Conversion rate | Converted / inquiries |
| Average days to convert | Inquiry date to conversion date |
| Lost reasons | Top reasons for losing leads from that source |
| Clients retained | How many converted clients renewed at least once (quality of the source) |
| Cost per inquiry and cost per client | Only if the admin enters an optional monthly marketing spend per source in Settings |

The tab shows a ranked bar chart of sources by inquiries and by conversion rate, a monthly trend line per source, a funnel (inquiries, contacted, visited, converted), and **auto-written insight cards** such as:

- "Referrals converted at 46% against 9% for Instagram. Consider a member referral reward."
- "Instagram brings 41% of inquiries but only 8% become clients. Review follow-up speed or the offer."
- "Inquiries contacted within 24 hours convert at twice the rate of later ones."
- "Most inquiries arrive on Mondays; most conversions follow a walk-in visit."
- "The top reason for lost leads is Timing. 7 AM MWF slots are full while 6 PM is empty."

Also shown: average number of follow-ups before conversion, share of follow-ups completed on time, and a per-month conversion trend.

**Slot matching:** when a slot becomes free (expiry or reassignment), the app suggests open inquiries whose preferred time and pattern fit it, so the empty seat can be filled with one call.

### 12.5 Reminders

Morning digest (default 9:00 AM, "You have 6 follow-up calls today"), a reminder before timed follow-ups, an evening nudge for calls still pending (default 5:00 PM), a next-morning overdue alert, a cold-lead alert when an open inquiry has had no contact for 7 days, and a Monday weekly summary. All times and on-off switches live in Settings. The app icon badge shows today's pending call count.

## 13. Staff attendance (admin only)

Separate from client sessions. Admin marks attendance for every employee: trainers, the nutritionist and any other staff added in Team (reception, housekeeping and so on). Staff cannot mark their own attendance.

- **Daily screen:** a date strip at the top, then the employee list. One tap sets Present, Absent, Half day, Leave, Week off or Holiday. Optional in-time, out-time and note. A **Mark all present** button speeds up the normal day, then admin changes the exceptions.
- **Shifts:** each employee has a shift start, end and weekly off from their profile. Late arrival is flagged automatically when the entered in-time is after the shift start plus a grace period (default 10 minutes, per-employee setting).
- **Trainer absence impact:** when a trainer is marked Absent or Leave, the app lists that day's clients affected and offers Reassign to another trainer for the day, or mark the sessions Cancelled by gym (which does not use up client sessions).
- **Monthly view:** calendar per employee with colour dots (green present, red absent, amber half day, blue leave, gray off). Summary shows days present, absent, half days, leaves, late marks and total hours.
- **Dashboard card:** staff present today, and who is absent.
- **Export:** monthly attendance to Excel or PDF for payroll.
- **Edits:** admin can change any day. Changes older than 7 days need a reason and are recorded in the audit log.
- **Staff view:** a trainer or nutritionist can see their own monthly attendance in Profile, read only.

## 14. Extra features that make FS-7 stand out

These go beyond the brief and are chosen because each saves the owner time or money, or makes clients say "this gym is serious". Phase 1 is part of the first release; Phase 2 follows once the core is stable.

| Feature | What it does | Why it matters | Phase |
| --- | --- | --- | --- |
| Transformation Report | Branded before and after PDF with FS-7 score, radar chart, auto-written summary and photos (section 10) | The wow moment at the end of a plan, and a renewal trigger | 1 |
| Renewal pipeline | A list of clients whose plan ends within 14 days, using the same follow-up and call-reminder flow as inquiries | Renewals are the cheapest revenue; nobody forgets to ask | 1 |
| WhatsApp templates | One-tap prefilled WhatsApp messages: renewal reminder, session reminder, birthday wish, report ready. Opens the chat; no paid API needed | Saves typing, consistent tone | 1 |
| At-risk client alert | Alert trainer and admin when a client misses 3 sessions in a row or attends under 50% in a month | Catches drop-outs before they leave | 1 |
| Hold or freeze plan | Admin pauses a plan for travel or injury; end date shifts by the hold length | Avoids unfair expiry and angry clients | 1 |
| Empty slot radar | Free seats per trainer and hour, an occupancy heatmap by hour and day, and matching of open inquiries to freed slots (sections 6 and 12) | Shows where revenue is being lost | 1 |
| Source analytics with insights | Which channel brings clients, with auto-written advice (section 12) | Spend marketing money where it works | 1 |
| Retention analytics | Renewal rate, average months a client stays, reasons for deactivation (a required dropdown when deactivating) | Tells why clients leave | 1 |
| Owner daily digest | One morning notification: yesterday's sessions and attendance rate, new inquiries, plans ending this week, calls due today | The owner sees the business in 10 seconds | 1 |
| Trainer scorecard | Per trainer: attendance marking on time, client attendance rate, renewal rate, average FS-7 score gain | Fair, data-based reviews and incentives | 2 |
| Birthday and milestone reminders | Birthday list; alert when a client reaches their 50th or 100th session, with a shareable milestone card | Personal touch that builds loyalty | 2 |
| Goal tracker | Client goal with target value and date, shown as a progress bar in the profile | Keeps training purposeful | 2 |
| Trainer handover note | Required short note when a client is moved to another trainer | Smooth transition, no lost context | 2 |
| Structured diet builder | Meals, quantities and macros for the nutritionist, once the owner defines the format | Complete nutrition offering | 2 |

## 15. Dashboard and notifications

**Admin Home** shows cards, each tappable into its list:

- Today: sessions scheduled, marked present, absent, not yet marked.
- Follow-up calls due today and overdue (first and most prominent card).
- Plans ending in 14 days (renewal pipeline) and clients currently in extension.
- New inquiries this week and conversion rate this month.
- Active clients, deactivated this month, free seats in the timetable.
- Staff present today and who is absent.
- Assessments pending (Baseline or Final overdue).
- Quick actions: Add Client, Add Inquiry, Mark Staff Attendance.

**Trainer Home (Today):** today's clients in time order with Present and Absent buttons, a banner for assessments due and at-risk clients, and the trainer's own attendance for the month.

**Push notifications** use Firebase Cloud Messaging plus local scheduled notifications so reminders still fire without internet. Every type can be switched off or timed in Settings.

| Recipient | Notification | When |
| --- | --- | --- |
| Admin | Follow-up digest: "6 calls today" | Daily 9:00 AM (setting) |
| Admin | Timed follow-up reminder | 15 minutes before and at the set time |
| Admin | Pending calls nudge | Daily 5:00 PM (setting) |
| Admin | Overdue follow-ups | Next morning |
| Admin | Cold inquiry, no contact for 7 days | Daily check |
| Admin | Plan ending in 14 days and 7 days | Daily check |
| Admin | Client moved to Extended or Deactivated | When status changes |
| Admin | Trainer has not marked attendance | 1 hour after the last slot of the day |
| Admin | Staff attendance not marked | 11:00 AM (setting) |
| Admin | Weekly summary: inquiries, conversions, renewals, best source | Monday 9:00 AM |
| Trainer | Today's sessions summary | 30 minutes before first session |
| Trainer | Attendance not marked | End of day |
| Trainer | Baseline or Final assessment due | When the rule in section 8 triggers |
| Trainer | Client at risk (3 absences in a row) | When it happens |
| Nutritionist | Nutrition check-in due, client plan ending in 14 days | Daily check |

The app icon badge shows today's pending follow-up calls for admin and unmarked sessions for trainers.

## 16. Data model

Every table has `id`, `created_at`, `updated_at` and `created_by`. Measurements are stored in cm and kg. Deleting is soft (an `archived` flag) so history is never lost.

| Table | Key fields |
| --- | --- |
| users | role (admin, trainer, nutritionist, staff), name, phone, email, photo, user\_id (login), password hash, active, shift\_start, shift\_end, weekly\_off, grace\_minutes, must\_change\_password |
| clients | first\_name, last\_name, address, dob, gender, phone\_primary, phone\_secondary, email, photo, program\_type, payment\_method, trainer\_id, nutritionist\_id (nullable), status, source\_inquiry\_id (nullable), emergency\_first\_name, emergency\_last\_name, emergency\_address, emergency\_phone |
| plans | name, months, sessions\_per\_month, active |
| subscriptions | client\_id, plan\_id, start\_date, end\_date, extension\_end\_date, total\_sessions, status (active, extended, completed, deactivated, hold), hold\_from, hold\_to, deactivation\_reason, renewed\_from\_id |
| slots | subscription\_id, client\_id, trainer\_id, hour\_start, pattern (A5, M1, M2, T1, T2), valid\_from, valid\_to |
| attendance | subscription\_id, client\_id, date, status (present, absent, makeup, cancelled), marked\_by, note |
| assessments | client\_id, subscription\_id, type (baseline, final, checkpoint), test\_date, all input fields from section 8, calculated\_json (snapshot of every auto value), fs7\_score, remarks |
| documents | client\_id, assessment\_id (nullable), kind (bca, blood, consent, diet, photo, other), file\_url, doc\_date, notes, uploaded\_by |
| consents | client\_id, template\_version, signed\_name, member\_signature, trainer\_signature, signed\_at, pdf\_url |
| notes | client\_id, author\_id, kind (training, nutrition), visibility (shared, author\_only), body, version, previous\_version\_id |
| nutrition\_checkins | client\_id, nutritionist\_id, date, weight, compliance |
| diet\_plans | client\_id, nutritionist\_id, start\_date, end\_date, file\_url, notes, structured\_json (reserved for Phase 2) |
| inquiries | name, phone, source\_id, reference\_name, referred\_by\_client\_id, inquiry\_date, last\_followup\_date, next\_followup\_date, next\_followup\_time, interested\_in, preferred\_time, preferred\_pattern, status, lost\_reason, converted\_client\_id |
| inquiry\_followups | inquiry\_id, followup\_at, outcome, remarks, next\_followup\_date, next\_followup\_time, logged\_by |
| inquiry\_sources | name, active |
| marketing\_spend | source\_id, month, amount (optional, used only for cost analytics) |
| staff\_attendance | user\_id, date, status, in\_time, out\_time, late\_flag, note, marked\_by |
| norm\_tables | metric, gender, age\_min, age\_max, category, lower, upper, source |
| settings | units, bmi\_standard, reminder times, gym location, consent template, grace minutes, asymmetry threshold |
| notifications | user\_id, type, payload, scheduled\_for, sent\_at, read\_at |
| audit\_log | actor\_id, table, record\_id, field, old\_value, new\_value, at |

**Key relationships:** a client has many subscriptions over time; each subscription has one slot, many attendance rows and its own Baseline and Final assessments; an inquiry converts into at most one client; a slot belongs to a subscription, so ending or deactivating the subscription frees the slot automatically.

## 17. Quality requirements, build order and acceptance tests

### 17.1 Non-functional requirements

- **Privacy:** health data is sensitive. Encrypt in transit and at rest; private storage buckets; no public links; server-side row-level security for every table; session timeout after inactivity; remote logout when a staff member is deactivated.
- **Performance:** timetable loads in under 2 seconds for 3 trainers and 200 active clients; assessment calculations update in under 100 ms while typing.
- **Offline:** today's schedule, client list and attendance marking work offline and sync later; conflicts resolve by latest edit and are logged.
- **Backups and export:** daily automatic database backup. Admin can export clients, attendance, inquiries and staff attendance to Excel.
- **Reliability:** the nightly status job (extension and deactivation) is idempotent and writes to the audit log.
- **Data import:** a one-time Excel import for existing clients and inquiries.
- **Accessibility:** minimum 16 px body text, contrast ratio of 4.5 or more on the dark theme.

### 17.2 Build order

| Phase | Scope |
| --- | --- |
| 1. Foundation | Login, roles and permissions, team management with admin-created credentials, theme and logo, settings |
| 2. Core operations | Plans, slot engine and timetable, Add Client wizard with digital consent, client profile, daily attendance, status job, Past Clients, renew and reactivate |
| 3. Assessments | Assessment forms with live calculations, norm tables, document uploads, Transformation Report |
| 4. Business growth | Inquiry module, reminders, source analytics, renewal pipeline, nutrition module |
| 5. Staff and polish | Staff attendance, dashboard, push notifications, extra features marked Phase 1 in section 14, offline sync, export |
| 6. Release | Testing on real iOS and Android devices, data import, staff training, launch |

### 17.3 Acceptance tests (the app is done when all pass)

- Admin creates a trainer with a user ID and password, and that trainer can log in and sees only their own clients.
- The slot engine accepts A5+M1+T1, A5+A5 and M1+M2+T1+T2, and rejects A5+M1+M2, A5+T1+T2 and a repeated M1 in the same hour.
- A5 sessions appear Monday to Friday, M sessions Monday, Wednesday, Friday, and T sessions Tuesday, Thursday, Saturday.
- A plan with sessions left on its end date moves to Extended for exactly 14 days, then to Deactivated, the client appears in Past Clients and the timetable seat is free immediately.
- Reactivating a past client with a fresh slot returns them to Active and the history stays intact.
- Marking Present reduces remaining sessions by 1; Absent and Cancelled do not.
- Entering the sample Rockport inputs (male, 34, 107.7 kg, 11:34, pulse 178) produces VO2max of about 42.1 and every Auto field fills without manual calculation.
- Changing units from cm to inch converts entered values and keeps stored values consistent.
- The Transformation Report shows baseline against final with correct improvement arrows and exports as a PDF with the FS-7 logo.
- A BCA report and a blood report can be uploaded, viewed and are inaccessible to unassigned staff.
- An inquiry added today appears in today's follow-ups when its next follow-up date is today; logging a follow-up updates the last follow-up date and keeps older remarks; Convert to Client pre-fills the wizard and marks it Converted.
- Source analytics show conversion rate per source and generate at least one insight card.
- A nutritionist sees only assigned clients and can add notes and upload files.
- Admin marks staff attendance for a month and exports it.
- Push notification arrives on both iOS and Android at the configured morning time with the correct call count.
- The app uses the gray, orange and black theme and the FS-7 logo on both platforms.
