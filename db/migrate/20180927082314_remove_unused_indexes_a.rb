# frozen_string_literal: true

class RemoveUnusedIndexesA < ActiveRecord::Migration[5.2]
  def up
    remove_index :blocks, name: 'index_blocks_on_target_account_id'
    remove_index :mutes, name: 'index_mutes_on_target_account_id'
    remove_index :oauth_access_grants, name: 'index_oauth_access_grants_on_resource_owner_id'
    remove_index :session_activations, name: 'index_session_activations_on_access_token_id'
  end
end
