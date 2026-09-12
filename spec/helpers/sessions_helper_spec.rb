require 'rails_helper'

# Specs in this file have access to a helper object that includes
# the SessionsHelper. For example:
#
# describe SessionsHelper do
#   describe "string concat" do
#     it "concats two strings with spaces" do
#       expect(helper.concat_strings("this","that")).to eq("this that")
#     end
#   end
# end
RSpec.describe SessionsHelper, type: :helper do
  let(:user) { FactoryBot.create(:user, activated: true) }

  describe "#log_in" do
    it "records the current time as the user's last login" do
      expect(user.last_login_at).to be_nil

      before_login = Time.current
      helper.log_in(user)

      expect(user.reload.last_login_at).to be_within(2.seconds).of(before_login)
    end

    it "updates last_login_at on every subsequent login" do
      helper.log_in(user)
      first_login = user.reload.last_login_at

      helper.log_in(user)

      expect(user.reload.last_login_at).to be >= first_login
    end
  end
end
