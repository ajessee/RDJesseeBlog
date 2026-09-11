require 'rails_helper'

RSpec.describe Story, type: :model do
  it 'returns empty filter options without stories' do
    expect(Story.all_years).to eq([])
    expect(Story.all_life_stages).to eq([])
  end

  it 'reflects edited and removed metadata without retaining values across requests' do
    author = FactoryBot.create(:user)
    story = Story.create!(user: author, title: 'Memory', content: 'A memory',
                          location: 'Virginia', life_stage: 'Childhood')
    expect(Story.all_locations).to eq(['Virginia'])
    expect(Story.all_life_stages).to eq(['Childhood'])
    story.update!(location: 'Tennessee', life_stage: nil)
    expect(Story.all_locations).to eq(['Tennessee'])
    expect(Story.all_life_stages).to eq([])
  end
end
