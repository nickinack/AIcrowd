class OngoingLeaderboard < SqlView
  self.primary_key = :id
  after_initialize :readonly!

  include PolymorphicSubmitter
  include FreezeRecord

  belongs_to :challenge
  belongs_to :challenge_round

  default_scope { order(seq: :asc) }
end
