require 'rails_helper'

describe Scheduler::MediaCleanupScheduler do
  subject { described_class.new }

  let!(:old_local_media) { Fabricate(:media_attachment, account_id: nil, created_at: 10.days.ago) }
  let!(:new_local_media) { Fabricate(:media_attachment, account_id: nil, created_at: 1.hour.ago) }

  let(:status) { Fabricate(:status) }
  let!(:very_old_remote_media) { Fabricate(:media_attachment, created_at: 30.days.ago, remote_url: 'https://example.com/example.png', status: status) }
  let!(:old_remote_media) { Fabricate(:media_attachment, created_at: 15.days.ago, remote_url: 'https://example.com/example.png', status: status) }
  let!(:new_remote_media) { Fabricate(:media_attachment, created_at: 1.days.ago, remote_url: 'https://example.com/example.png', status: status) }

  context 'when auto removal enabled' do
    before do
      Setting.media_remove_enabled = true
    end

    it 'removes old local media records' do
      subject.perform

      expect { old_local_media.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect(new_local_media.reload).to be_persisted
    end

    it 'removes old remote media records' do
      subject.perform

      expect(very_old_remote_media.reload).to be_needs_redownload
      expect(old_remote_media.reload).to be_needs_redownload
      expect(new_remote_media.reload).not_to be_needs_redownload
    end

    context 'when a days setting configured' do
      before do
        Setting.media_remove_days = 20
      end

      it 'respects a days setting' do
        subject.perform

        expect(very_old_remote_media.reload).to be_needs_redownload
        expect(old_remote_media.reload).not_to be_needs_redownload
        expect(new_remote_media.reload).not_to be_needs_redownload
      end
    end
  end

  context 'when auto removal disabled' do
    before do
      Setting.media_remove_enabled = false
    end

    it 'removes old local media records' do
      subject.perform

      expect { old_local_media.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect(new_local_media.reload).to be_persisted
    end

    it 'does not remove old remote media records' do
      subject.perform

      expect(very_old_remote_media.reload).not_to be_needs_redownload
      expect(old_remote_media.reload).not_to be_needs_redownload
      expect(new_remote_media.reload).not_to be_needs_redownload
    end
  end
end
