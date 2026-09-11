include ApplicationHelper

module FeatureAuthentication
  def log_in(user)
    visit login_path
    fill_in 'Email', with: user.email
    fill_in 'Password', with: user.password
    click_button "Let's go!"
  end
end

RSpec.configure do |config|
  config.include FeatureAuthentication, type: :feature
end
