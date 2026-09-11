require 'rails_helper'

RSpec.describe UserMailer, type: :mailer do
  let(:user) { FactoryBot.create(:user) }

  it 'addresses activation mail to the user and includes the activation link' do
    mail = UserMailer.account_activation(user)
    expect(mail.subject).to eq('Account activation')
    expect(mail.to).to eq([user.email])
    expect(mail.from).to eq([ApplicationMailer.default[:from]])
    expect(mail.text_part.body.decoded).to include(user.activation_token, 'account_activations')
  end

  it 'addresses reset mail to the user and includes the reset link' do
    user.create_reset_digest
    mail = UserMailer.password_reset(user)
    expect(mail.subject).to eq('Password reset')
    expect(mail.to).to eq([user.email])
    expect(mail.from).to eq([ApplicationMailer.default[:from]])
    expect(mail.text_part.body.decoded).to include(user.reset_token, 'password_resets')
  end
end
