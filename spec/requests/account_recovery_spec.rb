require 'rails_helper'
require 'cgi'

RSpec.describe 'Account activation and password recovery', type: :request do
  before { ActionMailer::Base.deliveries.clear }

  def token_from(mail, resource)
    body = mail.text_part.body.decoded
    encoded = body.match(%r{/#{resource}/([^/]+)/edit}).captures.first
    CGI.unescape(encoded)
  end

  it 'activates a newly registered account through the non-delivering email link' do
    expect do
      post users_path, params: {
        user: {
          name: 'New Reader', email: 'new-reader@example.test',
          password: 'password', password_confirmation: 'password'
        }
      }
    end.to change(ActionMailer::Base.deliveries, :count).by(1)

    user = User.find_by!(email: 'new-reader@example.test')
    expect(user).not_to be_activated
    token = token_from(ActionMailer::Base.deliveries.last, 'account_activations')

    get edit_account_activation_path(token, email: user.email)

    expect(response).to redirect_to(user_path(user))
    expect(user.reload).to be_activated
    expect(user.activated_at).to be_present

    get edit_account_activation_path(token, email: user.email)
    expect(response).to redirect_to(root_url)
  end

  it 'resets a password through email and invalidates the token after one use' do
    user = User.create!(name: 'Reader', email: 'reader-reset@example.test',
                        password: 'old-password', activated: true)
    expect do
      post password_resets_path, params: { password_reset: { email: user.email } }
    end.to change(ActionMailer::Base.deliveries, :count).by(1)

    token = token_from(ActionMailer::Base.deliveries.last, 'password_resets')
    get edit_password_reset_path(token, email: user.email)
    expect(response).to have_http_status(:ok)

    patch password_reset_path(token), params: {
      email: user.email,
      user: { password: 'new-password', password_confirmation: 'new-password' }
    }

    expect(response).to redirect_to('/#flash')
    user.reload
    expect(user.authenticate('new-password')).to eq(user)
    expect(user.authenticate('old-password')).to be(false)
    expect(user.reset_digest).to be_nil
    expect(user.reset_sent_at).to be_nil

    patch password_reset_path(token), params: {
      email: user.email,
      user: { password: 'reused-password', password_confirmation: 'reused-password' }
    }
    expect(response).to redirect_to(root_url)
    expect(user.reload.authenticate('reused-password')).to be(false)
  end
end
