# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Status do
  let(:account) { Fabricate(:account) }

  it 'preserves the visibility values already deployed in v4.4' do
    expect(described_class.visibilities).to eq('public' => 0, 'unlisted' => 1, 'private' => 2, 'unleakable' => 3, 'direct' => 4, 'limited' => 5)
  end

  it 'excludes unleakable posts from account counts on creation and deletion' do
    Fabricate(:status, account: account)
    status = nil

    expect { status = Fabricate(:status, account: account, visibility: :unleakable) }
      .to_not(change { account.reload.statuses_count })
    expect { status.destroy! }.to_not(change { account.reload.statuses_count })
  end

  it 'does not expose unleakable reblogs through public boost counts' do
    public_status = Fabricate(:status, visibility: :public)
    Fabricate(:status, reblog: public_status)
    reblog = nil

    expect { reblog = Fabricate(:status, account: account, reblog: public_status, visibility: :unleakable) }
      .to_not(change { public_status.reload.reblogs_count })
    expect { reblog.destroy! }.to_not(change { public_status.reload.reblogs_count })
  end
end
