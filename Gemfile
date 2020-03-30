source 'https://rubygems.org'

gem 'rails', '6.0'
gem 'sass-rails'
gem 'bootstrap-sass'
gem 'uglifier'
gem 'jquery-rails'
gem 'jbuilder'
gem 'sdoc', group: :doc
gem 'bcrypt'
gem 'trix-rails', require: 'trix'
gem 'will_paginate'
gem 'bootstrap-will_paginate'
gem 'aws-sdk-rails'
gem 'aws-sdk'
gem 'aws-sdk-s3'
gem 'carrierwave'           
gem 'carrierwave-aws'
gem 'mini_magick'          
gem 'font-awesome-sass'
gem 'simple_form'
gem 'pg'
gem 'bootsnap'
gem 'webpacker'
gem 'fog', require: 'fog/aws'

group :development do
  # Access an IRB console on exception pages or by using <%= console %> in views
  gem 'web-console'
  gem 'listen'
end

group :development, :test do
  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'spring'
  gem 'byebug'
  gem 'pry'
  gem 'faker'
  gem 'rspec-rails'
end

group :test do
  # don't know if I need these, they came with rails install
  # gem 'minitest-reporters'
  # gem 'mini_backtrace'
  # gem 'guard-minitest'
  gem 'factory_girl_rails'
  gem 'simplecov', :require => false
  gem 'capybara'
  gem 'launchy'
  gem 'shoulda-matchers'
end

group :production do
  gem 'rails_12factor'
  gem 'puma'
end
