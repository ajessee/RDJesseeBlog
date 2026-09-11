# RDJesseeBlog upgrade plan

Updated September 11, 2026. Status: local Rails 8.1 / Ruby 4.0 migration and production-image checks implemented on `andre/rdjessee-upgrade`; fresh production backups and deployment have not started.

## Progress: staged framework migration

- Added an isolated Docker Compose environment with PostgreSQL and Elasticsearch, local media, and non-delivering development email. Setup commands: [LOCAL-DEVELOPMENT.md](LOCAL-DEVELOPMENT.md).
- Moved Ruby 3.0.0 → 3.0.7 and Rails 6.1.3 → 6.1.7.10 as temporary migration steps. The original lockfile could not install because `mimemagic 0.3.5` was removed from RubyGems. These versions remain end-of-life and are not the deployment target.
- Resolved logger boot ordering; disabled legacy Bootsnap in Compose pending its upgrade. The baseline container builds and its test database initializes.
- Removed seven empty helper specs for nonexistent modules. The remaining original suite executes: 82 examples, 25 failures, 29 pending. New public-page/account-access request checks pass: 10 examples, 0 failures.
- RSpec now refuses a non-test environment or inherited `DATABASE_URL`; coverage goes to ignored temporary output.
- Repaired obsolete feature/controller/mailer assertions; the Rails 6.1 baseline passed 107 examples with zero failures and 29 pending. Added authorization regressions and corrected write guards, account privilege escalation, ownership assignment, and comment edits that previously wrote on GET. This is targeted coverage, not a completed security audit.
- Advanced to Rails 7.0.10. Removed `trix-rails` and unused Webpacker scaffolding; pinned npm Trix 2.1.19 served by Sprockets while preserving HTML database columns. Docker image builds, RSpec passes **111 examples, zero failures, 29 pending**, and test-environment assets precompile.
- Rails 7.1.6 with RSpec 6.1.5 passed the same 111 examples on Ruby 3.0.7 before the runtime change. Ruby 3.3.12 / Bundler 2.6.9 also passes **111 examples, zero failures, 29 pending**, eager-loading checks, and test-environment asset compilation. Updated pg to 1.6.3, Puma to 8.0.2, Capybara to 3.40.0, Listen to 3.10.0, and the native debugger dependencies for compatibility. Locked ARM and x86 Linux platforms.
- Replaced deprecated Factory Girl with Factory Bot; updated fixture paths and exception handling for Rails 7.1, adopted the 7.1 cache serialization format and modern timezone conversion, and removed obsolete `secrets.yml`. Production explicitly retains `SECRET_KEY_BASE` from Heroku; development/test use Rails-generated local secrets. Bootsnap is updated and enabled again.
- Rebuilt the development image successfully and booted Puma against the isolated development database. The Rails 8.1.3.1 image builds and boots; HTTP smoke checks returned 200 for `/`, `/blog`, `/stories`, `/login`, `/pictures`, `/recordings`, and `/videos`. These checks do not verify browser JavaScript or media processing.
- Rails 7.2.3 and Rails 8.0.5.1 each passed **116 examples, zero failures, 29 pending**, autoloading checks, and test-environment asset compilation. Updated Jbuilder to 2.15.1 and RSpec Rails to 8.0.4. Expanded public story coverage and fixed metadata filtering that returned nil or retained stale values across requests.
- Rails 8.1.3.1 passes **116 examples, zero failures, 29 pending**, autoloading checks and test-environment asset compilation; no deprecation warnings appeared in these checks. Compatibility exception: JSON is constrained to 2.x (resolved 2.21.2), because JSON 3.0.2 caused session-decoding argument errors in the regression suite. Revisit when the framework/dependency combination supports it. The obsolete timezone compatibility setting is removed; Rails 8.1 supplies the new behavior.
- Advanced to Ruby 4.0.6, Bundler 4.0.16 and Node 24 on Debian Trixie. Updated the dependency lockfile; removed unused Spring, Pry/Byebug, Jbuilder, Sdoc, Uglifier and rails_12factor. Replaced the incompatible Bootstrap pagination gem with a local renderer and a two-page regression.
- Current suite: **144 examples, zero failures, 29 pending**, including real audio conversion, cleanup on conversion failure, image variants, rich HTML sanitization, pagination, health checks, expanded authorization coverage, and Rails-default compatibility. Audio conversion now uses argument-based execution and Active Storage downloads, retains originals on failure, and no longer assumes a personal recording belongs to a story. Declaration-order commit callbacks ensure upload precedes conversion. Conversion remains synchronous. Upload validation rejects empty, unsupported MIME types and oversized new attachments (20 MB pictures; 200 MB audio/video); a real EXR payload named and declared as JPEG is identified as unsupported and rejected in regression coverage. MIME identification is not a sandbox or complete content inspection, and long conversions still require timeout/background-processing review. Conversion failures preserve the original and expose an owner/admin retry action; request tests cover these paths.
- Reviewed all implemented controller write actions against their authentication, role and ownership guards. Closed a remaining mismatch that let any signed-in reader open the story form and create a blog post even though the UI and edit/delete behavior reserve story management for admins. Request coverage now verifies anonymous, reader, owner and admin boundaries for stories, users, comments, pictures, recordings and videos, including forged ownership fields. Signup, login, token-authenticated activation/reset, comments and reader media contributions remain intentionally available to their existing audiences. The routed SendGrid response endpoints have no controller implementation and remain part of the separate outbound-email/integration review.
- Added a multi-stage, non-root production Docker image with ffmpeg/libvips, runtime secrets, stdout logs, PORT support, and a separate migration operation. Rails 8.1 variants use libvips, so redundant ImageMagick is excluded from production while remaining available for independent development/test fixture inspection. Assets compile with networking disabled and no production credentials. Isolated production HTTP checks exercise populated story lists, compiled CSS/JavaScript and recovery after restart; tools convert synthetic audio and images. See [PRODUCTION-DOCKER.md](PRODUCTION-DOCKER.md).
- Security checks are now reproducible through locked development-only Brakeman 8.0.6 and Bundler Audit 0.9.3 dependencies plus `bin/security-scan`; the production-image gate is `bin/container-security-scan`. On September 11, Brakeman reported zero warnings, Bundler Audit reported no vulnerable gems using advisory database commit `93b32f641f84282183ce58ab1d7204bee50885bd` dated September 8, and npm reported zero vulnerabilities. Docker Scout initially reported 1 critical and 28 high findings across seven packages. A no-cache rebuild located the available OpenSSL 3.5.7 Debian fix, so OpenSSL is now installed explicitly in the runtime layer. The reduced final ARM image has 742 indexed packages, verifies `openssl`/`libssl` 3.5.7, and rescans at 0 critical and 25 high findings. Twenty-four are required libvips/ffmpeg dependencies with no published Debian fixes; the other is Ruby's inactive default JSON 2.18.0 gem, while `bundle exec` demonstrably loads the application's locked 2.21.2. Redundant production ImageMagick was removed, and disguised-EXR rejection has a regression, but these steps do not eliminate the underlying decoder findings. Do not suppress them; monitor base/runtime package fixes and address or explicitly accept them before deployment.
- Compatibility exceptions remain: JSON 2.x, Elasticsearch 7 client/service, Font Awesome 5 icon names, image_processing 1.x, and legacy Sass/Bootstrap assets. These need deliberate migration or a documented final exception, not an unqualified claim that all dependencies are current. Both ARM and explicit amd64 production images build and execute locally. The amd64 image reports x86-64 Ruby/native gems, eagerly loads Rails, runs libvips/ffmpeg/OpenSSL as UID 1000, and serves the public route set against a disposable isolated database under emulation; native-x86 performance is not tested. After explicit approval for Scout indexing, amd64 also scans at 0 critical and 25 high findings in the same six packages as ARM.
- Browser checks with synthetic local data passed login, formatted story creation with redirect to its detail URL, and WAV upload/conversion with an audio player displayed. Unsupported Trix attachments are disabled; dedicated upload fields remain. At desktop 1280x720 and mobile 390x844, the home, blog, stories, pictures, recordings and login pages had no document-level horizontal overflow or broken images; the mobile navigation works and audio controls fit. A stored converted recording began playback. Mobile recordings spacing was fixed so the heading clears the fixed navigation. Microphone start/stop now produces an inline preview and editable default caption without a blocking prompt. The in-app browser's synthetic microphone stream was not decodable for playback or ffmpeg conversion; its submission verified that the original is preserved and retry UI is shown, but successful real-device capture/playback remains outstanding. No browser console errors remained after the prompt fix.
- Application defaults now load Rails 8.1. Legacy image variants were migrated to processor-neutral operations and pass with the Rails 8.1 libvips default. Same-host redirect fallbacks replace raw `Referer` redirects, and deprecated Rack 422 status names were updated without changing their numeric response. Session, remembered-login, same-host return URL and Rails 6-format signed-cookie regressions pass. Compatibility exception: cookie keys still use the prior SHA-1 derivation so existing permanent cookies remain readable; move to SHA-256 only with a tested production cookie-rotation plan.
- Next: real-device microphone validation, review/address or explicitly accept the remaining cross-architecture image findings, then staging/backup/Heroku deployment after authorization. No production changes have been made.

## Scope and sequence

Modernize RDJesseeBlog and BigDumbWebDev as separate Rails applications. Keep both on Heroku initially, upgrade Rails/Ruby and dependencies, add tested Docker configurations, address security and operational issues, and investigate account costs. Only after both upgrades are stable should RDJesseeBlog be evaluated for static conversion. Preserve existing features, content, URLs, and visual identity during modernization.

Working deployment recommendation: retain Heroku buildpacks on the latest supported numbered stack and use Docker for reproducible development and portability. Deploying Docker images directly on Heroku is a separate choice, not a cost-saving measure: it uses the `container` stack and retains dyno/database charges. That choice has not been finalized.

## Verified baseline

| Area | September 9, 2026 finding |
| --- | --- |
| Repository | Ruby 3.0.0, Rails 6.1.3, Rails 6.0 defaults, Puma 5.2.2, Webpacker 5.2.1 |
| Heroku app | `rdjessee`, US region, Cedar generation, one Basic web dyno |
| Deployment | Buildpacks: Active Storage preview, ffmpeg, Ruby; no Dockerfile or Compose configuration |
| Stack | Running `heroku-20`; next-build setting is `heroku-24`. Selecting a stack did not upgrade the existing release |
| Deployed code | Slug built November 3, 2023 from `a522ba71a6716f2733b5978310e992ae5713eace`; current release v165 is a database configuration update |
| Database | PostgreSQL 17.9, Essential-0, 10.1 MB of 1 GB, 20-connection limit |
| Services | S3 Active Storage; Searchbox Starter and SendGrid Starter show $0/month attached plans |
| Domain | `www.ralphdonaldjessee.com`, automatic certificate management enabled |
| Content | 193 stories, 56 pictures, 39 recordings, 23 comments, no video records; 83 users |
| Activity | Latest story update September 2020; latest comment August 2020; latest recording May 2020; latest picture May 2024; account registrations continue |
| Media | 158 blob records, 463,264,054 bytes total, largest 130,300,021 bytes; this is database metadata, not a verified S3 inventory |
| Backups | Latest listed manual export March 5, 2021; no export schedule. Continuous protection reports enabled, but restoreability has not been tested |

The baseline table records the pre-upgrade inspection. The temporary toolchain now runs in Docker, without a host Ruby installation. Test results are recorded above. No fresh backup was created: the proposed capture command was declined. Do not retry a production backup or deployment without resolving that approval.

## Implementation checklist

### 1. Establish a safe baseline

- [x] Create a dedicated `codex/` upgrade branch, preserve local changes, and compare checkout and deployed code.
- [ ] Arrange fresh database and media backups and test restoration in isolation before production changes. Keep dumps, user data, and secrets out of Git and Docker build contexts; review the existing tracked `dump.sql`.
- [x] Boot the existing app locally with isolated PostgreSQL, local media storage, non-delivering email, and an isolated search service. Never run tests against production.
- [x] Run RSpec; record existing failures and add regression coverage for important behavior rather than filling every placeholder spec.
- [ ] Capture representative desktop/mobile pages and old URLs for comparison.

### 2. Upgrade framework and dependencies

- [ ] Verify latest stable releases at implementation time. The official pages consulted advertise Rails 8.1.3 and Ruby 4.0.6. Target current stable successors if available, not preview releases; record any compatibility exception.
- [ ] Upgrade through latest patches of Rails 6.1 → 7.0 → 7.1 → 7.2 → 8.0 → 8.1 (and any newer stable target), changing Ruby at compatible steps. Intermediate unsupported versions are local migration steps only.
- [ ] Resolve deprecations and review generated configuration/default changes at each step. Pin versions and regenerate lockfiles with the selected toolchain.
- [x] Replace `trix-rails` (locked version requires Rails below 7) and Webpacker with maintained equivalents. Preserve existing rich HTML content rather than blindly migrating it to a new storage model.
- [ ] Consolidate overlapping Bootstrap, Trix, font, and asset dependencies. Select one JS package manager; update Sass tooling and browser assets while preserving behavior.
- [ ] Update remaining gems, Puma, Bundler, Node LTS/build tooling, and platform libraries. Remove unused dependencies and keep development/security tools out of the production bundle where appropriate.
- [x] Review Active Storage migrations, image variants, removed APIs such as `File.exists?`, autoloading, serialization, cookies, and session compatibility. Rails 8.1 defaults, autoloading, assets, libvips variants and legacy signed-cookie reads pass; retain SHA-1 cookie-key derivation as an explicit temporary compatibility exception pending production rotation.

### 3. Correct application and operational issues

- [x] Enforce authentication/authorization on every implemented write action. Correct story create/update guards, recording creation/deletion, user ownership and admin-only privilege changes; derive ownership server-side and retain request regressions for the role and ownership boundaries. Token-based account activation/password reset and the unimplemented SendGrid response routes require their separate integration checks.
- [ ] Derive authorship from the session rather than trusting submitted user IDs. Audit rich HTML rendering and upload types/sizes.
- [ ] Replace interpolated ffmpeg shell commands with argument-based execution and safe temporary files. Verify upload, conversion, cleanup, and playback; use durable background processing if required, accounting for worker cost.
- [ ] Evaluate replacing Elasticsearch with PostgreSQL full-text search. Searchbox is currently free, so removal reduces dependencies, not the current invoice. Preserve phrase search, ranking, and highlighting; defer replacement if it distracts from a safe framework upgrade.
- [ ] Verify SendGrid delivery, S3 permissions, HTTPS, secrets handling, logs, and error handling. Add a health endpoint and tune Puma/database pools within 20 available connections.

### 4. Add portable Docker support

- [x] Add a multi-stage production Dockerfile, `.dockerignore`, non-root runtime, documented entrypoint, and development Compose with isolated PostgreSQL and media storage.
- [x] Compile assets during builds without production credentials or production database access. Include required image-processing and ffmpeg runtime packages.
- [ ] Support `PORT`, runtime secrets, stdout logs, graceful shutdown, and persistent external media/database storage. Keep migrations an explicit release operation rather than running on every web restart.
- [ ] Test build, boot, assets, migrations, health, and restarts. Build the required target architecture; document parity with Heroku buildpacks.

### 5. Verify and deploy on Heroku

- [ ] Verify current stack availability and Ruby/native-buildpack compatibility. Heroku's current documentation lists `heroku-26` as supported and `heroku-24` as default; target the newest supported stack that passes validation and document any blocker.
- [ ] Validate on a separate preview/staging environment with isolated storage and email. Agree on temporary paid resources before provisioning them.
- [ ] Require passing RSpec/request tests, production asset compilation, Docker smoke tests, dependency/security scans with findings addressed or documented, and mobile/browser checks.
- [ ] Exercise login/logout, activation/reset, admin edits, tags/filtering/search, comments/guestbook, images, in-browser recording, uploaded audio and playback.
- [ ] Prepare fresh verified backups and release rollback instructions, including which migrations are backward compatible. Schedule any necessary write freeze.
- [ ] Deploy one app at a time, verify the actually running stack/release, URLs/TLS, assets, logs, database and media access, and retain the prior release until stable.
- [ ] Configure scheduled exports, restore checks, uptime/error monitoring, and automated dependency-update proposals after the required approvals.

## Costs and acceptance criteria

Current resource baseline is approximately $12/month: $7 Basic dyno plus $5 Essential-0 database, excluding S3/taxes/account-level charges. BigDumbWebDev has the same base, making $24 combined. Recent account invoices total $39; other owned apps exist, but invoice line-item attribution is still unresolved. Do not attribute the entire account bill to this site or remove other apps without authorization.

Docker on Heroku does not itself lower costs. Retain separate small databases, measure memory before downsizing, and avoid paid services without a demonstrated need. Completion means current supported runtime/dependencies and actual deployed stack, passing regression checks, reproducible Docker builds, tested recovery, and documented recurring costs—not merely edited version numbers.

## Later: static archive assessment

After both Rails upgrades stabilize, revisit the contribution workflow and the static export design in [HOSTING-PLAN.md](HOSTING-PLAN.md). Preserve public IDs/URLs, comments and guestbook, metadata search, original media, and thumbnails. Replace Rails-dependent Active Storage URLs with durable public media URLs. Exclude accounts/private data from static output. The large audio files should remain in object storage. Static conversion is deferred, not authorized for implementation by this plan.

## References

- [Rails releases](https://rubyonrails.org/) and [upgrade guide](https://guides.rubyonrails.org/upgrading_ruby_on_rails.html)
- [Ruby releases](https://www.ruby-lang.org/en/downloads/)
- [Heroku stacks](https://devcenter.heroku.com/articles/stack), [Ruby support](https://devcenter.heroku.com/articles/ruby-support-reference), and [pricing](https://www.heroku.com/pricing/)

Version and price observations are dated; recheck before implementation or purchasing resources.
