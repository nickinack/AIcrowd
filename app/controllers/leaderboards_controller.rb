class LeaderboardsController < ApplicationController
  before_action :authenticate_participant!, except: :index
  before_action :set_challenge, only: [:index, :export]
  before_action :set_current_round, only: [:index, :export]

  respond_to :js, :html

  def index
    @vote             = @challenge.votes.where(participant_id: current_participant.id).first if current_participant.present?
    @follow           = @challenge.follows.where(participant_id: current_participant.id).first if current_participant.present?
    @challenge_rounds = @challenge.challenge_rounds.started
    @post_challenge = true if @challenge.completed? && params[:post_challenge] == "true"
    @post_challenge = false if @challenge.meta_challenge?

    filter = {challenge_round_id: @current_round&.id.to_i, meta_challenge_id: nil}
    if @meta_challenge.present?
      filter[:meta_challenge_id] = @meta_challenge.id
    end

    @leaderboards = if @challenge.challenge == "NeurIPS 2019 : Disentanglement Challenge"
      DisentanglementLeaderboard
        .where(challenge_round_id: @current_round)
        .page(params[:page])
        .per(10)
        .order(:row_num)
    elsif @post_challenge
      policy_scope(OngoingLeaderboard)
        .where(filter)
        .freeze_record(current_participant)
        .page(params[:page])
        .per(10)
        .order(:seq)
    else
      policy_scope(Leaderboard)
        .where(filter)
        .freeze_record(current_participant)
        .page(params[:page])
        .per(10)
        .order(:seq)
    end
  end

  def export
    authorize @challenge, :export?

    @leaderboards = Leaderboard
      .where(challenge_round_id: params[:leaderboard_export_challenge_round_id].to_i)
      .order(:seq)

    csv_data = Leaderboards::CSVExportService.new(leaderboards: @leaderboards).call.value

    send_data csv_data,
              type:     'text/csv',
              filename: "#{@challenge.challenge.to_s.parameterize.underscore}_leaderboard_export.csv"
  end

  private

  def set_challenge
    @challenge = Challenge.friendly.find(params[:challenge_id])
    if params.has_key?('meta_challenge_id') and params[:meta_challenge_id] != params[:challenge_id]
      @meta_challenge = Challenge.includes(:organizers).friendly.find(params[:meta_challenge_id])
    elsif @challenge.meta_challenge
      params[:meta_challenge_id] = params[:challenge_id]
    end

    if !params.has_key?('meta_challenge_id')
      cp = ChallengeProblems.find_by(problem_id: @challenge.id)
      if cp.present?
        params[:meta_challenge_id] = Challenge.find(cp.challenge_id).slug
        redirect_to helpers.challenge_leaderboards_path(@challenge)
      end
    end
  end

  def set_current_round
    @current_round = if params[:challenge_round_id].present?
      @challenge.challenge_rounds.find(params[:challenge_round_id].to_i)
    else
      @challenge.active_round
    end
  end
end
