require 'rails_helper'

RSpec.describe 'Signup abuse prevention', type: :request do
  it 'renders the Turnstile widget when a site key is configured' do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('TURNSTILE_SITE_KEY').and_return('test-site-key')

    get signup_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('https://challenges.cloudflare.com/turnstile/v0/api.js')
    expect(response.body).to include('data-sitekey="test-site-key"')
  end

  it 'does not create a user or send mail when Turnstile rejects the request' do
    verifier = instance_double(TurnstileVerifier, verify: false)
    allow(TurnstileVerifier).to receive(:new).and_return(verifier)

    expect do
      post users_path, params: {
        user: {
          name: 'Synthetic Signup',
          email: 'blocked-signup@example.test',
          password: 'password',
          password_confirmation: 'password'
        },
        'cf-turnstile-response' => 'rejected-token'
      }
    end.not_to change(User, :count)

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include('Please verify that you are human and try again.')
    expect(ActionMailer::Base.deliveries).to be_empty
  end
end
