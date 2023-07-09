# frozen_string_literal: true

class RemoveIndexAccountPins < ActiveRecord::Migration[5.2]
  def up
    remove_index :account_pins, name: 'index_account_pins_on_account_id'
  end
end
