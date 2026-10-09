# frozen_string_literal: true

require 'rails_helper'

RSpec.describe REST::DedupNotificationGroupSerializer do
  let(:user) { Fabricate(:user) }
  let(:author) { Fabricate(:account) }
  let(:status) { Fabricate(:status, account: author, visibility: :unleakable) }
  let(:presenter) { GroupedNotificationsPresenter.new([]) }

  before { allow(presenter).to receive(:statuses).and_return([status]) }

  def serialized_statuses
    serialized_record_json(presenter, described_class, options: { scope: user, scope_name: :current_user })['statuses']
  end

  it 'checks permissions before serializing grouped notification posts' do
    author.follow!(user.account)
    expect(serialized_statuses.pluck('id')).to include(status.id.to_s)

    author.unfollow!(user.account)
    expect(serialized_statuses).to be_empty

    Fabricate(:mention, status: status, account: user.account, silent: true)
    expect(serialized_statuses.pluck('id')).to include(status.id.to_s)
  end
end
