require 'rails_helper'

RSpec.describe 'Write authorization', type: :request do
  let!(:owner) { User.create!(name: 'Owner', email: 'owner@example.test', password: 'password', activated: true) }
  let!(:reader) { User.create!(name: 'Reader', email: 'reader@example.test', password: 'password', activated: true) }
  let!(:admin) { User.create!(name: 'Admin', email: 'admin@example.test', password: 'password', activated: true, admin: true) }
  let!(:picture) { Picture.create!(user_id: owner.id, imageable: owner, caption: 'Original') }
  let!(:recording) { Recording.create!(user_id: owner.id, recordable: owner, caption: 'Original') }
  let!(:video) { Video.create!(user_id: owner.id, videoable: owner, caption: 'Original') }

  def sign_in(user)
    post login_path, params: { session: { email: user.email, password: 'password' } }
  end

  it 'blocks anonymous story updates before looking up the record' do
    patch story_path(123), params: { story: { title: 'Changed' } }
    expect(response).to redirect_to(login_url)
  end

  it 'blocks non-admins from opening the new story form' do
    sign_in(reader)
    get new_story_path
    expect(response).to redirect_to(root_url)
  end

  it 'blocks non-admin story creation' do
    sign_in(reader)
    expect do
      post stories_path, params: { story: { title: 'Unauthorized story', content: 'No access' } }
    end.not_to change(Story, :count)
    expect(response).to redirect_to(root_url)
  end

  it 'attributes an admin-created story to the signed-in admin' do
    sign_in(admin)
    expect do
      post stories_path, params: { story: { title: 'Authorized story', content: 'A memory', user_id: owner.id } }
    end.to change(Story, :count).by(1)
    expect(response).to redirect_to(story_path(Story.last))
    expect(Story.last.user).to eq(admin)
  end

  it 'blocks non-admin story updates' do
    sign_in(reader)
    patch story_path(123), params: { story: { title: 'Changed' } }
    expect(response).to redirect_to(root_url)
  end

  it 'blocks non-admin story deletion' do
    story = Story.create!(user: owner, title: 'Original', content: 'A memory')
    sign_in(reader)
    delete story_path(story)
    expect(response).to redirect_to(root_url)
    expect(Story.exists?(story.id)).to be(true)
  end

  it 'blocks updates to another user profile' do
    sign_in(reader)
    patch user_path(owner), params: { user: { name: 'Changed' } }
    expect(response).to redirect_to(root_url)
    expect(owner.reload.name).to eq('Owner')
  end

  it 'prevents a user from promoting themselves through the admin AJAX endpoint' do
    sign_in(reader)
    patch user_path(reader), params: { attributeToUpdate: 'admin', attributeValue: 'true' }, xhr: true
    expect(response).to have_http_status(:forbidden)
    expect(reader.reload).not_to be_admin
  end

  it 'allows admins to activate accounts through the existing AJAX endpoint' do
    owner.update!(activated: false)
    sign_in(admin)
    patch user_path(owner), params: { attributeToUpdate: 'activated', attributeValue: 'true' }, xhr: true
    expect(response).to have_http_status(:ok)
    expect(owner.reload).to be_activated
  end

  it 'rejects arbitrary columns in the admin AJAX endpoint' do
    sign_in(admin)
    patch user_path(owner), params: { attributeToUpdate: 'name', attributeValue: 'false' }, xhr: true
    expect(response).to have_http_status(:bad_request)
    expect(owner.reload.name).to eq('Owner')
  end

  it 'blocks an anonymous picture update' do
    patch picture_path(picture), params: { picture: { caption: 'Changed' } }
    expect(response).to redirect_to(login_url)
    expect(picture.reload.caption).to eq('Original')
  end

  it 'blocks another user from updating a picture' do
    sign_in(reader)
    patch picture_path(picture), params: { picture: { caption: 'Changed' } }
    expect(response).to redirect_to(root_url)
    expect(picture.reload.caption).to eq('Original')
  end

  it 'allows a picture owner to edit the caption without transferring ownership' do
    sign_in(owner)
    patch picture_path(picture), params: { picture: { caption: 'Changed', user_id: reader.id } }
    expect(response).to redirect_to(picture)
    expect(picture.reload.caption).to eq('Changed')
    expect(picture.user_id).to eq(owner.id)
  end

  it 'blocks another user from deleting a picture' do
    sign_in(reader)
    delete picture_path(picture)
    expect(response).to redirect_to(root_url)
    expect(Picture.exists?(picture.id)).to be(true)
  end

  [:recording, :video].each do |kind|
    it "blocks anonymous #{kind} deletion" do
      item = public_send(kind)
      delete polymorphic_path(item)
      expect(response).to redirect_to(login_url)
      expect(item.class.exists?(item.id)).to be(true)
    end

    it "blocks another user's #{kind} deletion" do
      sign_in(reader)
      item = public_send(kind)
      delete polymorphic_path(item)
      expect(response).to redirect_to(root_url)
      expect(item.class.exists?(item.id)).to be(true)
    end

    [ :owner, :admin ].each do |role|
      it "allows #{role} to delete a #{kind}" do
        sign_in(public_send(role))
        item = public_send(kind)
        delete polymorphic_path(item)
        expect(response).to have_http_status(:redirect)
        expect(item.class.exists?(item.id)).to be(false)
      end
    end
  end

  it 'attributes a guestbook comment to the signed-in author' do
    sign_in(reader)
    post comments_path, params: { comment: { content: 'A memory', user_id: owner.id } }
    expect(response).to redirect_to('/#guestbook')
    expect(Comment.first.user_id).to eq(reader.id)
  end

  it 'does not mutate a comment through the edit GET request' do
    comment = Comment.create!(author: owner, commentable: owner, content: 'Original')
    sign_in(owner)
    get edit_comment_path(comment), params: { comment: { content: 'Changed' } }
    expect(response).to have_http_status(:ok)
    expect(comment.reload.content).to eq('Original')
  end

  it 'allows the author to update content without transferring authorship' do
    comment = Comment.create!(author: owner, commentable: owner, content: 'Original')
    sign_in(owner)
    patch comment_path(comment), params: { comment: { content: 'Changed', user_id: reader.id } }
    expect(response).to have_http_status(:redirect)
    expect(comment.reload.content).to eq('Changed')
    expect(comment.user_id).to eq(owner.id)
  end

  it 'blocks another user from updating a comment' do
    comment = Comment.create!(author: owner, commentable: owner, content: 'Original')
    sign_in(reader)
    patch comment_path(comment), params: { comment: { content: 'Changed' } }
    expect(response).to redirect_to(root_url)
    expect(comment.reload.content).to eq('Original')
  end

  it 'blocks another user from deleting a comment' do
    comment = Comment.create!(author: owner, commentable: owner, content: 'Original')
    sign_in(reader)
    delete comment_path(comment)
    expect(response).to redirect_to(root_url)
    expect(Comment.exists?(comment.id)).to be(true)
  end

  it 'blocks non-admin user deletion' do
    sign_in(reader)
    delete user_path(owner)
    expect(response).to redirect_to(root_url)
    expect(User.exists?(owner.id)).to be(true)
  end

  it 'attributes a personal recording to the signed-in user' do
    sign_in(reader)
    post recordings_path, params: { recording: { caption: 'A memory', user_id: owner.id, audio_file: Rack::Test::UploadedFile.new(Rails.root.join('spec/fixtures/files/sample.wav'), 'audio/wav') } }
    expect(response).to redirect_to(recordings_path)
    item = Recording.order(:id).last
    expect(item.user_id).to eq(reader.id)
    expect(item.recordable).to eq(reader)
  end
end
