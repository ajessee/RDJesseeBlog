# Read cookies derived with Rails 6's SHA-1 key generator while new cookies use
# the Rails 8.1 SHA-256 default. Remove this rotation only after every pre-upgrade
# cookie has expired.
Rails.application.config.after_initialize do
  Rails.application.config.action_dispatch.cookies_rotations.tap do |cookies|
    action_dispatch = Rails.application.config.action_dispatch
    legacy_key_generator = ActiveSupport::KeyGenerator.new(
      Rails.application.secret_key_base,
      iterations: 1000,
      hash_digest_class: OpenSSL::Digest::SHA1
    )
    key_length = ActiveSupport::MessageEncryptor.key_len

    legacy_encrypted_secret = legacy_key_generator.generate_key(
      action_dispatch.authenticated_encrypted_cookie_salt,
      key_length
    )
    legacy_signed_secret = legacy_key_generator.generate_key(
      action_dispatch.signed_cookie_salt
    )

    cookies.rotate :encrypted, legacy_encrypted_secret
    cookies.rotate :signed, legacy_signed_secret
  end
end
