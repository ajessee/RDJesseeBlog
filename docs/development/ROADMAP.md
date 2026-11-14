# Roadmap

Living list of planned work and known technical debt for RDJesseeBlog. Update this as items complete or new ones surface; the detailed day-by-day history behind these items lives in [docs/archive/](../archive/).

## Current static archive work

- [x] Deploy the static archive to Cloudflare Pages and point `www` to Pages — completed November 13, 2026. See [STATIC-CUTOVER-AND-HEROKU-ROLLBACK.md](STATIC-CUTOVER-AND-HEROKU-ROLLBACK.md).
- [x] Capture and restore the final production database snapshot (`b040`) into the isolated local authoring database — completed November 14, 2026. The former Heroku app and database are retired; the restore procedure is documented in [LOCAL-DEVELOPMENT.md](LOCAL-DEVELOPMENT.md).
- [ ] Exercise publishing newly added media end to end when the next picture or recording is ready; the scoped AWS upload and CloudFront allowlist workflow is implemented but has not yet been used for a new media item.
- [ ] Review the next Heroku invoice to confirm charges for the retired app and add-ons have stopped.
- [ ] Re-scan the exact local portability-candidate Docker image digest with Docker Scout before changing dependencies or the base image (see [SECURITY-ACCEPTANCE.md](SECURITY-ACCEPTANCE.md)).
- [x] Remove the `bin/bundle` binstub and add an explicit `Procfile` — done 2026-09-12.
- [x] Add `last_login_at` tracking and display it in the admin user table — done 2026-09-12.

## Rails rebuild work (only if dynamic Rails is needed again)

- Rebuild the Heroku app and database from the preserved `b040` dump only if a dynamic site is needed. Follow [HEROKU-REDEPLOY-AND-TEARDOWN.md](HEROKU-REDEPLOY-AND-TEARDOWN.md); the former app and add-ons no longer exist.
- If Rails is redeployed, verify migrations, authentication, outbound email, uploads, search, and Turnstile using controlled synthetic data before routing traffic.
- Revisit the manual migration/release gate if the app is redeployed. The upgrade found a five-year-old missing `active_storage_variant_records` migration; see [../archive/UPGRADE-PLAN.md](../archive/UPGRADE-PLAN.md).

## Technical debt / compatibility exceptions

Carried over from the Rails 6→8 upgrade — see [../archive/UPGRADE-PLAN.md](../archive/UPGRADE-PLAN.md) for why each was deferred rather than resolved outright:

- [ ] JSON is pinned to 2.x (2.21.2) — JSON 3.0.2 broke session decoding during the upgrade. Revisit when the framework/dependency combination supports it.
- [ ] Elasticsearch 7 client/service — evaluate replacing with PostgreSQL full-text search for this small corpus (~193 stories). Searchbox is currently a free add-on, so this is a dependency-reduction opportunity, not a cost one.
- [ ] Font Awesome 5 icon names — needs a deliberate icon-name migration to go current.
- [ ] `image_processing` 1.x — needs testing against 2.x before upgrading.
- [ ] Legacy Sass/Bootstrap asset pipeline — no modernization plan yet beyond "it works."

## Cost and operations

- [ ] Resolve the ~$15/month of account-level Heroku invoice charges not yet attributed to a specific app (recent invoices total ~$39/month; RDJesseeBlog + BigDumbWebDev's own bases are ~$24 combined).
- [ ] Set up scheduled database exports, a periodic restore drill, and uptime/error monitoring — none exist today beyond Heroku's continuous-protection reporting, which itself has never been restore-tested.

## Longer-term / deferred

- [x] Static archive conversion — reviewed and deployed to Cloudflare Pages; `www` points to Pages. Heroku was retired after the final local database restore. S3 media cleanup remains deferred. See [STATIC-CUTOVER-AND-HEROKU-ROLLBACK.md](STATIC-CUTOVER-AND-HEROKU-ROLLBACK.md) and [HEROKU-REDEPLOY-AND-TEARDOWN.md](HEROKU-REDEPLOY-AND-TEARDOWN.md).
- [ ] BigDumbWebDev's own Rails 6→8 upgrade — same modernization, planned as a Claude Code session rather than Codex. See the `bigdumbwebdev-rails-upgrade` and `rails-upgrade-playbook` entries in Andre's personal Claude memory for the plan and the lessons this app's upgrade already surfaced for it.
