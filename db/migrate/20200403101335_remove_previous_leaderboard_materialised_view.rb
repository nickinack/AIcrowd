class RemovePreviousLeaderboardMaterialisedView < ActiveRecord::Migration[5.2]
  def change
    drop_view :previous_leaderboards
  end
end
