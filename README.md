# shikarisøkesearch — starter application

A Washington-first, installable real-estate research PWA starter. This is source code, not a deployed service.
It includes:
- Next.js App Router + TypeScript PWA shell
- Property-specific Autopilot investigation timeline
- Supabase PostgreSQL schema with tenant-aware row-level security
- Research jobs, findings, source citations, underwriting scenarios, approvals and audit log tables
- Explicit approval gates for outreach and transaction actions

## Stack
- Next.js 15 / React 19 / TypeScript
- Supabase Auth + PostgreSQL + Storage
- Vercel (or equivalent) hosting and scheduled jobs
- OpenAI API for research synthesis (server-side only)
- Stripe Billing for public subscriptions (integration stub; requires account and keys)

## Local setup
1. Install Node.js 20+.
2. Create a Supabase project.
3. Copy `.env.example` to `.env.local` and fill in values.
4. In Supabase SQL Editor, run `supabase/migrations/001_initial.sql`.
5. Run:
   ```bash
   npm install
   npm run dev
   ```
6. Open http://localhost:3000.

## Important deployment work still required
- Configure Supabase Auth redirect URLs and email templates.
- Add OpenAI, Stripe and hosting secrets to the deployment environment.
- Implement and validate source-specific Washington county connectors.
- Configure scheduled jobs and worker execution.
- Complete security review, privacy policy, terms, subscription cancellation, tax and consumer-law review.
- Run integration tests and verify that RLS policies behave correctly for multiple accounts.

## Safety boundary
The app is designed for autonomous public-record research and analysis only. It must not autonomously contact owners, heirs, agents, lenders, buyers or public offices; send offers; sign; submit documents; pay; or initiate a binding transaction. Any future external-action feature must require a separate, explicit, logged user approval and a second confirmation immediately before execution. This starter intentionally contains no send/contact/offer execution endpoint.

## Product behavior
Every property has its own investigation timeline. Research agents append findings with source URL, source date, retrieval time, confidence, evidence type, and unresolved questions. The UI must distinguish verified facts, inferences, and estimates.
