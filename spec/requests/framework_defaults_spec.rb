require 'rails_helper'

RSpec.describe 'Rails default compatibility', type: :request do
  let!(:user) do
    User.create!(name: 'Remembered Reader', email: 'remembered@example.test',
                 password: 'password', activated: true)
  end

  def legacy_key_generator
    ActiveSupport::KeyGenerator.new(
      Rails.application.secret_key_base,
      iterations: 1000,
      hash_digest_class: OpenSSL::Digest::SHA1
    )
  end

  it 'loads Rails 8.1 defaults with legacy cookie rotations' do
    expect(Rails.application.config.loaded_config_version).to eq(8.1)
    expect(Rails.application.config.active_support.key_generator_hash_digest_class)
      .to eq(OpenSSL::Digest::SHA256)
    expect(Rails.application.config.action_controller.per_form_csrf_tokens).to be(true)
    expect(Rails.application.config.action_controller.forgery_protection_origin_check).to be(true)
    expect(Rails.application.config.active_record.belongs_to_required_by_default).to be(true)
    expect(Rails.application.config.action_dispatch.cookies_rotations.signed).not_to be_empty
    expect(Rails.application.config.action_dispatch.cookies_rotations.encrypted).not_to be_empty
  end

  it 'accepts its own login form while rejecting the same token from another origin' do
    original_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    get login_path
    token = Nokogiri::HTML(response.body).at_css('input[name="authenticity_token"]')&.[]('value')
    expect(token).to be_present

    post login_path, params: {
      authenticity_token: token,
      session: { email: user.email, password: 'password' }
    }, headers: { 'HTTP_ORIGIN' => 'http://www.example.com' }
    expect(response).to redirect_to('/#flash')

    reset!
    get login_path
    token = Nokogiri::HTML(response.body).at_css('input[name="authenticity_token"]')&.[]('value')

    expect do
      post login_path, params: {
        authenticity_token: token,
        session: { email: user.email, password: 'password' }
      }, headers: { 'HTTP_ORIGIN' => 'https://attacker.example' }
    end.to raise_error(ActionController::InvalidAuthenticityToken)
  ensure
    ActionController::Base.allow_forgery_protection = original_forgery_protection
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
    signing_key = legacy_key_generator.generate_key(
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

  it 'reads an encrypted session cookie derived with the Rails 6 SHA-1 key generator' do
    action_dispatch = Rails.application.config.action_dispatch
    key_length = ActiveSupport::MessageEncryptor.key_len
    encryption_key = legacy_key_generator.generate_key(
      action_dispatch.authenticated_encrypted_cookie_salt,
      key_length
    )
    encryptor = ActiveSupport::MessageEncryptor.new(
      encryption_key,
      cipher: action_dispatch.encrypted_cookie_cipher,
      serializer: ActiveSupport::MessageEncryptor::NullSerializer
    )
    session_key = Rails.application.config.session_options[:key]
    session_data = ActiveSupport::Messages::SerializerWithFallback[:json].dump(
      session_id: SecureRandom.hex(16), user_id: user.id
    )

    current_metadata_format = ActiveSupport::Messages::Metadata.use_message_serializer_for_metadata
    begin
      ActiveSupport::Messages::Metadata.use_message_serializer_for_metadata = false
      cookies[session_key] = encryptor.encrypt_and_sign(
        session_data,
        purpose: "cookie.#{session_key}"
      )
    ensure
      ActiveSupport::Messages::Metadata.use_message_serializer_for_metadata = current_metadata_format
    end

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
