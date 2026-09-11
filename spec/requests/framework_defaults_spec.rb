require 'rails_helper'

RSpec.describe 'Rails default compatibility', type: :request do
  let!(:user) do
    User.create!(name: 'Remembered Reader', email: 'remembered@example.test',
                 password: 'password', activated: true)
  end

  it 'loads Rails 8.1 defaults with the documented cookie-key exception' do
    expect(Rails.application.config.loaded_config_version).to eq(8.1)
    expect(Rails.application.config.active_support.key_generator_hash_digest_class)
      .to eq(OpenSSL::Digest::SHA1)
  end

  it 'restores a login from permanent remember-me cookies after the session cookie is removed' do
    post login_path, params: {
      session: { email: user.email, password: 'password', remember_me: '1' }
    }
    expect(user.reload.remember_digest).to be_present

    cookies.delete(Rails.application.config.session_options[:key])
    get edit_user_path(user)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(user.email)
  end

  it 'reads a permanent signed cookie written with the Rails 6 metadata format' do
    user.remember
    serialized_user_id = ActiveSupport::Messages::SerializerWithFallback[:json].dump(user.id)
    signing_key = Rails.application.key_generator.generate_key(
      Rails.application.config.action_dispatch.signed_cookie_salt
    )
    verifier = ActiveSupport::MessageVerifier.new(
      signing_key,
      digest: Rails.application.config.action_dispatch.signed_cookie_digest,
      serializer: ActiveSupport::MessageEncryptor::NullSerializer
    )

    current_metadata_format = ActiveSupport::Messages::Metadata.use_message_serializer_for_metadata
    begin
      ActiveSupport::Messages::Metadata.use_message_serializer_for_metadata = false
      cookies[:user_id] = verifier.generate(
        serialized_user_id, expires_at: 20.years.from_now, purpose: 'cookie.user_id'
      )
    ensure
      ActiveSupport::Messages::Metadata.use_message_serializer_for_metadata = current_metadata_format
    end
    cookies[:remember_token] = user.remember_token

    get edit_user_path(user)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(user.email)
  end

  it 'returns to a same-host protected URL after login' do
    get edit_user_path(user)
    expect(response).to redirect_to(login_url)

    post login_path, params: { session: { email: user.email, password: 'password' } }
    expect(response).to redirect_to(edit_user_url(user))
  end

  it 'does not redirect to an external Referer after a destructive action' do
    comment = Comment.create!(author: user, commentable: user, content: 'A memory')
    post login_path, params: { session: { email: user.email, password: 'password' } }

    delete comment_path(comment), headers: { 'HTTP_REFERER' => 'https://attacker.example/leave' }

    expect(response).to redirect_to(root_url)
    expect(Comment.exists?(comment.id)).to be(false)
  end
end
