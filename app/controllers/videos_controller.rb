class VideosController < ApplicationController
  before_action :logged_in_user, only: [:create, :destroy, :new, :edit, :update]

  before_action :correct_user, only: [:edit, :update, :destroy]

  def new
    @video = current_user.videos.new
  end

  def create
   @video = current_user.videos.build(video_params.merge(user_id: current_user.id))
   if @video.save
     flash.now[:success] = "video uploaded successfully!"
     render :show
   else
     render 'new', status: :unprocessable_entity
   end
  end

 def index
   @videos = Video.all.order(created_at: :asc).paginate(:page => params[:page], :per_page => 6)
 end

 def show
   @video = Video.find(params[:id])
 end

 def edit
   @video = Video.find(params[:id])
 end

 def update

 end


 def destroy
   @video.destroy
   flash[:success] = "Story deleted"
   redirect_to request.referrer || root_url
 end

 private

 def correct_user
   @video = Video.find(params[:id])
   redirect_to(root_url) unless @video.user_id == current_user.id || current_user.admin?
 end

 def video_params
   params.require(:video).permit(:caption, :year, :video_file)
 end

end
