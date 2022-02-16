class RemovePrivateFilters < ActiveRecord::Migration[6.1]
  def change
    up_only do
      CustomFilter.where('phrase LIKE \'private-filter:@%\'').destroy_all
    end
  end
end
