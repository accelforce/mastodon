# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UnmergeWorker do
  let(:worker) { described_class.new }

  describe '#perform' do
    subject { worker.perform(account_id, into_id, type) }

    let(:account_id) { account.id }
    let(:account) { Fabricate :account }
    let(:into_id) { nil }
    let(:type) { nil }

    context 'when account is invalid' do
      let(:account_id) { 123_123_123 }

      it { is_expected.to be(true) }
    end

    context 'when type is invalid' do
      it { is_expected.to be_nil }
    end

    context 'when type is list' do
      let(:type) { 'list' }

      context 'when target is invalid' do
        let(:into_id) { 123_123_123 }

        it { is_expected.to be(true) }
      end

      context 'when target is valid' do
        let(:into_id) { list.id }
        let(:list) { Fabricate :list }

        let(:manager_service) { instance_double(FeedManager, unmerge_from_list: nil) }

        before { allow(FeedManager).to receive(:instance).and_return manager_service }

        it 'unmerges from list feed' do
          subject

          expect(manager_service)
            .to have_received(:unmerge_from_list).with(account, list)
        end
      end
    end

    context 'when type is home' do
      let(:type) { 'home' }

      context 'when target is invalid' do
        let(:into_id) { 123_123_123 }

        it { is_expected.to be(true) }
      end

      context 'when target is valid' do
        let(:into_id) { target_account.id }
        let(:target_account) { Fabricate :account }

        let(:manager_service) { instance_double(FeedManager, unmerge_from_home: nil) }

        before { allow(FeedManager).to receive(:instance).and_return manager_service }

        it 'unmerges from list feed' do
          subject

          expect(manager_service)
            .to have_received(:unmerge_from_home).with(account, target_account)
        end
      end
    end
  end

  describe 'removing inaccessible unleakable statuses' do
    let(:author) { Fabricate(:user).account }
    let(:recipient) { Fabricate(:user).account }
    let(:list) { Fabricate(:list, account: recipient) }
    let(:manager) { FeedManager.instance }
    let(:options) { { 'only_unleakable' => true } }
    let(:status) { Fabricate(:status, account: author, visibility: :unleakable) }
    let(:mentioned) { Fabricate(:status, account: author, visibility: :unleakable) }
    let(:silent_mentioned) { Fabricate(:status, account: author, visibility: :unleakable) }
    let(:public_status) { Fabricate(:status, account: author) }
    let(:private_status) { Fabricate(:status, account: author, visibility: :private) }
    let(:other_status) { Fabricate(:status, visibility: :unleakable) }
    let(:statuses) { [status, mentioned, silent_mentioned, public_status, private_status, other_status] }

    before do
      recipient.follow!(author)
      author.follow!(recipient)
      Fabricate(:list_account, list: list, account: author)
      Fabricate(:mention, status: mentioned, account: recipient)
      Fabricate(:mention, status: silent_mentioned, account: recipient, silent: true)
      statuses.each do |post|
        manager.push_to_home(recipient, post)
        manager.push_to_list(list, post)
      end
      allow(redis).to receive(:publish)
    end

    it 'queues reverse unmerges when the author unfollows the recipient' do
      expect { UnfollowService.new.call(author, recipient) }
        .to enqueue_sidekiq_job(described_class).with(author.id, recipient.id, 'home', options)

      expect(described_class.jobs.pluck('args')).to include([author.id, list.id, 'list', options])
    end

    it 'removes only inaccessible posts from the recipient feeds without streaming deletions', :inline_jobs do
      UnfollowService.new.call(author, recipient)

      [:home, :list].each do |type|
        id = type == :home ? recipient.id : list.id
        expect(redis.zrange(manager.key(type, id), 0, -1)).to match_array(statuses.excluding(status).map { |post| post.id.to_s })
      end
      expect(redis).to_not have_received(:publish)
    end

    it 'skips unmerging when disabled' do
      expect { UnfollowService.new.call(author, recipient, skip_unmerge: true) }
        .to_not enqueue_sidekiq_job(described_class)
    end

    it 'keeps the usual unmerge behavior without options' do
      worker.perform(author.id, recipient.id, 'home')
      worker.perform(author.id, list.id, 'list')

      expect(redis.zrange(manager.key(:home, recipient.id), 0, -1)).to eq([other_status.id.to_s])
      expect(redis.zrange(manager.key(:list, list.id), 0, -1)).to eq([other_status.id.to_s])
    end
  end
end
