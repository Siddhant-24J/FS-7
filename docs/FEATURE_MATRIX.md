# FS-7 GYM APP: COMPREHENSIVE FEATURE MATRIX

| Role | Screen / Route | Element or Action | Expected Behaviour (from Spec) | Status | Evidence & Resolution |
|---|---|---|---|---|---|
| **All** | `/login` | Credentials input | Inputs start blank; accepts User ID + password | **Working** | Tested: Admin `fs7admin` / `ceo@fs7`, Trainers `trainer_faraz` / `trainer123`. |
| **All** | `/login` | Biometric Quick Login | Prompts local biometric if enrolled | **Working** | Local authentication integration in `login_screen.dart`. |
| **All** | `/change-password` | Update Password | Validates length, saves, clears `must_change_password` | **Working** | `ChangePasswordScreen` navigates to role home upon completion. |
| **Admin** | `/admin` | Home Dashboard | 12 live KPI cards (Today's sessions, inquiries, active clients, ending soon) | **Working** | `AdminHomeScreen` reconciles counts with underlying lists. |
| **Admin** | `/admin` | Notification Bell | Badged unread notification list with direct navigation | **Working** | Modal sheet showing unread alerts (at-risk, follow-ups). |
| **Admin** | `/admin` | Global Search | Search clients and inquiries across the whole gym | **Working** | Search dialog querying client names, phones, inquiries. |
| **Admin** | `/admin/timetable` | Grid View (Week / Day) | Colored slot blocks by trainer and hour with capacity indicators | **Working** | Full timetable grid showing all 3 trainers (Faraz, Suyog, Khalfan). |
| **Admin** | `/admin/timetable` | Free Slot Finder | Search for open slots by trainer, hour, and pattern | **Working** | SlotEngine evaluated search bottom sheet. |
| **Admin** | `/admin/clients` | Client List Screen | Filter by trainer, status, program; search by name/phone | **Working** | Displays all 40 enrolled clients with status badges. |
| **Admin** | `/admin/clients` | Add Client FAB | Opens 10-step Add Client Wizard | **Working** | Fixed GoRouter precedence bug: `/admin/clients/add` mapped before `:id`. |
| **Admin** | `/admin/clients/add` | 10-Step Enrollment Wizard | Details, Emergency, Program, Trainer, Plan, Slot, Payment, Dual Signature, Review | **Working** | Single atomic Server Function creates Client, Sub, Slot, and Consent. |
| **Admin** | `/admin/clients/:id` | Client Profile | 7 Tabs: Overview, Plan & Attendance, Assessments, Docs, Notes, Nutrition, History | **Working** | Full client profile loads by ID with all subscription counters. |
| **Admin** | `/admin/clients/:id` | Popup Menu: Hold / Resume | Pauses subscription; preserves or releases slot per selection | **Working** | Server function `holdSubscription` & `resumeSubscription`. |
| **Admin** | `/admin/clients/:id` | Popup Menu: Reassign Trainer | Reassigns trainer with mandatory handover note in audit log | **Working** | Server function with `trainer_handovers` record. |
| **Admin** | `/admin/clients/:id` | Popup Menu: Deactivate | Deactivates client with mandatory reason; frees timetable slot | **Working** | Server function `deactivateClient`. |
| **Admin** | `/admin/clients/:id` | Baseline Assessment | Form with live VO2max, BMI, body fat, FS-7 score calculation | **Working** | Auto-calculated live values in `AssessmentFormScreen`. |
| **Admin** | `/admin/clients/:id` | Transformation Report | Compares Baseline vs Final with visual change badges and PDF export | **Working** | Full PDF generator via `PdfService` with FS-7 branding. |
| **Admin** | `/admin/inquiries` | Inquiries List | New, Follow-up due today, Overdue, Converted tabs | **Working** | `InquiryListScreen` with status chips and call buttons. |
| **Admin** | `/admin/inquiries/add`| Add Inquiry | Name, phone, source, initial inquiry notes | **Working** | Duplicate phone detection; defaults next follow-up. |
| **Admin** | `/admin/inquiries/:id`| Log Follow-up | Call outcome, notes timeline, next call date scheduler | **Working** | Full timeline history stored in `MockData.inquiryFollowups`. |
| **Admin** | `/admin/inquiries/:id`| Convert to Client | Pre-fills Add Client Wizard with inquiry data | **Working** | Auto-converts inquiry upon client activation and cancels reminders. |
| **Admin** | `/admin/inquiries/analytics`| Source Analytics | Bar charts and conversion rates by marketing channel | **Working** | Fixed GoRouter route order so `analytics` is never swallowed by `:id`. |
| **Admin** | `/admin/more/team` | Team Management | Trainers, Nutritionists, Staff tabs with Add Staff button | **Working** | Full team roster with shifts, weekly off, and status. |
| **Admin** | `/admin/more/staff-attendance`| Daily Staff Attendance | Date strip, Mark All Present, 1-tap Present/Absent/Leave | **Working** | Trainer absence modal prompts 1-tap Gym Cancel or Reassign. |
| **Admin** | `/admin/more/past-clients` | Past Clients Screen | Completed and deactivated clients with 1-tap Renew / Reactivate | **Working** | Pre-fills previous plan and trainer; checks slot with SlotEngine. |
| **Admin** | `/admin/more/settings`| App Settings & Norms | Metric/Imperial toggle, WHO vs Asia-Pacific BMI cut-offs | **Working** | Real-time settings toggles with persistent preference states. |
| **Admin** | `/admin/more/audit-log`| System Audit Trail | Immutable chronological ledger of all database changes | **Working** | Filterable by table and record ID. |
| **Admin** | `/admin/more` | Log Out Action | Confirmation dialog, provider reset, redirect to `/login` | **Working** | Added full Logout button to Admin More screen. |
| **Trainer** | `/trainer` | Today's Sessions | Interactive Date Strip (Prev, Next, Pick Date, Today) | **Working (Fixed B4)** | Changing date reloads due clients matching slot weekday. |
| **Trainer** | `/trainer` | Mark Attendance | 1-tap Present, Absent, Make-up with live session counter updates | **Working (Fixed B4)** | 24-hour edit window enforced: past >24h & future dates locked. |
| **Trainer** | `/trainer` | Sunday Gym Closed | Displays Sunday Gym Closed notice; marking disabled | **Working (Fixed B4)** | Sunday handled explicitly; 0 sessions scheduled. |
| **Trainer** | `/trainer/timetable` | My Timetable | Read-only view of own row only | **Working** | Trainer filter bar hidden; only own slots displayed. |
| **Trainer** | `/trainer/clients` | My Clients List | Shows ONLY assigned clients; NO Add Client FAB visible | **Working (Fixed B3)** | Removed Add Client FAB for non-admin roles; filtered by trainerId. |
| **Trainer** | `/trainer/clients/:id` | Client Profile | Overview, Attendance, Assessments, Notes, Nutrition | **Working** | Admin actions (Deactivate, Hold, Reassign, Audit) hidden. |
| **Trainer** | `/trainer/clients/:id` | Assessments | Can create Baseline/Final assessments for own clients | **Working** | Full form with Rockport 1-mile walk and Navy body fat calculator. |
| **Trainer** | `/trainer/profile` | Trainer Profile Screen | Photo, name, ID, shift hours, weekly off, monthly attendance | **Working (Fixed B2)** | Full `StaffProfileScreen` implemented with read-only monthly log. |
| **Trainer** | `/trainer/profile` | Logout Action | Logout confirmation dialog; cleans caches and returns to `/login` | **Working (Fixed B2)** | Integrated with `authNotifierProvider.logout()`. |
| **Trainer** | Any `/admin/...` | Route Guarding | Direct navigation or back button to admin screens | **Working (Fixed B3/B5)** | Strict router redirect immediately reroutes trainer to `/trainer`. |
| **Nutritionist**| `/nutritionist` | My Clients List | Shows ONLY assigned nutrition clients | **Working** | Routed to `NutritionistHomeScreen`; filtered by `nutritionistId`. |
| **Nutritionist**| `/nutritionist/:id` | Nutrition Screen | Diet notes, BMR & maintenance calories, macro breakdown | **Working** | Harris-Benedict BMR and activity multiplier calculator. |
| **Nutritionist**| `/nutritionist/profile`| Profile Screen | Photo, name, ID, shift hours, monthly attendance, Logout | **Working** | Uses `StaffProfileScreen` with full monthly attendance stats. |
| **Nutritionist**| Any `/admin/...` or `/trainer/...` | Route Guarding | Direct navigation to other roles | **Working** | Router redirects nutritionist back to `/nutritionist`. |
| **All** | Blank-Start Onboarding | Runtime launches completely fresh | Starts with zero clients, zero slots, zero inquiries; only secured admin | **Working** | MockSeed disabled at runtime; all collections initialize to `[]`. |
| **All** | Staff Password Management | Custom password & password change | Staff can log in with custom password set by admin; change password clears must_change_password | **Working** | `MockData.staffPasswords` stores credentials; `changePassword` updates session and router unlocks immediately. |
| **All** | Data Isolation | Multi-client & multi-trainer separation | Subscriptions, attendance, slots, and assessments strictly filtered by client & trainer ID | **Working** | Fixed `clients_provider.dart` and `timetable_provider.dart` fallback queries to filter by ID. |
| **Admin** | Inquiry Timeline | Follow-up history display | Logging follow-up calls updates client timeline immediately | **Working** | `inquiryFollowupsProvider` queries `MockData.inquiryFollowups` by `inquiryId`. |
| **Admin** | Dashboard Reconciliation | Stats match list views exactly | Conversion rate, ending plans, scheduled vs marked sessions derived dynamically | **Working** | `adminDashboardProvider` computes metrics from live memory collections. |


