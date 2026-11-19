-- shikarisøkesearch: corrected initial database schema (v2)
-- Intended for a NEW, EMPTY Supabase project. Do not run over existing schema.
-- Research only: no external-contact, offer, payment or execution capability.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE TYPE public.membership_role AS ENUM ('owner','admin','member');
CREATE TYPE public.property_stage AS ENUM ('new','researching','underwriting','review_required','approved_for_next_step','archived');
CREATE TYPE public.finding_kind AS ENUM ('verified_fact','inference','estimate','unknown');
CREATE TYPE public.research_status AS ENUM ('queued','running','completed','needs_review','failed');
CREATE TYPE public.approval_action AS ENUM ('contact_person','send_offer','sign_document','submit_document','pay_money','initiate_transaction');
CREATE TYPE public.approval_status AS ENUM ('pending','approved','rejected','expired','executed');

CREATE TABLE public.organizations (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 name text NOT NULL CHECK (length(btrim(name)) BETWEEN 1 AND 150),
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.organization_members (
 organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
 user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 role public.membership_role NOT NULL DEFAULT 'member',
 created_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY (organization_id,user_id)
);
CREATE TABLE public.subscriptions (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
 provider text NOT NULL DEFAULT 'stripe',
 provider_customer_id text,
 provider_subscription_id text UNIQUE,
 plan_key text NOT NULL DEFAULT 'free',
 status text NOT NULL DEFAULT 'incomplete',
 current_period_end timestamptz,
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.properties (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
 state_code char(2) NOT NULL DEFAULT 'WA',
 county text, situs_address text, city text, postal_code text,
 parcel_number text, legal_description text, property_type text,
 latitude double precision, longitude double precision,
 stage public.property_stage NOT NULL DEFAULT 'new',
 source_first_seen text,
 overall_confidence numeric(4,3) CHECK (overall_confidence BETWEEN 0 AND 1),
 created_by uuid REFERENCES auth.users(id),
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE (organization_id,state_code,parcel_number),
 UNIQUE (id,organization_id)
);
CREATE TABLE public.property_sources (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 property_id uuid NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
 source_name text NOT NULL, source_url text NOT NULL, source_type text NOT NULL,
 published_at timestamptz, retrieved_at timestamptz NOT NULL DEFAULT now(),
 source_record_id text, content_hash text, notes text,
 created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE (id,property_id)
);
CREATE TABLE public.research_runs (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 property_id uuid NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
 agent_key text NOT NULL, agent_label text NOT NULL,
 status public.research_status NOT NULL DEFAULT 'queued',
 started_at timestamptz, completed_at timestamptz, summary text,
 confidence numeric(4,3) CHECK (confidence BETWEEN 0 AND 1),
 error_message text, created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE (id,property_id)
);
CREATE TABLE public.property_findings (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 property_id uuid NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
 research_run_id uuid, finding_kind public.finding_kind NOT NULL,
 category text NOT NULL, title text NOT NULL, detail text NOT NULL,
 confidence numeric(4,3) CHECK (confidence BETWEEN 0 AND 1),
 source_id uuid, needs_human_verification boolean NOT NULL DEFAULT true,
 created_at timestamptz NOT NULL DEFAULT now(),
 FOREIGN KEY (research_run_id,property_id) REFERENCES public.research_runs(id,property_id),
 FOREIGN KEY (source_id,property_id) REFERENCES public.property_sources(id,property_id)
);
CREATE TABLE public.property_responses (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 property_id uuid NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
 response_version integer NOT NULL DEFAULT 1 CHECK (response_version > 0),
 headline text NOT NULL, executive_summary text NOT NULL,
 verified_facts jsonb NOT NULL DEFAULT '[]'::jsonb,
 inferences jsonb NOT NULL DEFAULT '[]'::jsonb,
 estimates jsonb NOT NULL DEFAULT '[]'::jsonb,
 unresolved_questions jsonb NOT NULL DEFAULT '[]'::jsonb,
 risk_flags jsonb NOT NULL DEFAULT '[]'::jsonb,
 recommended_next_steps jsonb NOT NULL DEFAULT '[]'::jsonb,
 generated_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE (property_id,response_version)
);
CREATE TABLE public.underwriting_scenarios (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 property_id uuid NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
 strategy text NOT NULL CHECK (strategy IN ('wholesale','rental','flip','creative_finance')),
 inputs jsonb NOT NULL DEFAULT '{}'::jsonb,
 outputs jsonb NOT NULL DEFAULT '{}'::jsonb,
 assumptions jsonb NOT NULL DEFAULT '[]'::jsonb,
 missing_inputs jsonb NOT NULL DEFAULT '[]'::jsonb,
 confidence numeric(4,3) CHECK (confidence BETWEEN 0 AND 1),
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.research_jobs (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
 property_id uuid,
 state_code char(2) NOT NULL DEFAULT 'WA',
 county text, category text, keywords text,
 status public.research_status NOT NULL DEFAULT 'queued',
 scheduled_at timestamptz, started_at timestamptz, completed_at timestamptz,
 result_count integer NOT NULL DEFAULT 0 CHECK (result_count >= 0),
 created_at timestamptz NOT NULL DEFAULT now(),
 FOREIGN KEY (property_id,organization_id) REFERENCES public.properties(id,organization_id)
);
CREATE TABLE public.approval_requests (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
 property_id uuid,
 action public.approval_action NOT NULL,
 status public.approval_status NOT NULL DEFAULT 'pending',
 description text NOT NULL,
 requested_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
 requested_by uuid REFERENCES auth.users(id),
 decided_by uuid REFERENCES auth.users(id),
 decided_at timestamptz, expires_at timestamptz,
 created_at timestamptz NOT NULL DEFAULT now(),
 FOREIGN KEY (property_id,organization_id) REFERENCES public.properties(id,organization_id)
);
CREATE TABLE public.audit_log (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
 actor_user_id uuid REFERENCES auth.users(id),
 property_id uuid,
 event_type text NOT NULL,
 event_detail jsonb NOT NULL DEFAULT '{}'::jsonb,
 created_at timestamptz NOT NULL DEFAULT now(),
 FOREIGN KEY (property_id,organization_id) REFERENCES public.properties(id,organization_id)
);

-- Hardened helper: not user-writable, fixed search_path and explicit privileges.
CREATE FUNCTION public.is_org_member(org_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = '' AS $$
 SELECT EXISTS (SELECT 1 FROM public.organization_members m
 WHERE m.organization_id = org_id AND m.user_id = (SELECT auth.uid()));
$$;
CREATE FUNCTION public.is_org_manager(org_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = '' AS $$
 SELECT EXISTS (SELECT 1 FROM public.organization_members m
 WHERE m.organization_id = org_id AND m.user_id = (SELECT auth.uid())
 AND m.role IN ('owner','admin'));
$$;
REVOKE ALL ON FUNCTION public.is_org_member(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.is_org_manager(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_org_member(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_org_manager(uuid) TO authenticated;

-- Safe organization bootstrap: the signed-in creator becomes the owner atomically.
-- No general client INSERT/UPDATE/DELETE policies on memberships or organizations.
CREATE FUNCTION public.create_my_organization(org_name text)
RETURNS uuid LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = '' AS $$
DECLARE new_org_id uuid;
BEGIN
 IF (SELECT auth.uid()) IS NULL THEN
   RAISE EXCEPTION 'Authentication required';
 END IF;
 IF org_name IS NULL OR length(btrim(org_name)) NOT BETWEEN 1 AND 150 THEN
   RAISE EXCEPTION 'Organization name must be 1 to 150 characters';
 END IF;
 INSERT INTO public.organizations(name) VALUES (btrim(org_name)) RETURNING id INTO new_org_id;
 INSERT INTO public.organization_members(organization_id,user_id,role)
 VALUES (new_org_id,(SELECT auth.uid()),'owner');
 RETURN new_org_id;
END;
$$;
REVOKE ALL ON FUNCTION public.create_my_organization(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_my_organization(text) TO authenticated;

ALTER TABLE public.organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.organization_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.properties ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.property_sources ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.research_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.property_findings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.property_responses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.underwriting_scenarios ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.research_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.approval_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;

-- Authenticated tenant-scoped read access; no anonymous access.
CREATE POLICY org_read ON public.organizations FOR SELECT TO authenticated
 USING (public.is_org_member(id));
CREATE POLICY members_read ON public.organization_members FOR SELECT TO authenticated
 USING (public.is_org_member(organization_id));
CREATE POLICY subscriptions_read ON public.subscriptions FOR SELECT TO authenticated
 USING (public.is_org_member(organization_id));
CREATE POLICY properties_read ON public.properties FOR SELECT TO authenticated
 USING (public.is_org_member(organization_id));
CREATE POLICY sources_read ON public.property_sources FOR SELECT TO authenticated
 USING (EXISTS (SELECT 1 FROM public.properties p WHERE p.id = property_id AND public.is_org_member(p.organization_id)));
CREATE POLICY runs_read ON public.research_runs FOR SELECT TO authenticated
 USING (EXISTS (SELECT 1 FROM public.properties p WHERE p.id = property_id AND public.is_org_member(p.organization_id)));
CREATE POLICY findings_read ON public.property_findings FOR SELECT TO authenticated
 USING (EXISTS (SELECT 1 FROM public.properties p WHERE p.id = property_id AND public.is_org_member(p.organization_id)));
CREATE POLICY responses_read ON public.property_responses FOR SELECT TO authenticated
 USING (EXISTS (SELECT 1 FROM public.properties p WHERE p.id = property_id AND public.is_org_member(p.organization_id)));
CREATE POLICY underwriting_read ON public.underwriting_scenarios FOR SELECT TO authenticated
 USING (EXISTS (SELECT 1 FROM public.properties p WHERE p.id = property_id AND public.is_org_member(p.organization_id)));
CREATE POLICY jobs_read ON public.research_jobs FOR SELECT TO authenticated
 USING (public.is_org_member(organization_id));
CREATE POLICY approvals_read ON public.approval_requests FOR SELECT TO authenticated
 USING (public.is_org_member(organization_id));
CREATE POLICY audit_read ON public.audit_log FOR SELECT TO authenticated
 USING (public.is_org_member(organization_id));

-- Property management limited to owner/admin. The owning org cannot be reassigned.
CREATE POLICY properties_insert ON public.properties FOR INSERT TO authenticated
 WITH CHECK (public.is_org_manager(organization_id) AND created_by = (SELECT auth.uid()));
-- Keep properties immutable from direct clients after creation until audited server endpoints exist.
-- This prevents reassignment, stage manipulation, and forged verified research.
-- Future updates must use audited, authorization-checked server functions.

-- Research jobs, sources, findings, runs, responses, scenarios and approvals are
-- intentionally read-only to browser clients. Server workers will need separate
-- tenant authorization, validation, audit and quota controls before being enabled.
-- In particular, NO client can approve/execute an action or forge an audit event.
-- Approval records do not authorize any real-world action by themselves.

CREATE INDEX idx_org_members_user ON public.organization_members(user_id);
CREATE INDEX idx_properties_org ON public.properties(organization_id);
CREATE INDEX idx_sources_property ON public.property_sources(property_id);
CREATE INDEX idx_runs_property ON public.research_runs(property_id);
CREATE INDEX idx_findings_property ON public.property_findings(property_id);
CREATE INDEX idx_responses_property ON public.property_responses(property_id);
CREATE INDEX idx_underwriting_property ON public.underwriting_scenarios(property_id);
CREATE INDEX idx_jobs_org ON public.research_jobs(organization_id);
CREATE INDEX idx_approvals_org ON public.approval_requests(organization_id);
CREATE INDEX idx_audit_org ON public.audit_log(organization_id);
REVOKE ALL ON FUNCTION public.create_my_organization(text) FROM anon;
REVOKE ALL ON FUNCTION public.create_my_organization(text) FROM PUBLIC;
COMMIT;
