class DynamicContentsController < ApplicationController
  before_action :set_challenge, only: :index
  before_action :set_challenge_rounds, only: :index
  before_action :set_vote, only: :index
  before_action :set_follow, only: :index

  def index; end

  private

  def set_challenge
    @challenge = Challenge.friendly.find(params[:challenge_id])
  end

  def set_challenge_rounds
    @challenge_rounds = @challenge.challenge_rounds.started
  end

  def set_vote
    @vote = @challenge.votes.where(participant_id: current_participant.id).first if current_participant.present?
  end

  def set_follow
    @follow = @challenge.follows.where(participant_id: current_participant.id).first if current_participant.present?
  end
end
