# Heroku redeployment and teardown plan

Inventory captured November 13, 2026 with the authenticated Heroku CLI. This is a record and plan only. No Heroku resources were changed or removed.

## Current state

| Resource | Current value |
| --- | --- |
| Heroku app | `rdjessee`, owned by `andre.isaac.jessee@gmail.com`, US region, `heroku-24` stack |
| App URL | `https://rdjessee.herokuapp.com/` (still returns HTTP 200); this is a rollback endpoint, not the public hostname |
| Web formation | One `Basic` web dyno, running `bin/rails server -p ${PORT:-5000} -e $RAILS_ENV` |
| Current release | `v171`, deployed commit `b7071c27` (`Track and display each user's last login time`); deployed September 12, 2026 |
| Git remote | `https://git.heroku.com/rdjessee.git`; local `heroku/main` points at `b7071c2` |
| Buildpacks, in order | `heroku-buildpack-activestorage-preview`, `heroku/nodejs`, `heroku/ruby` |
| PostgreSQL | `postgresql-pointy-18109`, `essential-0`, PostgreSQL 17.10, 10.3 MB of 1 GB, 20 connection limit; attached as `DATABASE` |
| Latest database backup | `b039`, completed November 13, 2026, 387.22 KB. It was downloaded and restored locally. No recurring backup schedule is configured; continuous protection is On. |
| Search | `searchbox-convex-81586`, `searchbox:starter`, free; attached as `SEARCHBOX` |
| Email | `sendgrid-trapezoidal-14729`, `sendgrid:starter`, free; attached as `SENDGRID` |
| Heroku custom domain | `www.ralphdonaldjessee.com`, target `www.ralphdonaldjessee.com.herokudns.com`, SNI endpoint `tenontosaurus-30456` |
| Heroku ACM certificate | Trusted for `www.ralphdonaldjessee.com`; expires December 14, 2026. The domain's Squarespace CNAME now points to Pages, so this certificate is retained only for rollback. |

The Heroku config currently has these variable names: `AWS_ACCESS_KEY_ID`, `AWS_REGION`, `AWS_SECRET_ACCESS_KEY`, `DATABASE_URL`, `LANG`, `NODE_OPTIONS`, `RACK_ENV`, `RAILS_ENV`, `RAILS_MASTER_KEY`, `RAILS_SERVE_STATIC_FILES`, `SEARCHBOX_SSL_URL`, `SEARCHBOX_URL`, `SECRET_KEY_BASE`, `SENDGRID_PASSWORD`, `SENDGRID_USERNAME`, and the three `TURNSTILE_*` variables. **Secret values were not printed or copied into this document.** Before deleting the app, save any still-needed values in a password manager or replace them with the appropriate current credentials. Do not reuse long-lived AWS access keys; the current local AWS identity/role session requires reauthentication and is not the same identity as the app's old credentials.

At the current published rates, the continuously running Basic dyno is up to $7/month and the Essential-0 database is $5/month, for about $12/month before taxes or other account charges. Searchbox and SendGrid currently show free plans. Actual app usage is prorated. See [Heroku pricing](https://www.heroku.com/pricing/) and [Heroku usage and billing](https://devcenter.heroku.com/articles/usage-and-billing).

### Account-level resources outside this app

The Heroku account also lists `big-dumb-web-dev`, `head-up`, `nycycle-1`, and `sql-tutor-upgrade`, plus collaborated app `magellan-investments`. The add-on inventory attaches a Postgres Essential-0 and PointDNS Developer to `big-dumb-web-dev`, Postgres Essential-0 instances to `head-up` and `nycycle-1`, and the three add-ons above to `rdjessee`. These other apps and their add-ons are outside the RDJesseeBlog conversion and must not be included in its teardown.

## Redeploy or roll back to Heroku

### While the existing app is retained

The fastest rollback is the DNS-only procedure in [STATIC-CUTOVER-AND-HEROKU-ROLLBACK.md](STATIC-CUTOVER-AND-HEROKU-ROLLBACK.md): restore the `www` CNAME to Heroku's current custom-domain target, wait for DNS/TLS, and verify the Heroku app. Do not change the apex forwarding, email DNS records, S3 bucket, or CloudFront distribution. The default `rdjessee.herokuapp.com` endpoint currently responds, and the database, release, dyno, and add-ons still exist.

### If the app must be rebuilt after deletion

1. Restore the source at Heroku's last known release commit `b7071c27` (or a reviewed later Rails commit) from the repository. Confirm the Ruby/Rails lockfile, asset build, release command, and `heroku-24` stack before creating a new release. Keep the static publishing scripts out of Heroku's release steps.
2. Create a new app in the US region and provision PostgreSQL Essential-0. Restore a fresh verified Heroku-format dump with `heroku pg:backups:restore`; `b039` is a local recovery point, but capture and restore the latest approved data backup if any later data exists. This backup contains PostgreSQL data, not S3 media.
3. Reprovision compatible Searchbox/Elasticsearch and SendGrid services if they are still available and still required. The Rails app expects the `SEARCHBOX_URL`/`SEARCHBOX_SSL_URL` and `SENDGRID_USERNAME`/`SENDGRID_PASSWORD` settings; the old add-on identifiers and credentials do not guarantee that the vendors will retain these services indefinitely. If unavailable, plan code changes for local search or a replacement mail provider.
4. Configure the ordered buildpacks recorded above, the `heroku-24` stack, one Basic web dyno, and the Rails production release command. Restore only required secrets through Heroku config after retrieving them from the password manager or rotating them. Do not copy this document's variable names as secret values.
5. Restore Active Storage access to `andre-pictures` using a current least-privilege AWS identity. S3 and CloudFront are independent of Heroku and were not part of this teardown. Verify that required bucket objects exist and are readable before enabling writes.
6. Add `www.ralphdonaldjessee.com` to the rebuilt Heroku app, update the Squarespace CNAME to the new Heroku-provided target, and wait for Heroku ACM issuance. Verify DNS, TLS, `/up`, homepage, stories, pictures, audio, login, and an authorized admin edit before treating the Rails service as recovered.

If Heroku no longer offers a compatible legacy Searchbox/SendGrid plan, restoring only the app and database will not recreate the old behavior. Keep the verified static Pages release available while working through replacement services.

## Teardown sequence (deferred)

The static Pages site is live, but keep Heroku during the agreed rollback window. When ready to retire it, work through these gates in order. This plan has **not** been executed.

1. **Accept the static release.** Confirm the content owner can create and publish from the local authoring database, verify all public media and routes on Pages, confirm the domain and SSL remain Active, and decide that new comments/uploads/admin edits are no longer expected on the public site. Keep the documented DNS rollback path through the chosen observation period.
2. **Preserve recovery material.** Capture a final Heroku Postgres backup, download it, verify its archive format and restore it to a new isolated local database. Retain the earlier `b039` dump and a final dump privately outside Git. Save necessary non-recoverable secrets in the password manager, record the exact Heroku source commit and release, and verify the S3/CloudFront origin and Pages deployment independently.
3. **Retire the Heroku hostname association.** After the rollback window, remove only the Heroku custom-domain attachment with `heroku domains:remove www.ralphdonaldjessee.com --app rdjessee`. Pages DNS already serves `www`; leave Squarespace nameservers, apex forwarding, mail records, and DNSSEC alone. Verify the Pages host again.
4. **Stop the app and remove add-ons.** Scale the Heroku web formation to zero to stop the $7/month dyno. If the app is being fully deleted, remove the Searchbox and SendGrid add-ons and finally the PostgreSQL add-on after verifying the final dump is retained. Review Heroku's confirmation prompt and verify the exact add-on names before each `heroku addons:destroy` action.
5. **Delete the app only when the recovery decision is final.** `heroku apps:destroy --app rdjessee --confirm rdjessee` removes the app, its release history, config vars, buildpacks, and domain association. This is the final irreversible step for the Heroku app. It does not delete the separate S3 bucket, CloudFront distribution, Cloudflare Pages project, Squarespace DNS zone, or other Heroku apps.
6. **Check billing and unrelated resources.** Re-run `heroku apps --all` and `heroku addons --all`; confirm only the `rdjessee` resources were removed and other apps/add-ons remain. Review the next invoice for the expected reduction (up to about $12/month for the current dyno and database), then verify public Pages hosting and media once more.

Do not destroy `andre-pictures`, its objects, CloudFront distribution `E1KFB1NQNA9XY4`, the Pages project, or any other Heroku app as part of this plan. Media cleanup in S3 remains separately deferred.
