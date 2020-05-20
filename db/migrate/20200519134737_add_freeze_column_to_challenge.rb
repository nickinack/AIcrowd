class AddFreezeColumnToChallenge < ActiveRecord::Migration[5.2]
  def change
    add_column :challenges, :freeze_flag, :boolean, null: false, default: false
    add_column :challenges, :freeze_duration, :integer
  end
end
