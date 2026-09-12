![RDJessee](https://s3.amazonaws.com/andre-pictures/grandpaSigBlack.jpg)
 
# [Ralph Donald Jessee Blog](https://ralphdonaldjessee.com/) 

Upgrade work: [plan and progress](UPGRADE-PLAN.md) · [local Docker setup](LOCAL-DEVELOPMENT.md) · [production Docker image](PRODUCTION-DOCKER.md) · [Heroku deployment](HEROKU-DEPLOYMENT.md) · [security posture](SECURITY-ACCEPTANCE.md).
 
My grandfather, Ralph 'Don' Jessee, lived most of his life in Lima, Ohio. Late in his life, after his third wife died, his daughter Catherine invited him to live with her in Lafayette, Louisiana. After he moved down there, she enrolled him in a life writing class and much to everyone's surprise, he wrote prolifically. When he died in 2016, he left behind a collection of over 170 stories.
 
I built this web application as a platform to share these stories with his extended family and preserve his writing legacy for posterity. It's also a place to share pictures of his life, and users can signup to share their own personal memories of Don. 
 
The app is written in Rails 8.1 and currently deployed in production using Heroku buildpacks. A separate multi-stage, non-root Docker image is maintained for local development and future hosting portability.
 
## Features
 
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
  
## Technical Specifications
 
* Written in Rails 8.1.3.1 on Ruby 4.0.6
* Hosted on Heroku (`heroku-24` stack) via buildpacks; a separate multi-stage, non-root Docker image supports local development and portability; migrations run as an explicit release step
* Uses Heroku SendGrid to deliver user activation emails, password reset emails, or any other communication
* Uses Heroku Postgres and PostgreSQL database for data persistence to store user information
* Uses AWS Simple Storage Service (S3) to store web application assets, served through Active Storage
* Images are processed with libvips (Rails 8.1's default Active Storage variant processor), with untrusted/unhardened image loaders explicitly blocked (`Vips.block_untrusted`)
* Audio recordings and uploads are converted with ffmpeg to a consistent AAC/MP4 format regardless of the source browser's recording format (e.g. WebM/Opus)
* Uses Google Analytics to monitor and analyze traffic, bounce rates, and page views
* Uses Bootstrap framework for front end design
* Uses Elasticsearch (Searchbox) for full-text story search
* Security scanning via Brakeman (static analysis), bundler-audit and npm audit (dependency CVEs), and Docker Scout (OS/image CVEs) — see [SECURITY-ACCEPTANCE.md](SECURITY-ACCEPTANCE.md) for current accepted findings

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
