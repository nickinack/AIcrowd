class NotificationService
  include Rails.application.routes.url_helpers
  include ActionView::Helpers::AssetTagHelper

  def initialize(participant_id, notifiable, notification_type)
    @participant       = Participant.find(participant_id)
    @notifiable        = notifiable
    @notification_type = notification_type
  end

  def call
    send(@notification_type) if ['graded', 'failed'].include?(@notification_type)
  end

  private

  def graded
    score   = @notifiable.score
    message = "Your Learning how to walk submission has been graded with a score of #{score}"
    thumb   = image_url(@notifiable.challenge)
    link    = challenge_url(@notifiable.challenge)
    Notification
      .create!(
        participant:       @participant,
        notifiable:        @notifiable,
        notification_type: @notification_type,
        message:           message,
        thumbnail_url:     thumb,
        notification_url:  link,
        is_new:            true)
  end

  def failed
    message = 'Your Learning how to walk submission has failed grading'
    thumb   = image_url(@notifiable.challenge)
    link    = challenge_url(@notifiable.challenge)
    Notification
      .create!(
        participant:       @participant,
        notifiable:        @notifiable,
        notification_type: @notification_type,
        message:           message,
        thumbnail_url:     thumb,
        notification_url:  link,
        is_new:            true)
  end
end
