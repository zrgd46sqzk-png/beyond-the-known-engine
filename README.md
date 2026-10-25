# Beyond the Known — AI Content Engine (starter scaffold)

A starter project for managing ~30-second science/history videos in separate Arabic and English versions.

## Current status
This repository is a starter scaffold, not a deployed app. No external accounts are connected. The dashboard is a starter UI, not a complete authenticated content-management app, and direct publishing integrations are not implemented.

## Included
- Responsive dashboard and setup checklist.
- Initial Supabase schema for profiles, workspace members, content items, approval history, publishing jobs, and analytics snapshots.
- Initial server-side queue guard that checks approval for the current content version.
- Environment-variable example and iPhone-first Arabic guide.

## Recommended architecture
- Web UI: Next.js.
- Hosting: Vercel (free tier subject to provider limits/terms).
- Auth/database: Supabase (free tier subject to provider limits/pausing).
- Media: Google Drive initially; keep large video files out of the database.
- Publishing: official platform APIs or native schedulers, only after explicit owner approval.

## Local development
Requires Node.js 20+.

```bash
npm install
npm run dev
```
Open `http://localhost:3000`.

## Before deployment
1. Create a Supabase project and review `supabase/schema.sql` carefully.
2. Configure authentication and trusted owner bootstrap.
3. Never expose a service-role key in frontend code.
4. Import this repository into Vercel and configure environment variables.
5. Complete authentication, CRUD, audit logging, storage, and server-side authorization before using real content.

## Production blockers
- Sign-in/out, account recovery, owner/editor/reviewer roles and invitations.
- Fully tested workspace isolation and row-level security policies.
- Authenticated content CRUD and media upload.
- Immutable audit log for approval actions.
- Server-side enforcement that only the workspace owner can approve publishing.
- Any edit to script, caption, video, destination or schedule must invalidate previous approval.
- Official platform integrations with encrypted token storage and least-privilege scopes.
- Automated tests for unauthorized access and approval bypass.

## Non-negotiable publishing rule
No live post may be queued or published unless the exact final content version and destination have explicit, recorded owner approval. Editing approved content must require new approval. Do not connect live platform accounts until this behavior is implemented and tested.

## Public repository notice
This repository is public. Do not commit credentials, private media, account data, or secrets. Use private repositories for sensitive work.