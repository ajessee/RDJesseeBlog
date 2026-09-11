class Story < ApplicationRecord
  include MediaUploadValidation
  validate_media_upload :picture, types: MediaUploadValidation::IMAGE_TYPES, maximum: 20.megabytes
  belongs_to :user
  has_many :taggings, dependent: :destroy
  has_many :tags, through: :taggings, dependent: :destroy
  has_many :pictures, as: :imageable, dependent: :destroy
  accepts_nested_attributes_for :pictures, allow_destroy: true
  has_many :comments, as: :commentable, dependent: :destroy
  has_many :recordings, as: :recordable, dependent: :destroy
  accepts_nested_attributes_for :recordings, allow_destroy: true, reject_if: :all_blank
  has_many :videos, as: :videoable, dependent: :destroy
  accepts_nested_attributes_for :videos, allow_destroy: true
  validates :user_id, presence: true
  validates :title, presence: true
  validates :content, presence: true
  has_one_attached :picture

  include Elasticsearch::Model
  include Elasticsearch::Model::Callbacks

  def self.search(query)

    search_definition = {
      from: 0,
      size: 500,
      query: {
        multi_match: {
          query: query,
          fields: ['title', 'content']
        }
      },
      highlight: {
        pre_tags: ['<mark>'],
        post_tags: ['</mark>'],
        fields: {
          title: {number_of_fragments: 0},
          content: {},
        }
      },
      suggest: {
        text: query,
        title: {
          term: {
            size: 1,
            field: :title
          }
        },
        content: {
          term: {
            size: 1,
            field: :content
          }
        }
      }
    }

    if (query[0] == '"' || query[0] == "'") && (query[-1] == '"' || query[-1] == "'")
      search_definition[:query][:multi_match][:type] = 'phrase'
      search_definition.delete(:suggest)
    end
    __elasticsearch__.search(search_definition)
  end

  def as_indexed_json(options = nil)
    self.as_json( only: [ :title, :content ] )
  end

  def self.get_stories(page)
    Story.all.order(title: :asc).paginate(:page => page, :per_page => 6)
  end

  def self.order_by_year(year, page)
    Story.where(year_written: year.to_i).paginate(:page => page, :per_page => 6)
  end

  def self.order_by_decade(decade, page)
    Story.where(decade: decade.to_i).paginate(:page => page, :per_page => 6)
  end

  def self.order_by_location(location, page)
    Story.where(location: location).paginate(:page => page, :per_page => 6)
  end

  def self.order_by_genre(genre, page)
    Story.where(genre: genre).paginate(:page => page, :per_page => 6)
  end

  def self.order_by_category(category, page)
    Story.where(category: category).paginate(:page => page, :per_page => 6)
  end

  def self.order_by_life_stage(life_stage, page)
    Story.where(life_stage: life_stage).paginate(:page => page, :per_page => 6)
  end

  def self.get_stories_with_recordings(page)
    Story.joins(:recordings).order(title: :asc).paginate(:page => page, :per_page => 6)
  end

  def self.get_stories_with_comments(page)
    Story.joins(:comments).paginate(:page => page, :per_page => 6)
  end

  def self.order_by_tag(tag, page)
    Tag.find_by_name!(tag.strip).stories.paginate(:page => page, :per_page => 6)
  end

  def self.all_years
    distinct.where.not(year_written: nil).order(:year_written).pluck(:year_written)
  end

  def self.all_decades
    distinct.where.not(decade: nil).order(:decade).pluck(:decade)
  end

  def self.all_locations
    distinct.where.not(location: nil).pluck(:location).sort
  end

  def self.all_genres
    distinct.where.not(genre: nil).pluck(:genre).sort
  end

  def self.all_categories
    distinct.where.not(category: nil).pluck(:category).sort
  end

  def self.all_life_stages
    stages = distinct.where.not(life_stage: nil).pluck(:life_stage).sort
    # Preserve the original menu order when there are enough entries to swap.
    stages[1], stages[2] = stages[2], stages[1] if stages.length >= 3
    stages
  end

  def strip_divs
    self.title.to_s.gsub!("<div>", "")
    self.title.to_s.gsub!("</div>", "")
    self.content.to_s.gsub!("<div>", "")
    self.content.to_s.gsub!("</div>", "")
  end

  def all_tags=(names)
    self.tags = names.split(",").map do |name|
      Tag.where(name: name.strip).first_or_create!
    end
  end

  def all_tags
    self.tags.map(&:name).join(", ")
  end

  def get_wordcount
    self.word_count = self.content.to_s.scan(/[\w-]+/).size
  end

end
