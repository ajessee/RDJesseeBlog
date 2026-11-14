![RDJessee](https://s3.amazonaws.com/andre-pictures/grandpaSigBlack.jpg)
 
# [Ralph Donald Jessee Blog](https://ralphdonaldjessee.com/) 

Documentation: [roadmap](docs/development/ROADMAP.md) · [local Docker setup](docs/development/LOCAL-DEVELOPMENT.md) · [production Docker image](docs/development/PRODUCTION-DOCKER.md) · [security posture](docs/development/SECURITY-ACCEPTANCE.md) · [hosting options](docs/development/HOSTING-PLAN.md) · [static cutover and Rails recovery](docs/development/STATIC-CUTOVER-AND-HEROKU-ROLLBACK.md) · [Heroku retirement and recovery](docs/development/HEROKU-REDEPLOY-AND-TEARDOWN.md). Historical upgrade record: [docs/archive/](docs/archive/) ([upgrade plan](docs/archive/UPGRADE-PLAN.md), [Heroku rollout](docs/archive/HEROKU-DEPLOYMENT.md)).
 
My grandfather, Ralph 'Don' Jessee, lived most of his life in Lima, Ohio. Late in his life, after his third wife died, his daughter Catherine invited him to live with her in Lafayette, Louisiana. After he moved down there, she enrolled him in a life writing class and much to everyone's surprise, he wrote prolifically. When he died in 2016, he left behind a collection of over 170 stories.
 
I built this web application as a platform to share these stories with his extended family and preserve his writing legacy for posterity. The original Rails site also let visitors share pictures and memories. The public archive is now read-only; the Rails app runs locally for content authoring.
 
The public site runs as a static archive on Cloudflare Pages. Docker runs Rails locally as the content-authoring tool; publishing updates to Pages does not deploy a Rails app. The former Heroku app was retired on November 14, 2026.
 
## Original Rails application features

These describe the former interactive Rails site. The public Pages archive preserves the stories and read-only presentation but does not include sign-in, visitor submissions, or uploads.
 
* Mobile-first design
* Stories with comments, tagging, and picture thumbnails for story cards
* In-browser audio recording for users to record their own readings of Don's stories
* Upload audio files to stories if user wants to record on their own devices
* Section for stand-alone audio recordings for sharing memories or vignettes about Don
* Story filtering feature to organize alphabetically, by year written, decade story takes place in, location of story, genre of story, category of story, Don's life stage (early/mid/late), or stories with audio recordings
* Search story for words or phrases using Elasticsearch
* Tags to organize stories by categories or phrases
* Tag cloud which shows most used tags, sortable tag list to show all tags and stories with that tag
* Pictures page, with feature to allow users to upload their own pictures and comment on existing pictures
* Pagination for story and pictures index pages
* Rotating carousel feature for obituary
* Guestbook to allow users to leave memories or comments of Don on the main page
* Parallax scrolling
* HTTPS secure connection to protect sensitive user data
* Secure user sign-in with administrative panel to manage users and stories, including each user's last login time
* User activation email upon user sign-up to ensure that user owns email address
* Automatic password reset feature via email
* Cloudflare Turnstile bot protection on signup, enforced server-side

## Static site and local content authoring

The public site uses Cloudflare Pages for generated HTML, CSS, and JavaScript, with public media served from the existing S3 bucket through CloudFront. The production site is [www.ralphdonaldjessee.com](https://www.ralphdonaldjessee.com/). Pages uses direct uploads and is not connected to Git. The former Heroku app was retired on November 14, 2026; restoring Rails now requires rebuilding the service from the saved recovery materials. See the [cutover and recovery runbook](docs/development/STATIC-CUTOVER-AND-HEROKU-ROLLBACK.md).

The repo provides a separate local authoring database, cloned from the latest Heroku production backup (`b040`, November 14, 2026). It does not point Rails at the live Heroku database. The authoring copy is isolated from the synthetic development and release snapshot databases. To run Rails against it:

```sh
DEVELOPMENT_DATABASE=rdjessee_blog_authoring docker compose up -d db search
DEVELOPMENT_DATABASE=rdjessee_blog_authoring docker compose up web
```


Open http://localhost:3000 and sign in using an existing local authoring account. Existing images and recordings are downloaded from CloudFront into the local Docker media volume; Active Storage in this authoring database is switched to local disk. Emails are not sent from development. Do not run the Rails app against the Heroku URL.

The final Heroku snapshot is `b040`, retained privately at `tmp/static-archive/production-b040.dump`. To recreate the authoring database from this snapshot, run `bin/refresh-authoring-db b040`. The script restores the dump into an isolated temporary database, retains the prior authoring database under a timestamped name rather than deleting it, updates only the new local copy to use disk storage, and hydrates its referenced media. Heroku was retired after `b040`, so no newer Heroku backup can be captured. Refreshing does not merge local edits into the snapshot; keep working on the retained copy if it contains unpublished changes.

To publish from the current authoring database:

```sh
bin/publish-static-site preview
# Review the Pages preview, then publish to the live hostname:
bin/publish-static-site production
```

The script exports the authoring database, uploads only newly referenced media to the existing `andre-pictures` bucket, adds those exact keys to the CloudFront OAC allowlist, verifies media through CloudFront, builds the static site, and uploads it to the selected Pages branch. The export is private at `tmp/static-archive/export-cloudfront.json`; Pages output is in ignored `dist/static-site/`. Publishing is a Pages upload, not a Heroku deployment. AWS credentials are short-lived and passed to the Docker task from the `rdjessee-static-setup` CLI profile without saving them in the repo. The role has the narrowly scoped upload policy described in [AWS media publishing](docs/development/AWS-STATIC-MEDIA-PUBLISHING.md).
  
## Technical Specifications
 
* Written in Rails 8.1.3.1 on Ruby 4.0.6
* Public HTML, CSS, and JavaScript are hosted on Cloudflare Pages; images and audio stay in S3 and are delivered by CloudFront
* Rails 8.1.3.1 on Ruby 4.0.6 runs locally in Docker for authoring; the former Heroku app was retired November 14, 2026
* The local Rails app uses PostgreSQL and disk-backed Active Storage; its final production database snapshot is kept privately for recovery
* The former production app used Heroku Postgres and SendGrid; those services were removed during retirement
* Images are processed with libvips (Rails 8.1's default Active Storage variant processor), with untrusted/unhardened image loaders explicitly blocked (`Vips.block_untrusted`)
* Audio recordings and uploads are converted with ffmpeg to a consistent AAC/MP4 format regardless of the source browser's recording format (e.g. WebM/Opus)
* Uses Google Analytics to monitor and analyze traffic, bounce rates, and page views
* Uses Bootstrap framework for front end design
* The former Rails app used Elasticsearch (Searchbox); the static archive uses generated client-side search/filter data
* Security scanning via Brakeman (static analysis), bundler-audit and npm audit (dependency CVEs), and Docker Scout (OS/image CVEs) — see [docs/development/SECURITY-ACCEPTANCE.md](docs/development/SECURITY-ACCEPTANCE.md) for current accepted findings

## Change Log

### September 2026 — Last login tracking
* Added a `last_login_at` column to users, set on every password login and every remember-cookie re-authentication
* Admin user table now shows each user's last login ("Never" if they haven't logged in since this was added); no historical login data existed before this, in the database or in Heroku's logs

### September 2026 — Rails 6.1 → 8.1 modernization
* Upgraded Rails 6.1.3 → 8.1.3.1 and Ruby 3.0.0 → 4.0.6 through every intermediate major version (7.0, 7.1, 7.2, 8.0), adopting each version's framework defaults along the way rather than just bumping the gem
* Replaced Webpacker and `trix-rails` (both incompatible with modern Rails) with Sprockets-served npm packages; removed Spring, Pry/Byebug, and other unmaintained/unneeded dependencies
* Added a Docker-based local development environment (isolated Postgres, media, and non-delivering mail) and a separate hardened multi-stage production image
* Closed authorization gaps found during the upgrade: every write action now enforces server-side ownership/role checks, state-changing actions no longer ride on GET requests, and record ownership is derived from the session rather than trusted from submitted form fields
* Added Cloudflare Turnstile to signup to stop the bot-account abuse discovered during the upgrade (63 stale unverified accounts were cleaned up after explicit approval)
* Hardened image handling: libvips untrusted-loader blocking, upload size/type validation, and a retry path when audio/image conversion fails (originals are preserved either way)
* Added reproducible security scanning (Brakeman, bundler-audit, npm audit, Docker Scout) to the development workflow
* Deployed to Heroku's `heroku-24` stack via buildpacks; fixed a post-deploy regression where a years-old missing Active Storage migration (`active_storage_variant_records`) had never been applied to production, which broke all image rendering under Rails 8.1's stricter variant-tracking until corrected

### Major Refactoring May 2020
* Upgraded to Rails 6 
* Migrate from AWS to Heroku for hosting
* Added feature to allow users to record story readings in-browser
* Added Elasticsearch to allow users to search stories for specific text
* Add table sorting feature to user admin table, story admin table, tags table
### August 2020
* Update all yarn package and Rails gems 
