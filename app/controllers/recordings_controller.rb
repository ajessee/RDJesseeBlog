class RecordingsController < ApplicationController
  before_action :logged_in_user, only: [:new, :create, :edit, :update, :destroy, :retry_conversion]
  before_action :correct_user, only: [:edit, :update, :destroy, :retry_conversion]

  def new
    @recording = Recording.new
  end

  def index
    @stories_with_recordings = Story.joins(:recordings).order(title: :asc).paginate(:page => params[:story_recordings], :per_page => 4)
    @user_recordings = Recording.where(recordable_type: "User").paginate(:page => params[:user_recordings], :per_page => 6)
  end

  rescue_from Recording::AudioConversionError, with: :conversion_failed

  def create
    parent = story_params[:story_id].present? ? Story.find(story_params[:story_id]) : current_user
    @recording = parent.recordings.build(recording_params)
    if @recording.audio_file.attached? && @recording.save
      recording_saved
    else
      @recording.errors.add(:audio_file, 'must be selected') unless @recording.audio_file.attached?
      respond_to do |format|
        format.json { render json: { error: @recording.errors.full_messages.to_sentence }, status: :unprocessable_entity }
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def retry_conversion
    @recording.process_audio!
    recording_saved
  end

  def show
  end

  def edit
  end

  def destroy
    @recording = Recording.find(delete_params)
    if @recording.recordable_type == "Story"
      @story = Story.find(@recording.recordable_id)
      @recording.destroy
      redirect_to story_path(@story)
    elsif @recording.recordable_type == "User"
      @recording.destroy
      flash[:success] = "Recording deleted successfully!"
      redirect_to recordings_path
    end

  end

  def update
  end

  private

  def recording_destination
    @recording.recordable_type == 'Story' ? story_path(@recording.recordable_id) : recordings_path
  end

  def recording_saved
    respond_to do |format|
      format.json { render json: { redirect_url: recording_destination } }
      format.html { redirect_to recording_destination, notice: 'Recording uploaded successfully!' }
    end
  end

  def conversion_failed
    message = 'The original audio was saved, but conversion failed. You can retry conversion from the recording page.'
    respond_to do |format|
      format.json { render json: { error: message, redirect_url: recording_destination }, status: :unprocessable_entity }
      format.html { redirect_to recording_destination, alert: message }
    end
  end

  def correct_user
    @recording = Recording.find(params[:id])
    redirect_to(root_url) unless @recording.user_id == current_user.id || current_user.admin?
  end

  def delete_params
    params.require(:id)
  end

  def recording_params
    params.require(:recording).permit(:caption, :audio_file).merge(user_id: current_user.id)
  end

  def story_params
    params.require(:recording).permit(:story_id)
  end


end
