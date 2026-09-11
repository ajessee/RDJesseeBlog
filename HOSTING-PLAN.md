# RDJesseeBlog assessment and hosting plan

Assessment date: September 9, 2026. Repository reviewed at `ea0eec7`.

## Current direction

The active plan is [UPGRADE-PLAN.md](UPGRADE-PLAN.md): modernize both RDJesseeBlog and BigDumbWebDev on Heroku, add tested Docker support, and consider RDJesseeBlog static conversion only after both upgrades stabilize. The options below are retained as research for that later decision, not the current implementation order.

No application upgrades or production changes have been made. Docker deployment alone would not reduce Heroku dyno/database charges.

## What the repository contains

| Component | Finding |
| --- | --- |
| Purpose | Family memorial and writing archive; production has 193 stories |
| Ruby / Rails | Ruby 3.0.0; Rails 6.1.3 in Gemfile.lock; application defaults still 6.0 |
| Server | Puma 5.2.2; PostgreSQL persistence |
| Frontend | ERB, Sprockets/Sass, Webpacker 5.2.1, jQuery, mixed Bootstrap dependencies, Trix |
| Content | Stories with rich HTML and metadata; tags; polymorphic comments, pictures, recordings, videos |
| Media | Active Storage backed by S3 bucket `andre-pictures` in `us-east-1`; generated image variants; ffmpeg audio conversion |
| Search | Elasticsearch models/callbacks; production uses `SEARCHBOX_URL` |
| Email | SendGrid SMTP for account activation/password reset |
| Accounts | Custom session authentication and admin screens |
| Containerization | No tracked Dockerfile, Compose configuration, Procfile, or heroku.yml found |
| Deployment clues | Heroku app `rdjessee` still runs heroku-20; heroku-24 is selected only for future builds |
| Tests | RSpec examples exist for users and authentication; many content-model specs are pending placeholders |

Docker CLI is installed locally. The pinned Ruby 3.0.0 is not installed, so the app and test suite were not run. Heroku dynos are containers, but that does not mean the repository has a portable Docker deployment.

Relevant code: `config/routes.rb`, `db/schema.rb`, `app/models/`, `app/controllers/`, `config/storage.yml`, `config/environments/production.rb`, `Gemfile.lock`, and `package.json`.

## Heroku inspection completed

Authenticated CLI inspection verified one Basic dyno and an Essential-0 database ($5/month), plus free Searchbox Starter and SendGrid Starter plans. The app's base is approximately $12/month including the $7 dyno. PostgreSQL is 17.9 and uses 10.1 MB of its 1 GB allowance.

The running stack is heroku-20; heroku-24 is selected for the next build. The deployed slug is from November 3, 2023, commit `a522ba71a6716f2733b5978310e992ae5713eace`. Release v165 is a database configuration update, not an application upgrade.

Read-only SQL found 193 stories, 56 pictures, 39 recordings, 23 comments and no video records. Latest content changes were in 2020 except pictures (May 2024). User registrations continue. Active Storage metadata records 158 blobs totaling 463,264,054 bytes, with one as large as 130,300,021 bytes. S3 object availability has not been verified.

Latest listed manual export: March 5, 2021. No scheduled exports. Continuous protection is enabled, but a restore has not been tested. The proposed fresh backup capture was declined and did not run.

BigDumbWebDev has the same approximately $12/month base. Recent account invoices total $39, and additional owned apps exist; the remaining charges have not been attributed to line items. AWS billing and live traffic/memory measurements remain unverified. See the active upgrade plan for follow-up checks.

## Option A: static archive

1. **Preserve and inventory.** Obtain a fresh database backup and a separate protected media backup; test restoration. Count all public content and map associations, including nested comments, story readings, user recordings, uploaded videos, and YouTube links. Treat the existing tracked `dump.sql` as historical, not the production source of truth. Keep backups and account data outside public build output.
2. **Export content.** Build an explicit exporter from a restored database into structured JSON plus sanitized HTML. Keep numeric IDs, titles, dates, bylines, captions, tags, and metadata. Export only approved public fields; exclude emails, password digests, reset/activation tokens, and admin data. Avoid executing model callbacks during export.
3. **Make media independent.** Map Active Storage blobs and attachments to stable media URLs. Existing `/rails/active_storage/...` links require Rails, and temporary signed S3 URLs expire. Generate all required thumbnails ahead of time; preserve audio MIME types and range-request playback. Check legacy path fields and embedded HTML links as well as Active Storage. Publish only intended public media through a dedicated prefix/bucket or appropriate CDN origin policy; do not make the entire existing bucket public.
4. **Build the site.** Use a small static generator such as Eleventy, retaining the current visual identity. Generate story, tag, picture, recordings, video, home, and about pages. Use a browser search index such as Pagefind and client-side metadata filters. Preserve quoted-phrase behavior where practical and explicitly test differences from Elasticsearch. Random home-page selections can happen at build time or in the browser.
5. **Resolve contributions.** Existing comments and guestbook entries remain readable. Remove login/upload/edit controls for a fully static archive. New contributions can be published by the owner through content files and a rebuild. A managed form or CMS is optional additional scope, with its own moderation, privacy, and pricing implications; a static site alone cannot retain authenticated uploads or recording submissions.
6. **Preserve links.** Retain `/stories/:id` and other public detail URLs. Explicitly handle `/blog`, `/welcome`, tag links, and existing query-string filters/pagination. A path redirect alone does not reproduce query-string behavior. Add canonical URLs, sitemap, metadata, and a useful 404 page.
7. **Verify and switch.** Compare source/export counts and media manifests. Check every internal link and media reference, mobile layout, image orientation, audio/video playback, and representative searches. Preview on a separate hostname. Freeze writes briefly for a final export, switch DNS/TLS, and retain Heroku for a short rollback window. Only then remove paid resources after confirming backups and explicit cutover approval.

Cloudflare Pages Free supports 500 builds/month, 20,000 files, and a 25 MiB limit per asset. Keep larger recordings/video in S3. Sources: [Pages limits](https://developers.cloudflare.com/pages/platform/limits/), [Cloudflare pricing](https://www.cloudflare.com/plans/developer-platform/), [Pagefind](https://pagefind.app/).

Planning estimate: 3–6 focused engineering days for a faithful static conversion, assuming the production data/media are accessible and intact. A redesign, CMS, or submission backend adds scope. This is an estimate, not a tested delivery commitment.

## Option B: current Rails and Docker

1. **Establish a baseline.** Restore production data privately, build an isolated development environment, and add meaningful regression tests for public pages, authentication/authorization, edits, uploads, search, and playback. Capture screenshots and important URL behavior before changes.
2. **Fix concrete issues.** `StoriesController#update` lacks the login/admin filters applied to edit; recordings create/destroy have no controller authentication filters; user update lacks the ownership filter used by edit. Audit all write routes and enforce server-side ownership/admin rules. Inspect `html_safe` rendering and sanitize rich content. Replace interpolated ffmpeg shell invocation with argument-based execution and safe temporary-file handling. These are source findings, not claims of confirmed exploitation on production.
3. **Upgrade incrementally.** Move through the latest patches of Rails 6.1 → 7.0 → 7.1 → 7.2 → 8.0 → 8.1, testing deprecations and enabling framework defaults at each step. Adjust Ruby at compatible steps. The official pages checked currently advertise Rails 8.1.3 and Ruby 4.0.6; target those or their latest stable successors when implementation starts. Ruby 3.4 can be a compatibility bridge if native dependencies delay Ruby 4. Pin resolved versions rather than leaving Rails unbounded.
4. **Replace aging dependencies.** The locked `trix-rails` requires Rails below 7 and must be replaced. Retire Webpacker in favor of a maintained asset build, consolidate duplicate Bootstrap/font/Trix packages, and preserve frontend behavior with browser tests. Replace removed APIs such as `File.exists?`. Review Active Storage migrations and variant syntax. Remove obsolete Heroku-only gems when no longer needed.
5. **Simplify services.** Replace Elasticsearch/Searchbox with PostgreSQL full-text search for this small corpus, testing phrase matching, ranking, and highlighting. Keep PostgreSQL and S3 initially to reduce migration risk. Verify the current mail provider/SMTP credentials rather than assuming the old SendGrid setup is still available. Move transcoding to a durable background job if retaining it; include any worker compute in the budget.
6. **Containerize.** Add a multi-stage Dockerfile, .dockerignore, development Compose with PostgreSQL, and a production start/migration procedure. Compile assets in the build stage; run as a non-root user; include ffmpeg and the selected image-processing runtime. Exclude dumps and secrets from the image and inject runtime secrets. Configure PORT, health checks, logging, database pool, and upload temporary space. Build for the target CPU architecture and verify restart/redeploy persistence.
7. **Deploy and maintain.** Stage against a restored database, measure memory and transcoding peaks, then choose the smallest proven configuration. Automate backups and test restoration, monitor availability/errors, and document image rollback plus database rollback limitations. Final database migration requires a short write freeze and DNS/TLS validation. Schedule regular dependency updates.

Sources: [Rails releases](https://rubyonrails.org/), [Ruby downloads](https://www.ruby-lang.org/en/downloads/), [Rails upgrade guide](https://guides.rubyonrails.org/upgrading_ruby_on_rails.html).

Planning estimate: 6–12 focused engineering days, potentially more for outdated native gems, frontend compatibility, and recording workflows. Restoring the baseline will narrow that range.

## Hosting comparison

USD/month, researched September 9, 2026. Excludes domain renewal, taxes, existing S3 usage, transactional mail, and extra workers unless stated. Usage estimates are not quotes. Searchbox is currently free on Heroku; replacing it simplifies dependencies but does not save an existing add-on fee.

| Option | Budget | Tradeoff |
| --- | --- | --- |
| Static Cloudflare Pages + existing S3 | $0 page hosting + S3 | Largest savings and lowest ongoing maintenance; publishing workflow changes |
| Current Heroku resource baseline | $12 base: $7 Basic dyno + $5 Essential-0 Postgres | Already configured this way; no $8/month saving from resizing to these plans |
| Render | About $13 base: $7 web + $6 small Postgres, with storage/overages additional | Managed hosting; confirm actual resource fit and final quote; modest savings |
| Railway Hobby | $5 minimum; provisional $8–15 usage budget | App and database consume metered RAM/CPU/storage; measure before promising savings |
| DigitalOcean Docker VPS | $12 for 2 GiB VM + backups | Run app and Postgres together; owner manages OS, TLS, database, recovery and capacity |

At Railway's listed RAM rate, 1 GiB continuously allocated/used for a 30-day month is about $10 before CPU/storage; its $5 minimum includes $5 usage, rather than adding $5 to the usage bill. A small persistent Rails/Postgres pair can therefore exceed the provisional budget. Avoid selecting purely on the advertised minimum.

DigitalOcean also lists a $6 1 GiB VM, but shared app/database memory and audio processing make it an unproven target here. A $12 VM does not save against this app’s verified $12/month resource baseline and adds backup/maintenance costs. Static hosting could remove roughly $144/year of this app’s base Heroku spend while retaining S3; it would not eliminate other account charges.

Sources: [Heroku dynos](https://www.heroku.com/dynos/), [Heroku database pricing](https://www.heroku.com/pricing/), [Render pricing](https://render.com/pricing), [Render small-app cost explanation](https://render.com/articles/how-much-does-cloud-application-hosting-cost-for-small-businesses), [Railway pricing](https://railway.com/pricing), [DigitalOcean pricing](https://www.digitalocean.com/pricing/droplets).

## Deferred decision

Upgrade both Rails applications first, following their respective UPGRADE-PLAN.md files. After stabilization, decide whether family contributions need a self-service workflow before selecting a static architecture. No static conversion is currently underway.
