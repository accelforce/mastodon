# frozen_string_literal: true

class AddQuotesCountToStatusStat < ActiveRecord::Migration[8.0]
  def change
    add_column :status_stats, :quotes_count, :bigint, null: false, default: 0

    up_only do
      safety_assured do
        execute <<~SQL.squish
          INSERT INTO status_stats (status_id, quotes_count, created_at, updated_at)
          SELECT quoted_status_id, COUNT(*), NOW(), NOW()
          FROM quotes
          WHERE state = 1 AND quoted_status_id IS NOT NULL
          GROUP BY quoted_status_id
          ON CONFLICT (status_id) DO UPDATE SET quotes_count = EXCLUDED.quotes_count
        SQL
      end
    end
  end
end
