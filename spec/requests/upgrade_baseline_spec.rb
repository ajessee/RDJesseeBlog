require 'rails_helper'

RSpec.describe 'Upgrade baseline', type: :request do
  %w[/ /about /login /signup /blog /stories /pictures /recordings /videos].each do |path|
    it "renders #{path} without production services" do
      get path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('RDJ Blog')
    end
  end

  it 'preserves rich formatting while removing executable story markup' do
    author = FactoryBot.create(:user)
    story = Story.create!(user: author, title: '<em>Family memory</em>',
                          content: '<strong>Keep formatting</strong><img src="x" onerror="window.story_attack=1"><script>window.story_attack=2</script>')
    [root_path, blog_path, story_path(story)].each do |path|
      get path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('<strong>Keep formatting</strong>')
      expect(response.body).not_to include('onerror=', '<script>window.story_attack')
    end
  end

  it 'renders pagination and the second page of stories' do
    author = FactoryBot.create(:user)
    7.times { |index| Story.create!(user: author, title: "Memory #{index}", content: 'A memory') }
    get blog_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('page=2', 'class="pagination"')
    get blog_path, params: { page: 2 }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Memory 6')
    expect(response.body).not_to include('Memory 0')
  end

  it 'exposes the Rails health endpoint' do
    get rails_health_check_path
    expect(response).to have_http_status(:ok)
  end

  it 'renders an existing story and its rich text at its public URL' do
    author = FactoryBot.create(:user)
    story = Story.create!(user: author, title: 'An archived memory',
                          content: '<div>A <strong>family</strong> memory.</div>')
    get story_path(story)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('An archived memory', '<strong>family</strong>')
  end

  it 'renders the login form with the current submit label' do
    get login_path
    expect(response.body).to include('session[email]', 'session[password]', "Let&#39;s go!")
  end

  it 'accepts an activated account and permits its profile edit' do
    user = User.create!(name: 'Example Reader', email: 'reader@example.test',
                        password: 'password', activated: true)
    post login_path, params: { session: { email: user.email, password: 'password' } }
    expect(response).to redirect_to('/#flash')
    get edit_user_path(user)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('reader@example.test')
  end

  it 'keeps an unactivated account out of profile editing' do
    user = User.create!(name: 'Example Reader', email: 'pending@example.test', password: 'password')
    post login_path, params: { session: { email: user.email, password: 'password' } }
    get edit_user_path(user)
    expect(response).to redirect_to(login_url)
  end
end
