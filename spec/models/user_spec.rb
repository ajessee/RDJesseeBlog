require 'rails_helper'

RSpec.describe User, type: :model do

  let(:user) {FactoryBot.create(:user)}

  subject { user }

  it { should respond_to(:name) }
  it { should respond_to(:email) }
  it { should respond_to(:password_digest) }
  it { should respond_to(:password) }
  it { should respond_to(:password_confirmation) }
  it { should respond_to(:authenticate) }
  it { should respond_to(:remember_token)}

  it { should be_valid}

  describe "when name is not present" do
    before { user.name = " " }
    it { should_not be_valid }
  end

  describe "when email is not present" do
    before { user.email = " " }
    it { should_not be_valid }
  end

  describe "when name is too long" do
    before { user.name = "A" * 51 }
    it { should_not be_valid }
  end

  describe "when email format is invalid" do
    it "should be invalid" do
      addresses = %w[user@foo,com user_at_foo.org example.user@foo.foo@bar_baz.com foo@bar+baz.com]
      addresses.each do |invalid_address|
        user.email = invalid_address
        expect(user).to_not be_valid
      end
    end
  end

  describe "when email format is valid" do
    it "should be invalid" do
      addresses = %w[user@foo.COM A_US-ER@f.b.org frst.lst@foo.jp a+b@baz.cn]
      addresses.each do |valid_address|
        user.email = valid_address
        expect(user).to be_valid
      end
    end
  end

  describe "when email address is already taken" do
    it "should be invalid" do
      user2 = user.dup
      user2.save
      expect(user2).to_not be_valid
    end
  end

  describe "when password is not present" do
    it "should be invalid" do
      user.password = user.password_confirmation = " "
      expect(user).to_not be_valid
    end
  end

  describe "when password and confirmation do not match" do
    it "should be invalid" do
      user.password_confirmation = "mismatch"
      expect(user).to_not be_valid
    end
  end

  describe "when password is too short" do
    it "should be invalid" do
      user.password = user.password_confirmation = "a" * 5
      expect(user).to_not be_valid
    end
  end

  describe "authenticate method returns correct user" do
    before {user.save}
    let(:found_user) { User.find_by_email(user.email) }
    let(:user_for_invalid_password) { found_user.authenticate("invalid") }

    it "works with valid password" do
      user == found_user.authenticate(user.password)
    end

    it "fails with invalid password" do
      user != user_for_invalid_password
    end
  end

end
