-- ====================================================================
-- FS-7 Gym Management App - Complete PostgreSQL Schema & RLS Policies
-- ====================================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. USERS & ROLES
CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    supabase_uid UUID UNIQUE,
    supabase_email TEXT UNIQUE,
    role TEXT NOT NULL CHECK (role IN ('admin', 'trainer', 'nutritionist', 'staff')),
    name TEXT NOT NULL,
    phone TEXT,
    email TEXT,
    photo_url TEXT,
    user_id TEXT NOT NULL UNIQUE,
    active BOOLEAN NOT NULL DEFAULT true,
    shift_start TEXT DEFAULT '06:00',
    shift_end TEXT DEFAULT '14:00',
    weekly_off INT DEFAULT 7,
    grace_minutes INT DEFAULT 10,
    must_change_password BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. PLANS (No prices in the app)
CREATE TABLE IF NOT EXISTS public.plans (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    months INT NOT NULL,
    sessions_per_month INT NOT NULL,
    active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Seed Default Plans
INSERT INTO public.plans (id, name, months, sessions_per_month) VALUES
('plan_3m_12', '3 Months, 12 sessions', 3, 12),
('plan_3m_20', '3 Months, 20 sessions', 3, 20),
('plan_6m_12', '6 Months, 12 sessions', 6, 12),
('plan_6m_20', '6 Months, 20 sessions', 6, 20)
ON CONFLICT (id) DO NOTHING;

-- 3. INQUIRY SOURCES
CREATE TABLE IF NOT EXISTS public.inquiry_sources (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    active BOOLEAN NOT NULL DEFAULT true
);

INSERT INTO public.inquiry_sources (id, name) VALUES
('walk_in', 'Walk-in'),
('instagram', 'Instagram'),
('facebook', 'Facebook'),
('google', 'Google'),
('website', 'Website'),
('justdial', 'Justdial'),
('hoarding', 'Hoarding or board'),
('flyer', 'Poster or flyer'),
('referral', 'Referral'),
('other', 'Other')
ON CONFLICT (id) DO NOTHING;

-- 4. INQUIRIES
CREATE TABLE IF NOT EXISTS public.inquiries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    phone TEXT NOT NULL,
    source_id TEXT NOT NULL,
    reference_name TEXT,
    referred_by_client_id UUID,
    inquiry_date DATE NOT NULL DEFAULT CURRENT_DATE,
    last_followup_date DATE NOT NULL DEFAULT CURRENT_DATE,
    next_followup_date DATE NOT NULL,
    next_followup_time TEXT,
    interested_in TEXT,
    preferred_time TEXT,
    preferred_pattern TEXT,
    status TEXT NOT NULL DEFAULT 'new' CHECK (status IN ('new', 'follow_up', 'converted', 'not_interested', 'lost')),
    lost_reason TEXT,
    converted_client_id UUID,
    archived BOOLEAN NOT NULL DEFAULT false,
    created_by UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 5. INQUIRY FOLLOWUPS
CREATE TABLE IF NOT EXISTS public.inquiry_followups (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    inquiry_id UUID NOT NULL REFERENCES public.inquiries(id) ON DELETE CASCADE,
    followup_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    outcome TEXT NOT NULL,
    remarks TEXT,
    next_followup_date DATE,
    next_followup_time TEXT,
    logged_by UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 6. CLIENTS
CREATE TABLE IF NOT EXISTS public.clients (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    address TEXT,
    dob DATE NOT NULL,
    gender TEXT NOT NULL CHECK (gender IN ('Male', 'Female')),
    phone_primary TEXT NOT NULL,
    phone_secondary TEXT,
    email TEXT,
    photo_url TEXT,
    program_type TEXT NOT NULL,
    payment_method TEXT NOT NULL,
    trainer_id UUID NOT NULL REFERENCES public.users(id),
    nutritionist_id UUID REFERENCES public.users(id),
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'extended', 'completed', 'deactivated', 'hold')),
    source_inquiry_id UUID REFERENCES public.inquiries(id),
    emergency_first_name TEXT NOT NULL,
    emergency_last_name TEXT NOT NULL,
    emergency_address TEXT,
    emergency_phone TEXT NOT NULL,
    archived BOOLEAN NOT NULL DEFAULT false,
    created_by UUID NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 7. SUBSCRIPTIONS
CREATE TABLE IF NOT EXISTS public.subscriptions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    client_id UUID NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
    plan_id TEXT NOT NULL REFERENCES public.plans(id),
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    extension_end_date DATE,
    total_sessions INT NOT NULL,
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'extended', 'completed', 'deactivated', 'hold')),
    hold_from DATE,
    hold_to DATE,
    deactivation_reason TEXT,
    renewed_from_id UUID,
    created_by UUID NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 8. SLOTS (Timetable grid bookings)
CREATE TABLE IF NOT EXISTS public.slots (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    subscription_id UUID NOT NULL REFERENCES public.subscriptions(id) ON DELETE CASCADE,
    client_id UUID NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
    trainer_id UUID NOT NULL REFERENCES public.users(id),
    hour_start INT NOT NULL CHECK (hour_start BETWEEN 5 AND 22),
    pattern TEXT NOT NULL CHECK (pattern IN ('A5', 'M1', 'M2', 'T1', 'T2')),
    valid_from DATE NOT NULL,
    valid_to DATE NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 9. ATTENDANCE (Session marking)
CREATE TABLE IF NOT EXISTS public.attendance (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    subscription_id UUID NOT NULL REFERENCES public.subscriptions(id) ON DELETE CASCADE,
    client_id UUID NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('present', 'absent', 'makeup', 'cancelled')),
    marked_by UUID NOT NULL,
    note TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_subscription_session_date UNIQUE (subscription_id, date)
);

-- 10. ASSESSMENTS
CREATE TABLE IF NOT EXISTS public.assessments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    client_id UUID NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
    subscription_id UUID NOT NULL REFERENCES public.subscriptions(id) ON DELETE CASCADE,
    type TEXT NOT NULL CHECK (type IN ('baseline', 'final', 'checkpoint')),
    test_date DATE NOT NULL,
    weight_kg NUMERIC(5,2),
    height_cm NUMERIC(5,2),
    goal TEXT,
    resting_heart_rate INT,
    systolic INT,
    diastolic INT,
    neck NUMERIC(5,2),
    chest NUMERIC(5,2),
    upper_abdomen NUMERIC(5,2),
    waist_widest NUMERIC(5,2),
    waist_narrowest NUMERIC(5,2),
    hip NUMERIC(5,2),
    arm_left NUMERIC(5,2),
    arm_right NUMERIC(5,2),
    thigh_left NUMERIC(5,2),
    thigh_right NUMERIC(5,2),
    calf_left NUMERIC(5,2),
    calf_right NUMERIC(5,2),
    rockport_time TEXT,
    rockport_pulse INT,
    recovery_heart_rate INT,
    pushups_count INT,
    squats_count INT,
    pullups_count INT,
    pullups_time_seconds INT,
    quadriceps_flexibility TEXT,
    hamstrings_flexibility TEXT,
    hip_flexors_flexibility TEXT,
    shoulder_reach_flexibility TEXT,
    trainer_remarks TEXT,
    fs7_score NUMERIC(5,2),
    calculated_json JSONB,
    created_by UUID NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 11. DOCUMENTS & REPORTS
CREATE TABLE IF NOT EXISTS public.documents (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    client_id UUID NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
    assessment_id UUID REFERENCES public.assessments(id) ON DELETE SET NULL,
    kind TEXT NOT NULL CHECK (kind IN ('bca', 'blood', 'consent', 'diet', 'photo', 'other')),
    file_url TEXT NOT NULL,
    doc_date DATE,
    notes TEXT,
    uploaded_by UUID NOT NULL,
    archived BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 12. STAFF ATTENDANCE
CREATE TABLE IF NOT EXISTS public.staff_attendance (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('present', 'absent', 'half_day', 'leave', 'week_off', 'holiday')),
    in_time TEXT,
    out_time TEXT,
    late_flag BOOLEAN NOT NULL DEFAULT false,
    note TEXT,
    marked_by UUID NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_user_staff_attendance_date UNIQUE (user_id, date)
);

-- 13. AUDIT LOG
CREATE TABLE IF NOT EXISTS public.audit_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    actor_id UUID NOT NULL,
    "table" TEXT NOT NULL,
    record_id TEXT NOT NULL,
    field TEXT NOT NULL,
    old_value TEXT,
    new_value TEXT,
    at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ====================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ====================================================================

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.slots ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assessments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inquiries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff_attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;

-- Helper function to get current user role
CREATE OR REPLACE FUNCTION public.current_app_role()
RETURNS TEXT AS $$
    SELECT role FROM public.users WHERE supabase_uid = auth.uid() LIMIT 1;
$$ LANGUAGE sql SECURITY DEFINER;

-- Helper function to get current user id
CREATE OR REPLACE FUNCTION public.current_app_user_id()
RETURNS UUID AS $$
    SELECT id FROM public.users WHERE supabase_uid = auth.uid() LIMIT 1;
$$ LANGUAGE sql SECURITY DEFINER;

-- Admin has full access to everything
CREATE POLICY admin_full_access_users ON public.users FOR ALL USING (public.current_app_role() = 'admin');
CREATE POLICY admin_full_access_clients ON public.clients FOR ALL USING (public.current_app_role() = 'admin');
CREATE POLICY admin_full_access_subs ON public.subscriptions FOR ALL USING (public.current_app_role() = 'admin');
CREATE POLICY admin_full_access_slots ON public.slots FOR ALL USING (public.current_app_role() = 'admin');
CREATE POLICY admin_full_access_att ON public.attendance FOR ALL USING (public.current_app_role() = 'admin');
CREATE POLICY admin_full_access_assess ON public.assessments FOR ALL USING (public.current_app_role() = 'admin');
CREATE POLICY admin_full_access_docs ON public.documents FOR ALL USING (public.current_app_role() = 'admin');
CREATE POLICY admin_full_access_inq ON public.inquiries FOR ALL USING (public.current_app_role() = 'admin');
CREATE POLICY admin_full_access_staff_att ON public.staff_attendance FOR ALL USING (public.current_app_role() = 'admin');
CREATE POLICY admin_full_access_audit ON public.audit_log FOR ALL USING (public.current_app_role() = 'admin');

-- Trainer Access: Only own assigned clients
CREATE POLICY trainer_select_clients ON public.clients FOR SELECT
USING (public.current_app_role() = 'trainer' AND trainer_id = public.current_app_user_id());

CREATE POLICY trainer_select_slots ON public.slots FOR SELECT
USING (public.current_app_role() = 'trainer' AND trainer_id = public.current_app_user_id());

CREATE POLICY trainer_attendance ON public.attendance FOR ALL
USING (
    public.current_app_role() = 'trainer' AND 
    client_id IN (SELECT id FROM public.clients WHERE trainer_id = public.current_app_user_id())
);

CREATE POLICY trainer_assessments ON public.assessments FOR ALL
USING (
    public.current_app_role() = 'trainer' AND 
    client_id IN (SELECT id FROM public.clients WHERE trainer_id = public.current_app_user_id())
);

-- Nutritionist Access: Only assigned clients
CREATE POLICY nutritionist_select_clients ON public.clients FOR SELECT
USING (public.current_app_role() = 'nutritionist' AND nutritionist_id = public.current_app_user_id());

CREATE POLICY nutritionist_assessments ON public.assessments FOR SELECT
USING (
    public.current_app_role() = 'nutritionist' AND 
    client_id IN (SELECT id FROM public.clients WHERE nutritionist_id = public.current_app_user_id())
);

-- ====================================================================
-- SCHEDULED JOB: NIGHTLY STATUS TRANSITIONS (Section 14 & 16)
-- Automatically extends incomplete plans by 14 days once,
-- then deactivates expired extensions and frees timetable slots.
-- ====================================================================

CREATE OR REPLACE FUNCTION public.apply_status_transitions()
RETURNS void AS $$
BEGIN
    -- 1. Active plans that passed end_date with sessions remaining -> Extended by 14 days
    UPDATE public.subscriptions
    SET status = 'extended',
        extension_end_date = end_date + INTERVAL '14 days',
        updated_at = NOW()
    WHERE status = 'active'
      AND end_date < CURRENT_DATE
      AND extension_end_date IS NULL;

    -- 2. Extended plans that passed extension_end_date -> Deactivated
    UPDATE public.subscriptions
    SET status = 'deactivated',
        deactivation_reason = 'Plan extension period expired with incomplete sessions',
        updated_at = NOW()
    WHERE status = 'extended'
      AND extension_end_date < CURRENT_DATE;

    -- Update client table status to match subscription
    UPDATE public.clients c
    SET status = s.status,
        updated_at = NOW()
    FROM public.subscriptions s
    WHERE s.client_id = c.id
      AND c.status != s.status;

    -- 3. Delete / Free slots for deactivated or completed subscriptions
    DELETE FROM public.slots
    WHERE subscription_id IN (
        SELECT id FROM public.subscriptions WHERE status IN ('deactivated', 'completed')
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

