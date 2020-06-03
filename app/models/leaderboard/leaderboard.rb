class Leaderboard < SqlView
  self.primary_key = :id
  after_initialize :readonly!

  include PolymorphicSubmitter
  belongs_to :challenge
  belongs_to :challenge_round
  belongs_to :submission

  default_scope { order(seq: :asc) }

  def self.freeze_record(participant)
    return self if !participant.present? || participant_is_organizer(participant.email) || all.where(submitter_type: "Participant").pluck(:submitter_id).exclude?(participant.id)

    ch_round = first.challenge_round
    if ch_round.freeze_flag && freeze_time(ch_round, participant.id)
      freeze_beyond_time = Time.now.utc - ch_round.freeze_duration.to_i.hours

      participant_and_before_freeze_record = where("submitter_id = ? OR created_at < ?", participant.id, freeze_beyond_time)
      return participant_and_before_freeze_record
    end

    self
  end

  def self.participant_is_organizer(participant_email)
    organizers_email = first.challenge.organizers.flat_map { |organizer| organizer.participants }.pluck(:email)
    organizers_email.include?(participant_email)
  end

  def self.freeze_time(ch_round, participant_id)
    submission_time = ch_round.submissions.where(participant_id: participant_id).order(created_at: :desc).first.created_at
    Time.now.utc - submission_time < ch_round.freeze_duration * 60 * 60
  end
end
