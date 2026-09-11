require 'rails_helper'

RSpec.feature "Authentication", :type => :feature do

  let(:base_title) { "RDJ Blog" }
  let(:user) {FactoryBot.create(:user, activated: true)}

  scenario "login with invalid information" do
    visit "/login"
    click_button "Let's go!"
    expect(page).to have_title("#{base_title} | Log in")
    expect(page).to have_css("div.alert.alert-danger", text: "Invalid")
  end

  scenario "after visiting another page" do
    visit "/"
    expect(page).to_not have_selector('div.alert.alert-danger')
  end

  scenario "with valid information" do
    log_in user

    expect(page).to have_title(base_title)
    # RackTest does not open the JavaScript dropdown menu.
    expect(page).to have_link("Settings", href: edit_user_path(user), visible: :all)
    expect(page).to have_link("Log out", href: logout_path, visible: :all)
    expect(page).to_not have_link('Sign up', href: logout_path)
    expect(page).to_not have_link('Log in', href: login_path)
  end

  # scenario "checking 'remember me' box creates user remember token" do
  #   visit "/login"
  #   fill_in "Email", with: user.email
  #   fill_in "Password", with: user.password
  #   check "session_remember_me"
  #   click_button "Let's go!"

  #   expect(user.remember_digest).to_not be_nil

  # end

end
