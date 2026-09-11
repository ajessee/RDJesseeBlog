class UsersController < ApplicationController
  before_action :logged_in_user, only: [:index, :edit, :update, :destroy]
  before_action :correct_user, only: [:edit, :update], unless: -> { action_name == "update" && request.xhr? }
  before_action :admin_user, only: :destroy

  def index
    @users = User.paginate(page: params[:page])
  end

  def show
    @user = User.find(params[:id])
  end

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    if @user.save
      @user.send_activation_email
      flash[:info] = "Please check your email to activate your account."
      redirect_to "/#flash"
    else
      render 'new'
    end
  end

  def edit
    @user = User.find(params[:id])
  end

  def update
    if request.xhr?
      return head :forbidden unless current_user.admin?
      attribute = params[:attributeToUpdate]
      value = params[:attributeValue].to_s.downcase
      return head :bad_request unless %w[admin activated].include?(attribute) && %w[true false 1 0].include?(value)

      @user = User.find(params[:id])
      if @user.update(attribute => ActiveModel::Type::Boolean.new.cast(value))
        render plain: 'Change'
      else
        head :unprocessable_content
      end
    else
      @user = User.find(params[:id])
      if @user.update(user_params)
        flash[:success] = "Profile updated"
        redirect_to "/#flash"
      else
        render 'edit'
      end
    end
  end

  def destroy
    User.find(params[:id]).destroy
    flash[:success] = "User deleted"
    redirect_to admin_users_path
  end

  private

    def user_params
      params.require(:user).permit(:name, :email, :password, :password_confirmation)
    end

    #before filters

    def correct_user
      @user = User.find(params[:id])
      redirect_to(root_url) unless current_user?(@user)
    end

    # Confirms an admin user.
    def admin_user
      redirect_to(root_url) unless current_user.admin?
    end

end
