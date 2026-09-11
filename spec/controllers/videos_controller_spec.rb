require 'rails_helper'

RSpec.describe VideosController, type: :controller do
  it 'serves the public index' do
    get :index
    expect(response).to have_http_status(:ok)
  end

  { new: :get, create: :post, edit: :get, update: :patch, destroy: :delete }.each do |action, method|
    it "requires login for #{action}" do
      public_send(method, action, params: { id: 123 })
      expect(response).to redirect_to(login_url)
    end
  end
end
