class RemoveMediaRemoval < ActiveRecord::Migration[6.1]
  def change
    up_only do
      Setting.where(var: %w[media_remove_enabled media_remove_days])
             .destroy_all
    end
  end
end
