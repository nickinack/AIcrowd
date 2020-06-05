class TestPreviousLeaderboards < ActiveRecord::Migration[5.2]
  def change
    create_view :previous_leaderboards, version: 5
    create_view :previous_ongoing_leaderboards, version: 4
  end
end
