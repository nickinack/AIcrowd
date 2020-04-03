module ChallengeRounds
  class CreateLeaderboardsService < ::BaseService
    def initialize(challenge_round:, meta_challenge_id: nil)
      @challenge_round   = challenge_round
      @challenge         = @challenge_round.challenge
      @submissions       = @challenge_round.submissions.order(created_at: :desc)
      @meta_challenge_id = meta_challenge_id
      @window_border     = (@submissions.find_by(meta_challenge_id: @meta_challenge_id)&.created_at || Time.current) - @challenge_round.ranking_window.hours
    end

    def call
      ActiveRecord::Base.transaction do
        truncate_scores

        BaseLeaderboard.where(challenge_round: challenge_round, meta_challenge_id: @meta_challenge_id).destroy_all

        leaderboards          = build_base_leaderboards('leaderboard', [false], Time.current)
        previous_leaderboards = build_base_leaderboards('previous', [false], @window_border)

        create_leaderboards(leaderboards, previous_leaderboards)

        ongoing_leaderboards          = build_base_leaderboards('ongoing', [true, false], Time.current)
        previous_ongoing_leaderboards = build_base_leaderboards('previous_ongoing', [true, false], @window_border)

        create_leaderboards(ongoing_leaderboards, previous_ongoing_leaderboards)
      end

      success
    end

    private

    attr_reader :challenge_round, :challenge, :submissions, :window_border, :meta_challenge_id

    def create_leaderboards(leaderboards, previous_leaderboards)
      leaderboards.each do |leaderboard|
        previous_leaderboard = previous_leaderboards.find do |previous_leaderboard|
          previous_leaderboard.submitter_id == leaderboard.submitter_id &&
          previous_leaderboard.submitter_type == leaderboard.submitter_type
        end

        next if previous_leaderboard.blank?

        leaderboard.previous_row_num = previous_leaderboard.row_num
      end

      BaseLeaderboard.import!(leaderboards)
    end

    def build_base_leaderboards(leaderboard_type, post_challenge, cuttoff_dttm)
      teams_submissions = submissions.joins(participant: :teams)
        .where(meta_challenge_id: @meta_challenge_id, post_challenge: post_challenge, baseline: false)
        .where('submissions.created_at <= ?', cuttoff_dttm)
        .select('teams.id AS team_id, submissions.*')
        .reorder(submissions_order)
        .group_by { |submission| submission.team_id }

      participants_submissions = submissions.left_joins(participant: :teams)
        .where('teams.id IS NULL AND participants.id IS NOT NULL')
        .where(meta_challenge_id: @meta_challenge_id, post_challenge: post_challenge, baseline: false)
        .where('submissions.created_at <= ?', cuttoff_dttm)
        .reorder(submissions_order)
        .group_by { |submission| submission.participant_id }

      migration_submmissions = submissions.left_joins(:participant)
        .where(meta_challenge_id: @meta_challenge_id, post_challenge: post_challenge, baseline: false)
        .where('submissions.created_at <= ?', cuttoff_dttm)
        .reorder(submissions_order)
        .where('participants.id IS NULL')

      baseline_submissions = challenge_round.submissions
        .where(meta_challenge_id: @meta_challenge_id, post_challenge: post_challenge, baseline: true, grading_status_cd: 'graded')
        .where('submissions.created_at <= ?', cuttoff_dttm)

      team_leaderboards = teams_submissions.map do |team_id, submissions|
        first_graded_submission = submissions.find { |submission| submission.grading_status_cd == 'graded' }
        next if first_graded_submission.blank?

        build_leaderboard(first_graded_submission, submissions.size, 'Team', team_id, leaderboard_type)
      end

      participants_leaderboards = participants_submissions.map do |participant_id, submissions|
        first_graded_submission = submissions.find { |submission| submission.grading_status_cd == 'graded' }
        next if first_graded_submission.blank?

        build_leaderboard(first_graded_submission, submissions.size, 'Participant', participant_id, leaderboard_type)
      end

      migration_leaderboards = migration_submmissions.map do |submission|
        build_leaderboard(submission, 1, 'OldParticipant', nil, leaderboard_type)
      end

      baseline_leaderboards = baseline_submissions.map do |submission|
        build_leaderboard(submission, 0, 'Participant', submission.participant_id, leaderboard_type)
      end

      users_leaderboards  = (team_leaderboards + participants_leaderboards + migration_leaderboards).compact
      sorted_leaderboards = sort_leaderboards(users_leaderboards)

      leaderboards_with_rank = sorted_leaderboards.map.with_index(1) do |leaderboard, index|
        leaderboard.row_num = index
        leaderboard
      end

      all_leaderboards    = leaderboards_with_rank + baseline_leaderboards
      sorted_leaderboards = sort_leaderboards(all_leaderboards)

      leaderboards_with_rank_and_seq = sorted_leaderboards.map.with_index(1) do |leaderboard, index|
        leaderboard.seq = index
        leaderboard
      end

      leaderboards_with_rank_and_seq
    end

    def build_leaderboard(submission, submissions_count, submitter_type, submitter_id, leaderboard_type = 'leaderboard')
      BaseLeaderboard.new(
        meta_challenge_id:    @meta_challenge_id,
        challenge_id:         challenge.id,
        challenge_round_id:   challenge_round.id,
        submitter_type:       submitter_type,
        submitter_id:         submitter_id,
        submission_id:        submission.id,
        seq:                  0,
        row_num:              0,
        previous_row_num:     0,
        entries:              submissions_count,
        score:                submission.score_display,
        score_secondary:      submission.score_secondary_display,
        meta:                 submission.meta,
        media_large:          submission.media_large,
        media_thumbnail:      submission.media_thumbnail,
        media_content_type:   submission.media_content_type,
        description:          submission.description,
        description_markdown: submission.description_markdown,
        leaderboard_type_cd:  leaderboard_type,
        post_challenge:       submission.post_challenge,
        baseline:             submission.baseline,
        baseline_comment:     submission.baseline_comment,
        refreshed_at:         Time.current,
        created_at:           submission.created_at,
        updated_at:           submission.updated_at
      )
    end

    def sort_map(sort_field)
      case sort_field
      when 'ascending'
        return 'asc'
      when 'descending'
        return 'desc'
      else
        return nil
      end
    end

    def submissions_order(use_display: false)
      return 'updated_at desc' if challenge.latest_submission == true

      score_sort_order ||= sort_map(challenge_round.primary_sort_order_cd)
      score_sort_col     = use_display ? 'score_display' : 'score'

      return "#{score_sort_col} #{score_sort_order} NULLS LAST" if challenge_round.secondary_sort_order_cd.blank? || challenge_round.secondary_sort_order_cd == 'not_used'

      secondary_sort_order ||= sort_map(challenge_round.secondary_sort_order_cd)
      secondary_sort_col     = use_display ? 'score_secondary_display' : 'score_secondary'
      "#{score_sort_col} #{score_sort_order} NULLS LAST, #{secondary_sort_col} #{secondary_sort_order} NULLS LAST"
    end

    def sort_leaderboards(all_leaderboards)
      all_leaderboards.sort_by { |leaderboard| leaderboard.updated_at }.reverse

      return 'updated_at desc' if challenge.latest_submission == true

      score_sort_order ||= sort_map(challenge_round.primary_sort_order_cd)

      if challenge_round.secondary_sort_order_cd.blank? || challenge_round.secondary_sort_order_cd == 'not_used'
        sorted_leaderboards = all_leaderboards.sort_by { |leaderboard| leaderboard.score.to_i }
        sorted_leaderboards.reverse! if score_sort_order == 'desc'

        return sorted_leaderboards
      end

      secondary_sort_order ||= sort_map(challenge_round.secondary_sort_order_cd)

      all_leaderboards.sort_by do |leaderboard|
        first_column     = score_sort_order == 'desc' ? leaderboard.score : leaderboard.score * -1
        secondary_column = secondary_sort_order == 'desc' ? leaderboard.score_secondary : leaderboard.score_secondary * -1

        [first_column, secondary_column]
      end
    end

    def truncate_scores
      submissions
        .where(meta_challenge_id: @meta_challenge_id)
        .update_all([
          'score_display = ROUND(score::numeric, ?), score_secondary_display = ROUND(score_secondary::numeric, ?)',
          @challenge_round.score_precision,
          @challenge_round.score_secondary_precision
        ])
    end
  end
end
