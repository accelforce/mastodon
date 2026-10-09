# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StatusPolicy do
  let(:author) { Fabricate(:account) }
  let(:viewer) { Fabricate(:account) }
  let(:status) { Fabricate(:status, account: author, visibility: :unleakable) }

  def policy(account)
    described_class.new(account, status)
  end

  it 'allows the author but denies anonymous viewers and unrelated accounts' do
    expect(policy(author)).to be_show
    expect(policy(nil)).to_not be_show
    expect(policy(viewer)).to_not be_show
  end

  it 'allows followees of the author, regardless of whether they follow back' do
    author.follow!(viewer)

    expect(policy(viewer)).to be_show
  end

  it 'does not allow followers solely because they follow the author' do
    viewer.follow!(author)

    expect(policy(viewer)).to_not be_show
  end

  [false, true].each do |silent|
    it "allows mentioned viewers with silent=#{silent}, including preloaded mentions" do
      Fabricate(:mention, status: status, account: viewer, silent: silent)

      expect(policy(viewer)).to be_show
      status.mentions.load
      expect(policy(viewer)).to be_show
    end
  end

  it 'forbids boosting even by the author and permits only self-quotes' do
    author.follow!(viewer)

    expect(policy(author)).to_not be_reblog
    expect(policy(viewer)).to_not be_reblog
    expect(policy(author)).to be_quote
    expect(policy(viewer)).to_not be_quote
  end
end
