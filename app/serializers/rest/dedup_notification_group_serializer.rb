# frozen_string_literal: true

class REST::DedupNotificationGroupSerializer < ActiveModel::Serializer
  has_many :accounts, serializer: REST::AccountSerializer
  has_many :partial_accounts, serializer: REST::PartialAccountSerializer, if: :return_partial_accounts?
  has_many :statuses, serializer: REST::StatusSerializer
  has_many :notification_groups, serializer: REST::NotificationGroupSerializer

  def statuses
    object.statuses.reject { |status| status.unleakable_visibility? && !StatusPolicy.new(current_user&.account, status).show? }
  end

  def return_partial_accounts?
    instance_options[:expand_accounts] == 'partial_avatars'
  end
end
