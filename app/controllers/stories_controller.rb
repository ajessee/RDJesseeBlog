class StoriesController < ApplicationController
  before_action :logged_in_user, only: [:create, :destroy, :new, :edit]
  before_action :admin_user,   only: [:destroy, :edit]

  def new
    @story = Story.new
    @recordings = @story.recordings.new
  end

  def index
    @stories = Story.get_stories(params[:page])
    @active_button = "alphabetical"
    Story.get_metadata
    @years = Story.all_years
    @decades = Story.all_decades
    @locations = Story.all_locations
    @genres = Story.all_genres
    @categories = Story.all_categories
    @life_stages = Story.all_life_stages
  end

  def sort
    Story.get_metadata
    @years = Story.all_years
    @decades = Story.all_decades
    @locations = Story.all_locations
    @genres = Story.all_genres
    @categories = Story.all_categories
    @life_stages = Story.all_life_stages
    case params[:sort]
    when "year_written"
      @active_button = "year"
      @stories = Story.order_by_year(params[:year], params[:page])
      render 'index'
    when "decade"
      @active_button = "decade"
      @stories = Story.order_by_decade(params[:decade], params[:page])
      render 'index'
    when "location"
      @active_button = "location"
      @stories = Story.order_by_location(params[:location] , params[:page])
      render 'index'
    when "genre"
      @active_button = "genre"
      @stories = Story.order_by_genre(params[:genre] , params[:page])
      render 'index'
    when "category"
      @active_button = "category"
      @stories = Story.order_by_category(params[:category] , params[:page])
      render 'index'
    when "life_stage"
      @active_button = "life_stage"
      @stories = Story.order_by_life_stage(params[:life_stage] , params[:page])
      render 'index'
    when "has_recordings"
      @active_button = "has_recordings"
      @stories = Story.get_stories_with_recordings( params[:page])
      render 'index'
    when "has_comments"
      @active_button = "has_comments"
      @stories = Story.get_stories_with_comments( params[:page])
      render 'index'
    when "tag"
      @active_button = "tag"
      @stories = Story.order_by_tag(params[:tag] , params[:page])
      render 'index'
    end
  end

  def search
    Story.get_metadata
    @years = Story.all_years
    @decades = Story.all_decades
    @locations = Story.all_locations
    @genres = Story.all_genres
    @categories = Story.all_categories
    @life_stages = Story.all_life_stages
    story_ids = []
    @results = Story.search(search_params[:query])
    @results.each do |result|
      story_ids.push(result.id)
    end
    @stories = Story.where(id: story_ids).paginate(:page => params[:page], :per_page => 6)
    render 'index'
  end

  def show
    @story = Story.find(params[:id])
  end

  def edit
    @story = Story.find(params[:id])
    @all_tags = Tag.all
  end

  def update
    if request.xhr?
      @story = Story.find(params[:id])
      params[:attributeValue] = nil if params[:attributeValue] == ""
      if @story[params[:attributeToUpdate]].to_s != params[:attributeValue]
        if @story.update(params[:attributeToUpdate] => params[:attributeValue])
          @story.strip_divs
          @story.get_wordcount
          @story.save
          @value = @story[params[:attributeToUpdate]]
          render plain: "Change"
        end
      end
    else
      @story = Story.find(params[:id])
      helpers.clean_story_params(story_params, params)
      if @story.update(story_params)
        @story.strip_divs
        @story.get_wordcount
        @story.save
        flash[:success] = "Story updated"
        redirect_to @story
      else
        render 'edit'
      end 
    end

  end

  def create
    helpers.clean_story_params(story_params, params)
    @story = current_user.stories.build(story_params)
    @story.strip_divs
    @story.get_wordcount
    if @story.save
      flash.now[:success] = "Story created!"
      render :show
    else
      flash.now[:info] = "Oops, that didn't work"
      redirect_to "/#flash"
    end
  end

  def destroy
    @story = Story.find(delete_params)
    @story.destroy
    flash.now[:success] = "Story deleted"
    redirect_to request.referrer || root_url
  end

  private

  def story_params
    params.require(:story).permit(:title, :content, :year_written, :decade, :location, :genre, :category, :life_stage, :picture, :all_tags, recordings_attributes: [:caption, :audio_file] )
  end

  def search_params
    params.permit(:query, :commit)
  end

  def delete_params
    params.require(:id)
  end

  # Confirms an admin user.
  def admin_user
    redirect_to(root_url) unless current_user.admin?
  end

  def correct_user
    @story = current_user.stories.find_by(id: params[:id])
    redirect_to root_url if @story.nil?
  end

end
