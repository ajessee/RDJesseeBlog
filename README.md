![RDJessee](https://s3.amazonaws.com/andre-pictures/grandpaSigBlack.jpg)
 
# [Ralph Donald Jessee Blog](https://ralphdonaldjessee.com/) 
 
My grandfather, Ralph 'Don' Jessee, lived most of his life in Lima, Ohio. Late in his life, after his third wife died, his daughter Catherine invited him to live with her in Lafayette, Louisiana. After he moved down there, she enrolled him in a life writing class and much to everyone's surprise, he wrote prolifically. When he died in 2016, he left behind a collection of over 170 stories.
 
I built this web application as a platform to share these stories with his extended family and preserve his writing legacy for posterity. It's also a place to share pictures of his life, and users can signup to share their own personal memories of Don. 
 
The app is written in Rails 6 and currently deployed in production using Heroku.
 
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
* Secure user sign-in with administrative panel to manage users and stories
* User activation email upon user sign-up to ensure that user owns email address
* Automatic password reset feature via email
  
## Technical Specifications
 
* Written in Rails 6.
* Hosted on Heroku
* Uses Heroku SendGrid to deliver send user activation emails, password reset emails, or any other communication
* Uses Heroku Postgres and PostgresQL database for data persistence to store user information
* Uses AWS Simple Storage Service (S3) to store web application assets
* Uses Google Analytics to monitor and analyze traffic, bounce rates, and page views
* Uses Bootstrap framework for front end design

## Change Log

### Major Refactoring May 2020
* Upgraded to Rails 6 
* Migrate from AWS to Heroku for hosting
* Added feature to allow users to record story readings in-browser
* Added Elasticsearch to allow users to search stories for specific text
* Add table sorting feature to user admin table, story admin table, tags table
### August 2020
* Update all yarn package and Rails gems 
