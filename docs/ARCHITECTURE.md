# Architecture

## System overview
Mobile PWA (Next.js) -> Supabase Auth -> tenant-scoped PostgreSQL -> research-job queue -> server-side research workers -> public source adapters -> evidence records -> property response synthesis -> underwriting -> user review.

## Agent roles
1. Scout: discover public-record candidates.
2. Parcel Investigator: match parcel IDs, situs, legal description and assessor.
3. Probate Research: public case-index and estate-indicator research.
4. Tax & Foreclosure: delinquency, redemption, auction and trustee-sale status.
5. Title & Risk: recorded instruments, easements, liens, access and restrictions.
6. Underwriter: comps, ARV, repairs, rent and four-strategy analysis.
7. Financing: DSCR, private money, seller terms and creative structures.
8. Acquisitions: assemble property-specific response, CRM status and next steps.

Agents are workflow roles, not independently deployed services until worker infrastructure is implemented.

## Property response contract
Each property response contains:
- executive summary
- verified facts (each linked to a source)
- inferences (explicitly labeled)
- estimates (assumptions and ranges)
- source register (URL, publisher, published date, retrieval timestamp)
- agent-by-agent timeline
- confidence and rationale
- unresolved questions
- risks / red flags
- strategy-specific underwriting
- recommended next research steps

Never state a property is available, unencumbered, buildable, probate-controlled, or profitable unless evidence supports it.

## Public subscription model
Organizations are tenants. A solo subscriber has a one-person organization; teams can invite members. Stripe Billing should provision plans and entitlements via verified webhooks. Suggested tiers: Starter (limited saved properties and manual scans), Investor (higher scan allowance and underwriting), Team (seats, shared CRM). Final pricing and limits remain a business decision.

## Security and privacy
- Supabase RLS on every tenant-owned table.
- Service role and AI keys are server-side only.
- Verify Stripe webhook signatures.
- Rate-limit research endpoints and enforce per-plan quotas.
- Store source URLs and extracted evidence, not unrestricted copyrighted page copies.
- Keep audit records for user decisions.
- Do not expose personal data beyond lawful, necessary public-record research.
- Never automate outreach or transactions. Approval request records are not authorization to execute until a future separately secured workflow exists.
