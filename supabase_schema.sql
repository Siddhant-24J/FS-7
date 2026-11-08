-- ==============================================================================
-- FS-7 GYM APP — COMPLETE SUPABASE POSTGRESQL DATABASE SCHEMA
-- Run this entire script in your Supabase SQL Editor (Dashboard > SQL Editor)
-- ==============================================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. USERS & STAFF TABLE
CREATE TABLE IF NOT EXISTS public.users (
    id TEXT PRIMARY KEY DEFAULT ('staff-' || extract(epoch from now())::bigint || '-' || substr(md5(random()::text), 1, 6)),
    user_id TEXT UNIQUE NOT NULL, -- Login username (e.g. fs7admin, faraz, rahul)
    role TEXT NOT NULL CHECK (role IN ('admin', 'trainer', 'nutritionist', 'staff')),
    name TEXT NOT NULL,
    phone TEXT,
    email TEXT,
    photo_url TEXT,
    active BOOLEAN DEFAULT true,
    shift_start TEXT DEFAULT '06:00',
    shift_end TEXT DEFAULT '22:00',
    weekly_off INTEGER DEFAULT 7, -- 1=Mon...7=Sun
    grace_minutes INTEGER DEFAULT 10,
    must_change_password BOOLEAN DEFAULT true,
    password_hash TEXT DEFAULT 'ceo@fs7', -- In-memory/simple credential verify
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 2. CLIENTS TABLE
CREATE TABLE IF NOT EXISTS public.clients (
    id TEXT PRIMARY KEY DEFAULT ('client-' || extract(epoch from now())::bigint || '-' || substr(md5(random()::text), 1, 6)),
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    address TEXT,
    dob DATE NOT NULL DEFAULT '1995-01-01',
    gender TEXT NOT NULL DEFAULT 'Male',
    phone_primary TEXT UNIQUE NOT NULL,
    phone_secondary TEXT,
    email TEXT,
    photo_url TEXT,
    program_type TEXT NOT NULL DEFAULT 'Personal Training',
    payment_method TEXT NOT NULL DEFAULT 'Online',
    trainer_id TEXT REFERENCES public.users(id) ON DELETE SET NULL,
    nutritionist_id TEXT REFERENCES public.users(id) ON DELETE SET NULL,
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'extended', 'completed', 'deactivated', 'hold')),
    source_inquiry_id TEXT,
    emergency_first_name TEXT DEFAULT 'Emergency',
    emergency_last_name TEXT DEFAULT 'Contact',
    emergency_address TEXT,
    emergency_phone TEXT,
    consecutive_absences INTEGER DEFAULT 0,
    archived BOOLEAN DEFAULT false,
    created_by TEXT DEFAULT 'admin-01',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 3. PLANS TABLE
CREATE TABLE IF NOT EXISTS public.plans (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    months INTEGER NOT NULL,
    total_sessions INTEGER NOT NULL,
    price NUMERIC DEFAULT 0,
    active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 4. SUBSCRIPTIONS TABLE
CREATE TABLE IF NOT EXISTS public.subscriptions (
    id TEXT PRIMARY KEY DEFAULT ('sub-' || extract(epoch from now())::bigint || '-' || substr(md5(random()::text), 1, 6)),
    client_id TEXT NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
    plan_id TEXT NOT NULL REFERENCES public.plans(id),
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    extension_end_date DATE,
    total_sessions INTEGER NOT NULL,
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'extended', 'completed', 'deactivated', 'hold')),
    baseline_due_date DATE,
    final_assessment_due BOOLEAN DEFAULT false,
    renewed_from_id TEXT,
    hold_from DATE,
    hold_to DATE,
    created_by TEXT DEFAULT 'admin-01',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 5. TIMETABLE SLOTS TABLE
CREATE TABLE IF NOT EXISTS public.slots (
    id TEXT PRIMARY KEY DEFAULT ('slot-' || extract(epoch from now())::bigint || '-' || substr(md5(random()::text), 1, 6)),
    subscription_id TEXT NOT NULL REFERENCES public.subscriptions(id) ON DELETE CASCADE,
    client_id TEXT NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
    trainer_id TEXT NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    hour_start INTEGER NOT NULL CHECK (hour_start BETWEEN 6 AND 22),
    pattern TEXT NOT NULL CHECK (pattern IN ('A5', 'M1', 'M2', 'T1', 'T2')),
    valid_from DATE NOT NULL,
    valid_to DATE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 6. ATTENDANCE TABLE
CREATE TABLE IF NOT EXISTS public.attendance (
    id TEXT PRIMARY KEY DEFAULT ('att-' || extract(epoch from now())::bigint || '-' || substr(md5(random()::text), 1, 6)),
    subscription_id TEXT NOT NULL REFERENCES public.subscriptions(id) ON DELETE CASCADE,
    client_id TEXT NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('present', 'absent', 'makeup', 'cancelled')),
    marked_by TEXT NOT NULL,
    note TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    CONSTRAINT unique_client_attendance_per_day UNIQUE (subscription_id, date)
);

-- 7. STAFF ATTENDANCE TABLE
CREATE TABLE IF NOT EXISTS public.staff_attendance (
    id TEXT PRIMARY KEY DEFAULT ('sa-' || extract(epoch from now())::bigint || '-' || substr(md5(random()::text), 1, 6)),
    user_id TEXT NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('present', 'absent', 'half_day', 'leave', 'week_off', 'holiday')),
    in_time TEXT,
    out_time TEXT,
    late_flag BOOLEAN DEFAULT false,
    note TEXT,
    marked_by TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    CONSTRAINT unique_staff_attendance_per_day UNIQUE (user_id, date)
);

-- 8. ASSESSMENTS TABLE
CREATE TABLE IF NOT EXISTS public.assessments (
    id TEXT PRIMARY KEY DEFAULT ('ass-' || extract(epoch from now())::bigint || '-' || substr(md5(random()::text), 1, 6)),
    client_id TEXT NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
    subscription_id TEXT NOT NULL REFERENCES public.subscriptions(id) ON DELETE CASCADE,
    type TEXT NOT NULL CHECK (type IN ('baseline', 'checkpoint', 'final')),
    test_date DATE NOT NULL DEFAULT CURRENT_DATE,
    conducted_by TEXT NOT NULL,
    weight_kg NUMERIC,
    height_cm NUMERIC,
    body_fat_percent NUMERIC,
    muscle_mass_kg NUMERIC,
    visceral_fat NUMERIC,
    systolic_bp INTEGER,
    diastolic_bp INTEGER,
    resting_hr INTEGER,
    post_hr INTEGER,
    calculated_vo2max NUMERIC,
    pushups INTEGER,
    plank_seconds INTEGER,
    sit_reach_cm NUMERIC,
    fs7_score NUMERIC,
    calculated_json JSONB DEFAULT '{}'::jsonb,
    remarks TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 9. INQUIRIES & LEADS TABLE
CREATE TABLE IF NOT EXISTS public.inquiries (
    id TEXT PRIMARY KEY DEFAULT ('inq-' || extract(epoch from now())::bigint || '-' || substr(md5(random()::text), 1, 6)),
    full_name TEXT NOT NULL,
    phone TEXT NOT NULL,
    email TEXT,
    program_interested TEXT NOT NULL DEFAULT 'Personal Training',
    fitness_goal TEXT,
    status TEXT NOT NULL DEFAULT 'new' CHECK (status IN ('new', 'follow_up', 'converted', 'not_interested', 'lost')),
    source TEXT NOT NULL DEFAULT 'Walk-in',
    inquiry_date DATE NOT NULL DEFAULT CURRENT_DATE,
    last_followup_date DATE,
    next_followup_date DATE,
    next_followup_time TEXT,
    converted_client_id TEXT REFERENCES public.clients(id) ON DELETE SET NULL,
    lost_reason TEXT,
    notes TEXT,
    created_by TEXT DEFAULT 'admin-01',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 10. INQUIRY FOLLOWUPS TABLE
CREATE TABLE IF NOT EXISTS public.inquiry_followups (
    id TEXT PRIMARY KEY DEFAULT ('fup-' || extract(epoch from now())::bigint || '-' || substr(md5(random()::text), 1, 6)),
    inquiry_id TEXT NOT NULL REFERENCES public.inquiries(id) ON DELETE CASCADE,
    followup_date TIMESTAMPTZ NOT NULL DEFAULT now(),
    outcome TEXT NOT NULL,
    next_followup_date DATE,
    next_followup_time TEXT,
    notes TEXT,
    logged_by TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 11. NOTIFICATIONS TABLE
CREATE TABLE IF NOT EXISTS public.notifications (
    id TEXT PRIMARY KEY DEFAULT ('notif-' || extract(epoch from now())::bigint || '-' || substr(md5(random()::text), 1, 6)),
    user_id TEXT NOT NULL,
    type TEXT NOT NULL,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    payload JSONB DEFAULT '{}'::jsonb,
    is_read BOOLEAN DEFAULT false,
    cancelled BOOLEAN DEFAULT false,
    scheduled_for TIMESTAMPTZ DEFAULT now(),
    sent_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 12. AUDIT LOG TABLE
CREATE TABLE IF NOT EXISTS public.audit_log (
    id TEXT PRIMARY KEY DEFAULT ('aud-' || extract(epoch from now())::bigint || '-' || substr(md5(random()::text), 1, 6)),
    actor_id TEXT NOT NULL,
    table_name TEXT NOT NULL,
    record_id TEXT NOT NULL,
    field TEXT,
    old_value TEXT,
    new_value TEXT,
    timestamp TIMESTAMPTZ DEFAULT now()
);

-- 13. CONSENTS TABLE
CREATE TABLE IF NOT EXISTS public.consents (
    id TEXT PRIMARY KEY DEFAULT ('consent-' || extract(epoch from now())::bigint || '-' || substr(md5(random()::text), 1, 6)),
    client_id TEXT NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
    consent_text TEXT NOT NULL,
    member_signature_url TEXT,
    trainer_signature_url TEXT,
    signed_at TIMESTAMPTZ DEFAULT now(),
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 14. DOCUMENTS TABLE
CREATE TABLE IF NOT EXISTS public.documents (
    id TEXT PRIMARY KEY DEFAULT ('doc-' || extract(epoch from now())::bigint || '-' || substr(md5(random()::text), 1, 6)),
    client_id TEXT NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
    assessment_id TEXT REFERENCES public.assessments(id) ON DELETE SET NULL,
    kind TEXT NOT NULL, -- bca, blood, consent, report, photo
    file_url TEXT NOT NULL,
    file_name TEXT,
    doc_date DATE DEFAULT CURRENT_DATE,
    notes TEXT,
    uploaded_by TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 15. NOTES TABLE
CREATE TABLE IF NOT EXISTS public.notes (
    id TEXT PRIMARY KEY DEFAULT ('note-' || extract(epoch from now())::bigint || '-' || substr(md5(random()::text), 1, 6)),
    client_id TEXT NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
    author_id TEXT NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    visibility TEXT NOT NULL DEFAULT 'shared' CHECK (visibility IN ('shared', 'private')),
    body TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 16. SESSION OVERRIDES TABLE (Workflow I)
CREATE TABLE IF NOT EXISTS public.session_overrides (
    id TEXT PRIMARY KEY DEFAULT ('so-' || extract(epoch from now())::bigint || '-' || substr(md5(random()::text), 1, 6)),
    client_id TEXT NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    trainer_id TEXT NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    hour_start INTEGER NOT NULL,
    created_by TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 17. TRAINER HANDOVERS TABLE (Workflow J)
CREATE TABLE IF NOT EXISTS public.trainer_handovers (
    id TEXT PRIMARY KEY DEFAULT ('th-' || extract(epoch from now())::bigint || '-' || substr(md5(random()::text), 1, 6)),
    client_id TEXT NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
    from_trainer_id TEXT NOT NULL,
    to_trainer_id TEXT NOT NULL,
    note TEXT NOT NULL,
    at TIMESTAMPTZ DEFAULT now()
);

-- 18. SETTINGS TABLE
CREATE TABLE IF NOT EXISTS public.settings (
    key TEXT PRIMARY KEY,
    value JSONB NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- ==============================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES — ALLOW CONNECTED APP READ & WRITE
-- ==============================================================================

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.slots ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff_attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assessments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inquiries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inquiry_followups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.consents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.session_overrides ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trainer_handovers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.settings ENABLE ROW LEVEL SECURITY;

-- Allow Anon & Authenticated full read/write for the app:
DO $$
DECLARE
    tbl text;
BEGIN
    FOR tbl IN 
        SELECT tablename FROM pg_tables WHERE schemaname = 'public'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS "Allow all app access" ON public.%I', tbl);
        EXECUTE format('CREATE POLICY "Allow all app access" ON public.%I FOR ALL USING (true) WITH CHECK (true)', tbl);
    END LOOP;
END $$;

-- ==============================================================================
-- SEED INITIAL FOUNDATIONAL DATA
-- ==============================================================================

-- Seed Admin
INSERT INTO public.users (id, user_id, role, name, phone, email, active, password_hash)
VALUES ('admin-01', 'fs7admin', 'admin', 'Director (Admin)', '+91 99999 00001', 'admin@fs7gym.com', true, 'ceo@fs7')
ON CONFLICT (user_id) DO UPDATE SET active = true, role = 'admin';

-- Seed Plans (Section 7.2)
INSERT INTO public.plans (id, name, months, total_sessions, price)
VALUES 
    ('plan_3m_12', '3 Months (12 Sessions)', 3, 12, 15000),
    ('plan_6m_24', '6 Months (24 Sessions)', 6, 24, 28000),
    ('plan_12m_48', '12 Months (48 Sessions)', 12, 48, 50000)
ON CONFLICT (id) DO NOTHING;

-- Seed Default Settings
INSERT INTO public.settings (key, value)
VALUES 
    ('general', '{"gym_name": "FS-7 Fitness", "currency": "INR", "timezone": "Asia/Kolkata"}'::jsonb),
    ('rules', '{"grace_minutes": 10, "max_seats_per_slot": 2, "extension_days": 14}'::jsonb)
ON CONFLICT (key) DO NOTHING;

-- Complete!

