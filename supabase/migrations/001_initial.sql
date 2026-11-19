-- shikarisøkesearch initial schema
create extension if not exists pgcrypto;

create type public.membership_role as enum ('owner','admin','member');
create type public.property_stage as enum ('new','researching','underwriting','review_required','approved_for_next_step','archived');
create type public.finding_kind as enum ('verified_fact','inference','estimate','unknown');
create type public.research_status as enum ('queued','running','completed','needs_review','failed');
create type public.approval_action as enum ('contact_person','send_offer','sign_document','submit_document','pay_money','initiate_transaction');
create type public.approval_status as enum ('pending','approved','rejected','expired','executed');

create table public.organizations (
 id uuid primary key default gen_random_uuid(),
 name text not null,
 created_at timestamptz not null default now()
);
create table public.organization_members (
 organization_id uuid references public.organizations(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 role public.membership_role not null default 'member',
 created_at timestamptz not null default now(),
 primary key (organization_id,user_id)
);
create table public.subscriptions (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete cascade,
 provider text not null default 'stripe',
 provider_customer_id text,
 provider_subscription_id text unique,
 plan_key text not null default 'free',
 status text not null default 'incomplete',
 current_period_end timestamptz,
 created_at timestamptz not null default now()
);
create table public.properties (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete cascade,
 state_code char(2) not null default 'WA',
 county text,
 situs_address text,
 city text,
 postal_code text,
 parcel_number text,
 legal_description text,
 property_type text,
 latitude double precision,
 longitude double precision,
 stage public.property_stage not null default 'new',
 source_first_seen text,
 overall_confidence numeric(4,3) check (overall_confidence between 0 and 1),
 created_by uuid references auth.users(id),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique (organization_id,state_code,parcel_number)
);
create table public.property_sources (
 id uuid primary key default gen_random_uuid(),
 property_id uuid not null references public.properties(id) on delete cascade,
 source_name text not null,
 source_url text not null,
 source_type text not null,
 published_at timestamptz,
 retrieved_at timestamptz not null default now(),
 source_record_id text,
 content_hash text,
 notes text,
 created_at timestamptz not null default now()
);
create table public.research_runs (
 id uuid primary key default gen_random_uuid(),
 property_id uuid not null references public.properties(id) on delete cascade,
 agent_key text not null,
 agent_label text not null,
 status public.research_status not null default 'queued',
 started_at timestamptz,
 completed_at timestamptz,
 summary text,
 confidence numeric(4,3) check (confidence between 0 and 1),
 error_message text,
 created_at timestamptz not null default now()
);
create table public.property_findings (
 id uuid primary key default gen_random_uuid(),
 property_id uuid not null references public.properties(id) on delete cascade,
 research_run_id uuid references public.research_runs(id) on delete set null,
 finding_kind public.finding_kind not null,
 category text not null,
 title text not null,
 detail text not null,
 confidence numeric(4,3) check (confidence between 0 and 1),
 source_id uuid references public.property_sources(id) on delete set null,
 needs_human_verification boolean not null default true,
 created_at timestamptz not null default now()
);
create table public.property_responses (
 id uuid primary key default gen_random_uuid(),
 property_id uuid not null references public.properties(id) on delete cascade,
 response_version integer not null default 1,
 headline text not null,
 executive_summary text not null,
 verified_facts jsonb not null default '[]',
 inferences jsonb not null default '[]',
 estimates jsonb not null default '[]',
 unresolved_questions jsonb not null default '[]',
 risk_flags jsonb not null default '[]',
 recommended_next_steps jsonb not null default '[]',
 generated_at timestamptz not null default now(),
 unique(property_id,response_version)
);
create table public.underwriting_scenarios (
 id uuid primary key default gen_random_uuid(),
 property_id uuid not null references public.properties(id) on delete cascade,
 strategy text not null check (strategy in ('wholesale','rental','flip','creative_finance')),
 inputs jsonb not null default '{}',
 outputs jsonb not null default '{}',
 assumptions jsonb not null default '[]',
 missing_inputs jsonb not null default '[]',
 confidence numeric(4,3) check (confidence between 0 and 1),
 created_at timestamptz not null default now()
);
create table public.research_jobs (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete cascade,
 property_id uuid references public.properties(id) on delete cascade,
 state_code char(2) not null default 'WA',
 county text,
 category text,
 keywords text,
 status public.research_status not null default 'queued',
 scheduled_at timestamptz,
 started_at timestamptz,
 completed_at timestamptz,
 result_count integer not null default 0,
 created_at timestamptz not null default now()
);
create table public.approval_requests (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete cascade,
 property_id uuid references public.properties(id) on delete set null,
 action public.approval_action not null,
 status public.approval_status not null default 'pending',
 description text not null,
 requested_payload jsonb not null default '{}',
 requested_by uuid references auth.users(id),
 decided_by uuid references auth.users(id),
 decided_at timestamptz,
 expires_at timestamptz,
 created_at timestamptz not null default now()
);
create table public.audit_log (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete cascade,
 actor_user_id uuid references auth.users(id),
 property_id uuid references public.properties(id) on delete set null,
 event_type text not null,
 event_detail jsonb not null default '{}',
 created_at timestamptz not null default now()
);

create or replace function public.is_org_member(org_id uuid)
returns boolean language sql stable security definer set search_path=public
as $$ select exists(select 1 from public.organization_members m where m.organization_id=org_id and m.user_id=auth.uid()); $$;

alter table public.organizations enable row level security;
alter table public.organization_members enable row level security;
alter table public.subscriptions enable row level security;
alter table public.properties enable row level security;
alter table public.property_sources enable row level security;
alter table public.research_runs enable row level security;
alter table public.property_findings enable row level security;
alter table public.property_responses enable row level security;
alter table public.underwriting_scenarios enable row level security;
alter table public.research_jobs enable row level security;
alter table public.approval_requests enable row level security;
alter table public.audit_log enable row level security;

create policy "org members read org" on public.organizations for select using (public.is_org_member(id));
create policy "members read membership" on public.organization_members for select using (public.is_org_member(organization_id));
create policy "members read subscriptions" on public.subscriptions for select using (public.is_org_member(organization_id));
create policy "members manage properties" on public.properties for all using (public.is_org_member(organization_id)) with check (public.is_org_member(organization_id));
create policy "members access property sources" on public.property_sources for all using (exists(select 1 from public.properties p where p.id=property_id and public.is_org_member(p.organization_id))) with check (exists(select 1 from public.properties p where p.id=property_id and public.is_org_member(p.organization_id)));
create policy "members access research runs" on public.research_runs for all using (exists(select 1 from public.properties p where p.id=property_id and public.is_org_member(p.organization_id))) with check (exists(select 1 from public.properties p where p.id=property_id and public.is_org_member(p.organization_id)));
create policy "members access findings" on public.property_findings for all using (exists(select 1 from public.properties p where p.id=property_id and public.is_org_member(p.organization_id))) with check (exists(select 1 from public.properties p where p.id=property_id and public.is_org_member(p.organization_id)));
create policy "members access responses" on public.property_responses for all using (exists(select 1 from public.properties p where p.id=property_id and public.is_org_member(p.organization_id))) with check (exists(select 1 from public.properties p where p.id=property_id and public.is_org_member(p.organization_id)));
create policy "members access underwriting" on public.underwriting_scenarios for all using (exists(select 1 from public.properties p where p.id=property_id and public.is_org_member(p.organization_id))) with check (exists(select 1 from public.properties p where p.id=property_id and public.is_org_member(p.organization_id)));
create policy "members access jobs" on public.research_jobs for all using (public.is_org_member(organization_id)) with check (public.is_org_member(organization_id));
create policy "members access approvals" on public.approval_requests for all using (public.is_org_member(organization_id)) with check (public.is_org_member(organization_id));
create policy "members read audit" on public.audit_log for select using (public.is_org_member(organization_id));

-- Deliberately no public client policy to execute approvals or perform external actions.
-- Service-role credentials must remain server-side. Add server-side authorization and
-- a second confirmation before any future action executor is introduced.
