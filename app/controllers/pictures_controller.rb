class PicturesController < ApplicationController
  before_action :logged_in_user, only: [:create, :destroy, :new, :edit]
  before_action :correct_user,   only: [:destroy, :edit]

  def new
    @picture = current_user.pictures.new
  end

  def create
    @picture = current_user.pictures.build(picture_params)
    @picture.strip_divs
    if @picture.save
      flash.now[:success] = "Picture uploaded successfully!"
      render :show
    else
      render 'new'
    end
  end

  def index
    @pictures = Picture.all.order(created_at: :asc).paginate(:page => params[:page], :per_page => 3)
  end

  def show
    @picture = Picture.find(params[:id])
  end

  def edit
    @picture = Picture.find(params[:id])
  end

  def update
    @picture = Picture.find(params[:id])
    if @picture.update(picture_params)
      @picture.strip_divs
      @picture.save
      flash[:success] = "Picture updated"
      redirect_to @picture
    else
      render 'edit'
    end 
  end

  def destroy
    @picture = Picture.find(params[:id])
    @picture.destroy
    flash[:success] = "Picture deleted"
    redirect_to request.referrer || root_url
  end

  private

  def picture_params
    params.require(:picture).permit(:caption, :picture, :user_id)
  end

  def correct_user
    @picture = Picture.find_by(id: params[:id])
    redirect_to(root_url) unless @picture.user_id == current_user.id || current_user.admin?
  end

end
