require 'rails_helper'

RSpec.describe EditorHelper, type: :helper do
  it 'keeps existing HTML in the form field and links the Trix editor to it' do
    story = Story.new(content: '<div>A memory & a story</div>')
    html = helper.form_for(story) { |form| helper.plain_html_editor(form, :content, class: 'editor') }
    fragment = Nokogiri::HTML.fragment(html)
    input = fragment.at_css('input[name="story[content]"]')
    expect(input['value']).to eq(story.content)
    expect(fragment.at_css('trix-editor')['input']).to eq(input['id'])
    expect(fragment.at_css('trix-editor')['class']).to eq('editor')
  end
end
