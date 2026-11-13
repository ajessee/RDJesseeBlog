# Roadmap

Living list of planned work and known technical debt for RDJesseeBlog. Update this as items complete or new ones surface; the detailed day-by-day history behind these items lives in [docs/archive/](../archive/).

## Near-term

- [ ] Verify the remaining authenticated production workflows with controlled synthetic data: login/logout, a reversible admin edit, tags/filtering/search, comments, an image upload, an audio upload/conversion/playback, outbound SendGrid delivery, and both accepted and rejected Turnstile signup submissions. (See [../archive/HEROKU-DEPLOYMENT.md](../archive/HEROKU-DEPLOYMENT.md) for what was already verified at the `v169` rollout.)
- [ ] Test database-backup restoration in isolation, and verify the S3 media-backup story independently of the Postgres backup. Neither has ever been tested, only "continuous protection" reporting as enabled.
- [ ] Re-scan the exact release-candidate Docker image digest with Docker Scout before the next deploy that touches dependencies or the base image (see [SECURITY-ACCEPTANCE.md](SECURITY-ACCEPTANCE.md)) — no digest-exact scan has been authorized yet, only the package-layer result.
- [x] Remove the `bin/bundle` binstub and add an explicit `Procfile` — done 2026-09-12.
- [x] Add `last_login_at` tracking and display it in the admin user table — done 2026-09-12.

## Deployment automation

- [ ] Consider moving `bin/rails db:migrate` from a manual `heroku run` step to a Heroku release-phase command, once deploy cadence increases enough that the manual gate is more overhead than safety net.
  - **Why it's manual for now:** this app deploys rarely, and the upgrade already hit one incident where a moment of manual review would have caught a missing migration before it went out (a five-year-old `active_storage_variant_records` table gap — see [../archive/UPGRADE-PLAN.md](../archive/UPGRADE-PLAN.md)). A release-phase command runs automatically, immediately before traffic shifts to new dynos, with no chance to check `db:migrate:status` or take a fresh backup first. Revisit this tradeoff if manual migrations start getting forgotten or deploys become frequent enough that the review step is the bottleneck.
- [ ] Evaluate the Heroku-24 → Heroku-26 stack upgrade once the current stack has been stable for a while (Heroku recommends moving stack/runtime/framework incrementally, not all at once).

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

- [ ] Static-archive conversion — implementation and owner review are complete on `codex/static-site-conversion`; production cutover is pending. Target: Cloudflare Pages for generated HTML/CSS/JavaScript, with media kept in S3 through CloudFront. AWS/OAC setup and the private exporter are documented in [HOSTING-PLAN.md](HOSTING-PLAN.md). The generator restores the original homepage order and styling: one of the six original full-length hero passages typed at the original Typed.js cadence inside a fixed full-screen hero, followed by signature/book reveal, a sticky menu revealed after the hero, full biography, three aligned parallax quotes, three random photo-bearing story cards, three random pictures, two columns of random recordings, and a nine-slide obituary carousel before the guestbook, with distinct visual separation among recordings, obituary, and guestbook. The branch preview is direct-uploaded at [codex-static-site-conversion.rdjessee-blog-preview.pages.dev](https://codex-static-site-conversion.rdjessee-blog-preview.pages.dev/); the separate [preview.ralphdonaldjessee.com](https://preview.ralphdonaldjessee.com/) custom hostname is active with SSL. The Pages project has no Git integration; `www` still points to Heroku. Desktop review confirmed the revised search/filter layout and clear-all behavior, Nexa Bold navigation, and audio players contained in their story cards. Four Node tests are defined in `npm run site:test`; they cover entity-to-text conversion, filter matching, synthetic static output, and the unresolved-media build guard. Keep Heroku through the rollback window and defer S3 cleanup until after cutover verification. Follow [STATIC-CUTOVER-AND-HEROKU-ROLLBACK.md](STATIC-CUTOVER-AND-HEROKU-ROLLBACK.md) for release gates and recovery.
- [ ] BigDumbWebDev's own Rails 6→8 upgrade — same modernization, planned as a Claude Code session rather than Codex. See the `bigdumbwebdev-rails-upgrade` and `rails-upgrade-playbook` entries in Andre's personal Claude memory for the plan and the lessons this app's upgrade already surfaced for it.
