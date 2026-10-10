# frozen_string_literal: true

class AddCatToAccounts < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!

  def change
    safety_assured do
      add_column :accounts, :cat, :boolean, default: false, null: false
    end
  end
end
