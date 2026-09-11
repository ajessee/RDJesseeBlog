require 'rails_helper'

RSpec.feature "Content check", :type => :feature do
  let(:base_title) { "RDJ Blog" }

  scenario "User sees 'Ralph Donald Jessee' when they visit welcome page" do
    visit "/welcome"
    expect(page).to have_content("Ralph 'Don' Jessee")
  end

  scenario "User sees 'RD Jessee Blog | Welcome' in title when they visit welcome page" do
    visit "/welcome"
    expect(page).to have_title(base_title)
  end

  scenario "User sees 'About' when they visit about page" do
    visit "/about"
    expect(page).to have_selector('h1', text: "About")
  end

  scenario "User sees 'RD Jessee Blog | About' in title when they visit welcome page" do
    visit "/about"
    expect(page).to have_title("#{base_title} | About")
  end

end



