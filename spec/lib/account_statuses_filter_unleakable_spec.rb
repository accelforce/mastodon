# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccountStatusesFilter do
  let(:author) { Fabricate(:account) }
  let(:viewer) { Fabricate(:account) }
  let!(:status) { Fabricate(:status, account: author, visibility: :unleakable) }
  let!(:direct) { Fabricate(:status, account: author, visibility: :direct) }

  def results(account, **params)
    described_class.new(author, account, params).results
  end

  it 'returns followees-only posts to the author, including when excluding direct posts' do
    expect(results(author)).to include(status, direct)
    expect(results(author, exclude_direct: true)).to include(status).and not_include(direct)
  end

  it 'returns them to followees but not anonymous viewers, strangers, or ordinary followers' do
    expect(results(nil)).to_not include(status)
    expect(results(viewer)).to_not include(status)
    viewer.follow!(author)
    expect(results(viewer)).to_not include(status)
    author.follow!(viewer)
    expect(results(viewer)).to include(status)
    expect(results(viewer, exclude_direct: true)).to include(status)
  end

  it 'retains mentioned posts after unfollowing, including silent mentions and exclude_direct' do
    author.follow!(viewer)
    Fabricate(:mention, status: status, account: viewer, silent: true)
    Fabricate(:mention, status: direct, account: viewer)
    author.unfollow!(viewer)

    expect(results(viewer)).to include(status, direct)
    expect(results(viewer, exclude_direct: true)).to include(status).and not_include(direct)
  end
end
