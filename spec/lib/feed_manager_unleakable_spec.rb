# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FeedManager do
  subject(:manager) { described_class.instance }

  let(:author) { Fabricate(:user).account }
  let(:recipient) { Fabricate(:user).account }
  let(:list) { Fabricate(:list, account: recipient) }
  let!(:status) { Fabricate(:status, account: author, visibility: :unleakable) }

  before do
    recipient.follow!(author)
    Fabricate(:list_account, list: list, account: author)
  end

  it 'filters unauthorized home and list insertions and permits silent mentions' do
    expect(manager.filter?(:home, status, recipient)).to be true
    expect(manager.filter?(:list, status, list)).to be true
    Fabricate(:mention, status: status, account: recipient, silent: true)
    expect(manager.filter?(:home, status, recipient)).to be false
    expect(manager.filter?(:list, status, list)).to be false
  end

  [:merge_into_home, :populate_home, :merge_into_list, :populate_list].each do |method|
    it "checks permissions during #{method}" do
      type = method.to_s.end_with?('list') ? :list : :home
      receiver = type == :list ? list : recipient
      args = method.to_s.start_with?('merge') ? [author, receiver] : [receiver]
      key = manager.key(type, receiver.id)

      manager.public_send(method, *args)
      expect(redis.zscore(key, status.id)).to be_nil
      author.follow!(recipient)
      manager.public_send(method, *args)
      expect(redis.zscore(key, status.id)).to_not be_nil
    end
  end

  [:home, :list].each do |type|
    it "regenerates #{type} even when last_status_at excludes recent unleakable posts" do
      stub_const('FeedManager::MAX_ITEMS', 4)
      author.follow!(recipient)
      receiver = type == :home ? recipient : list
      key = manager.key(type, receiver.id)
      [2.days.ago, 1.day.ago].each do |time|
        post = Fabricate(:status, account: recipient, id: Mastodon::Snowflake.id_at(time), created_at: time)
        redis.zadd(key, post.id, post.id)
      end
      recent_status = Fabricate(:status, account: author, visibility: :unleakable)
      author.account_stat.update!(last_status_at: 3.days.ago)

      manager.public_send("populate_#{type}", receiver)

      expect(redis.zscore(key, recent_status.id)).to_not be_nil
    end
  end
end
