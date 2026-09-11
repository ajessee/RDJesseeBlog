require 'rails_helper'


RSpec.feature "Content check", :type => :feature do

  # subject {page}

  describe "signup page" do
    before { visit signup_path }

    it "should have the right info" do
    expect(page).to have_selector('h4', text: 'Signup For New Account')
    expect(page).to have_title(full_title('Sign up'))
    end
  end

  describe "signup" do
    before {visit signup_path}
    let(:submit) { "Sign me up!"}

    describe "with invalid information" do
      it "should not create user" do
        expect { click_button submit }.not_to change(User, :count)
      end
    end

    describe "with valid information" do
      before do
        fill_in "Name", with: "Example User"
        fill_in "Email", with: "user@example.com"
        fill_in "Password", with: "password"
        fill_in "Confirmation", with: "password"
      end

      it "should create user" do
        expect { click_button submit }.to change(User, :count).by(1)
      end
    end
  end

  describe "edit" do
    let(:user) { FactoryBot.create(:user, activated: true)}
    before do
      log_in user
      visit edit_user_path(user)
    end

    it "should have the correct information" do
      expect(page).to have_selector('h4', text: 'Update your profile')
      expect(page).to have_title(full_title('Edit user'))
      expect(page).to have_field('Email', with: user.email, readonly: true)
    end

    describe "with invalid information" do
      before do
        fill_in 'Name', with: ''
        click_button 'Save changes'
      end

      it { expect(page).to have_selector('div.alert.alert-danger') }
    end

    describe "with valid information" do
      let(:new_name) { "New Name" }
      let(:new_email) { "new@example.com"}

      before do
        fill_in "Name", with: new_name
        fill_in "Password", with: user.password
        fill_in "Confirmation", with: user.password
        click_button "Save changes"
      end

      it "should have the correct information" do
        expect(page).to have_selector('div.alert.alert-success')
        expect(page).to have_title("RDJ Blog")
        # expect(page).to have_link('Account')
        expect(user.reload.name).to eq(new_name)
        expect(user.reload.email).to eq("andre@andre.com")
      end
    end

  end

end
