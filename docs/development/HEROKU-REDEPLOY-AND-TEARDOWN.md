# Heroku retirement and recovery record

Updated November 14, 2026 after retiring the `rdjessee` Heroku app. The app and its add-ons have been removed. This document records the pre-retirement inventory and the information needed to rebuild the Rails service if necessary. No other Heroku app was changed.

## Retirement result

The following operations completed for `rdjessee`:

1. Captured Heroku Postgres backup `b040` on November 14, 2026 at 00:48 UTC. The backup completed at 00:49 UTC, was downloaded to the ignored local `tmp/static-archive/production-b040.dump`, and its PostgreSQL archive listing was verified.
2. Restored `b040` to the separate local `rdjessee_blog_authoring` database. Verified 193 stories, 56 pictures, 39 recordings, 23 comments, and 271 Active Storage blobs. The previous authoring database remains as `rdjessee_blog_authoring_before_20261114_004924`.
3. Removed Heroku's `www.ralphdonaldjessee.com` custom-domain attachment and scaled the web formation to zero.
4. Destroyed the `searchbox-convex-81586`, `sendgrid-trapezoidal-14729`, and `postgresql-pointy-18109` add-ons.
5. Destroyed the `rdjessee` app.
6. Verified `rdjessee` no longer appears in the account app/add-on inventory. The unrelated apps `big-dumb-web-dev`, `head-up`, `nycycle-1`, and `sql-tutor-upgrade`, and collaborated app `magellan-investments`, remain. Their add-ons remain attached to their respective apps.
7. Verified `https://www.ralphdonaldjessee.com/` and `/stories/64.html` still return HTTP 200 from the static site.

The Pages project, Squarespace DNS zone, S3 bucket `andre-pictures`, CloudFront distribution `E1KFB1NQNA9XY4`, and all other Heroku apps were left in place. The local `b040` dump is private, owner-readable only, and ignored by Git. Retain it and the earlier `b039` dump outside Git. The dump contains PostgreSQL data, not S3 media or secrets.

## Pre-retirement infrastructure inventory

This inventory was captured November 13, 2026, immediately before retirement.

| Resource | Pre-retirement value |
| --- | --- |
| Heroku app | `rdjessee`, owned by `andre.isaac.jessee@gmail.com`, US region, `heroku-24` stack |
| App URL | `https://rdjessee.herokuapp.com/` |
| Web formation | One `Basic` web dyno, running `bin/rails server -p ${PORT:-5000} -e $RAILS_ENV` |
| Release | `v171`, commit `b7071c27` (`Track and display each user's last login time`), deployed September 12, 2026 |
| Buildpacks | `heroku-buildpack-activestorage-preview`, `heroku/nodejs`, `heroku/ruby` |
| PostgreSQL | `postgresql-pointy-18109`, `essential-0`, PostgreSQL 17.10; attached as `DATABASE` |
| Final backup | `b040`, completed November 14, 2026 at 00:49 UTC, 387.22 KB; downloaded and restored locally |
| Search | `searchbox-convex-81586`, `searchbox:starter`; attached as `SEARCHBOX` |
| Email | `sendgrid-trapezoidal-14729`, `sendgrid:starter`; attached as `SENDGRID` |
| Heroku custom domain | `www.ralphdonaldjessee.com`, target `www.ralphdonaldjessee.com.herokudns.com`; detached during retirement |

The deleted app had config variable names `AWS_ACCESS_KEY_ID`, `AWS_REGION`, `AWS_SECRET_ACCESS_KEY`, `DATABASE_URL`, `LANG`, `NODE_OPTIONS`, `RACK_ENV`, `RAILS_ENV`, `RAILS_MASTER_KEY`, `RAILS_SERVE_STATIC_FILES`, `SEARCHBOX_SSL_URL`, `SEARCHBOX_URL`, `SECRET_KEY_BASE`, `SENDGRID_PASSWORD`, `SENDGRID_USERNAME`, and three `TURNSTILE_*` variables. Secret values were not printed or copied. The old Heroku config and credentials were removed with the app; retrieve any still-needed secrets from the password manager or rotate them. Do not reuse the old long-lived AWS keys. Local publishing uses the short-lived `RDJesseeStaticSiteSetup` role described in [AWS static media publishing](AWS-STATIC-MEDIA-PUBLISHING.md).

Before retirement, the Basic dyno and Essential-0 database represented up to about $12/month before taxes and other account charges. Searchbox and SendGrid showed free plans. Actual billing is prorated; check the next Heroku invoice to confirm the charges stopped.

## Rebuilding Rails on Heroku

Heroku is no longer a DNS-only rollback option. A return to dynamic Rails requires provisioning new infrastructure, restoring the database, reconfiguring integrations, and changing DNS only after the replacement is verified. The static Pages site remains available during that work.

1. Restore the Rails source from the repository at the pre-retirement release commit `b7071c27`, or use a reviewed later Rails commit. Confirm the Ruby/Rails lockfile, asset build, release command, and `heroku-24` compatibility. Keep static publishing scripts out of Heroku release steps.
2. Create a new Heroku app in the US region and provision PostgreSQL. Restore the private `b040` dump into the new database using a supported PostgreSQL restore workflow. The local archive has been verified and the authoring database restore succeeded. The dump does not include S3 media.
3. Reprovision Searchbox/Elasticsearch and SendGrid only if they are still available and required. The Rails app expects `SEARCHBOX_URL`/`SEARCHBOX_SSL_URL` and `SENDGRID_USERNAME`/`SENDGRID_PASSWORD`; the old add-on instances and credentials no longer exist. If compatible services are unavailable, replace those integrations in the Rails app.
4. Configure the prior buildpacks, stack, release command, and required application settings. Retrieve secrets from the password manager or rotate them. Do not restore the removed AWS access keys; use a current least-privilege identity for any required Rails media access.
5. Verify the rebuilt app, database, login, archive routes, and S3/CloudFront media before routing users to it.
6. Add `www.ralphdonaldjessee.com` to the new app and wait for Heroku ACM/TLS. Only then change the Squarespace `www` CNAME from `rdjessee-blog-preview.pages.dev` to the new Heroku target. Leave the apex forwarding, nameservers, mail records, DNSSEC, S3 bucket, CloudFront distribution, and Pages deployment unchanged.

## Deferred cleanup

S3 media inventory cleanup remains deferred. Do not delete `andre-pictures`, its objects, CloudFront distribution `E1KFB1NQNA9XY4`, the Pages project, the Squarespace DNS zone, or any unrelated Heroku app as part of the completed Heroku retirement.
