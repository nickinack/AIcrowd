# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include Pundit
  rescue_from Pundit::NotAuthorizedError, with: :not_authorized_or_login
  after_action :participant_activity
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :set_paper_trail_whodunnit
  after_action :track_action
  before_action :store_user_location!, if: :storable_location?
  before_action :modify_params_for_meta_challenges

  def track_action
    properties         = { request: request.filtered_parameters }
    properties[:flash] = flash.to_json unless flash.empty?
    ahoy.track "Processed #{controller_name}##{action_name}", properties
  end

  def doorkeeper_unauthorized_render_options(error: nil)
    { json: { error: 'Not authorized' } }
  end

  def append_info_to_payload(payload)
    super
    payload[:request_id] = request.uuid
    payload[:user_id]    = current_user.id if current_user
  end

  private

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up) do |u|
      u.permit(:name, :email, :password, :password_confirmation, :remember_me,
               :agreed_to_terms_of_use_and_privacy,
               :agreed_to_marketing)
    end
  end

  def modify_params_for_meta_challenges
    if controller_name == "challenges"
      if params.has_key?('challenge_id')
        params[:meta_challenge_id] = params['challenge_id']
        params.delete('challenge_id')
      end
    end
    if params.has_key?('problem_id')
      if params.has_key?('challenge_id')
        if !params.has_key?('meta_challenge_id')
          params[:meta_challenge_id] = params[:challenge_id]
          params[:challenge_id] = params[:problem_id]
          params.delete('problem_id')
        end
      end
    end
  end

  def pundit_user
    current_participant
  end

  def current_user
    current_participant
  end

  def storable_location?
    request.get? && is_navigational_format? && !devise_controller? && !request.xhr? && params[:controller] != 'challenge_rules'
  end

  def store_user_location!
    store_location_for(:user, request.fullpath)
  end

  def after_sign_in_path_for(resource)
    unless current_participant.agreed_to_terms_of_use_and_privacy?
      flash[:notice] = 'We have changed the way we save email and notification preferences, please review them below'
      current_participant.update(agreed_to_terms_of_use_and_privacy: true)
      return participant_notifications_path(current_participant)
    end

    # Prioritise return path set by application logic
    if session.has_key?(:participant_return_to)
      return session['participant_return_to']
    end

    # Redirect based on available browsing history
    return stored_location_for(:user) || root_path
  end

  def participant_activity
    current_participant.try :touch
  end

  def not_authorized_or_login
    if current_participant
      not_authorized
    else
      request_login
    end
  end

  def request_login
    flash[:info] = 'Please log into AIcrowd to perform this action.'
    redirect_to new_participant_session_path
  end

  def not_authorized
    flash[:error] = 'You are not authorised to access this page.'
    redirect_to root_path
  end

  def terminate_challenge
    TerminateChallenges.new.call
  end

  def search_params
    params[:q]
  end

  def clear_search_index
    if params[:search_cancel]
      params.delete(:search_cancel)
      search_params&.each do |key, _param|
        search_params[key] = nil
      end
    end
  end

  # TODO: Investigate if we can get rid of this weird override of default settings
  def default_url_options
    if Rails.env.test?
      super
    else
      { host: ENV['DOMAIN_NAME'] || 'localhost:3000' }
    end
  end
end
