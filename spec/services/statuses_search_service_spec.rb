# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StatusesSearchService do
  subject(:service) { described_class.new }

  let(:viewer) { Fabricate(:account) }
  let(:author) { Fabricate(:account, indexable: false) }

  def search(query, **options)
    service.call(query, viewer, { limit: 20 }.merge(options))
  end

  describe '#call' do
    it 'searches local and remote public posts without Elasticsearch, opt-in, or interactions' do
      local = Fabricate(:status, account: author, text: '電車に乗る')
      remote = Fabricate(:status, account: Fabricate(:account, domain: 'remote.example', indexable: false), text: '<p>電車で帰る</p>')

      expect(Chewy).to_not be_enabled
      expect(search('電車')).to eq [remote, local]
    end

    it 'searches authored text rather than cat speech or content warnings' do
      author.update!(cat: true)
      status = Fabricate(:status, account: author, text: 'な', spoiler_text: '警告')

      expect(search('な')).to eq [status]
      expect(search('にゃ')).to be_empty
      expect(search('警告')).to be_empty
    end

    it 'excludes every non-public visibility even for the author' do
      statuses = %i(public unlisted private unleakable direct limited).map do |visibility|
        Fabricate(:status, account: viewer, text: 'visibility', visibility: visibility)
      end

      expect(search('visibility')).to eq [statuses.first]
    end

    it 'excludes discarded posts and boosts from modifier-only searches' do
      status = Fabricate(:status, account: viewer, text: 'original')
      Fabricate(:status, account: viewer, text: 'discarded').discard!
      Fabricate(:status, account: viewer, reblog: status)

      expect(search('from:me')).to eq [status]
    end

    %i(blocking blocked_by muting domain_blocking silenced suspended deleted).each do |restriction|
      context "with a #{restriction} author" do
        let!(:status) { Fabricate(:status, account: author, text: 'restricted') }

        before do
          case restriction
          when :blocking then viewer.block!(author)
          when :blocked_by then author.block!(viewer)
          when :muting then viewer.mute!(author)
          when :domain_blocking
            author.update!(domain: 'blocked.example')
            viewer.block_domain!(author.domain)
          when :silenced then author.update!(silenced_at: Time.now.utc)
          when :suspended then author.update!(suspended_at: Time.now.utc)
          when :deleted then author.update!(requested_deletion_at: Time.now.utc)
          end
        end

        it 'filters the post before counting search results' do
          expect(search('restricted')).to be_empty
        end

        if restriction == :silenced
          it 'retains posts from a followed author' do
            viewer.follow!(author)

            expect(search('restricted')).to eq [status]
          end
        end
      end
    end

    it 'pages the filtered results across candidate batches' do
      visible = Fabricate.times(3, :status, account: author, text: 'page')
      blocked_author = Fabricate(:account)
      viewer.block!(blocked_author)
      first_id = visible.last.id + 1
      Status.insert_all!((0..100).map do |index|
        { id: first_id + index, account_id: blocked_author.id, text: 'page', visibility: 0, created_at: Time.now.utc, updated_at: Time.now.utc }
      end)

      expect(search('page', limit: 2)).to eq visible.reverse.take(2)
      expect(search('page', limit: 2, offset: 2)).to eq [visible.first]
    end

    it 'applies author and exclusive ID boundaries without converting IDs to timestamps' do
      statuses = (100..102).map { |id| Fabricate(:status, id: id, account: author, text: 'boundary', created_at: Time.utc(2026, 10, 11)) }
      Fabricate(:status, id: 103, account: viewer, text: 'boundary')

      expect(search('boundary', account_id: author.id, min_id: 100, max_id: 102)).to eq [statuses[1]]
      expect(search('boundary', limit: 0)).to be_empty
    end

    context 'with text operators' do
      let!(:phrase) { Fabricate(:status, account: author, text: 'red blue') }
      let!(:reversed) { Fabricate(:status, account: author, text: 'blue red') }
      let!(:other) { Fabricate(:status, account: author, text: 'red OR green :blobcat:') }

      it 'supports required words, phrases, and exclusions' do
        expect(search('+red blue')).to eq [reversed, phrase]
        expect(search('"red blue"')).to eq [phrase]
        expect(search('red -blue')).to eq [other]
        expect(search('red -"red blue"')).to eq [other, reversed]
      end

      it 'treats query-language words and emoji shortcodes as authored text' do
        expect(search('OR')).to eq [other]
        expect(search(':blobcat:')).to eq [other]
      end

      it 'retains the ordinary-text meaning of unknown prefixes' do
        expect(search('red:blue')).to eq [reversed, phrase]
      end
    end

    context 'with author and language operators' do
      let!(:japanese) { Fabricate(:status, account: viewer, text: 'language', language: 'ja') }
      let!(:english) { Fabricate(:status, account: author, text: 'language', language: 'en') }
      let!(:unknown) { Fabricate(:status, account: author, text: 'language', language: nil) }

      it 'resolves authors including me and missing accounts' do
        expect(search('from:me')).to eq [japanese]
        expect(search("from:@#{author.acct}")).to eq [unknown, english]
        expect(search('from:@nonexistent@invalid.example')).to be_empty
      end

      it 'normalizes language codes and includes missing values in negated filters' do
        expect(search('language:EN_US')).to eq [english]
        expect(search('-language:ja')).to eq [unknown, english]
      end
    end

    context 'with date operators' do
      let!(:before_day) { Fabricate(:status, account: author, created_at: Time.utc(2026, 10, 10, 14, 59, 59)) }
      let!(:start_of_day) { Fabricate(:status, account: author, created_at: Time.utc(2026, 10, 10, 15)) }
      let!(:end_of_day) { Fabricate(:status, account: author, created_at: Time.utc(2026, 10, 11, 14, 59, 59)) }
      let!(:after_day) { Fabricate(:status, account: author, created_at: Time.utc(2026, 10, 11, 15)) }

      before do
        viewer.user.update!(time_zone: 'Asia/Tokyo')
        viewer.reload
      end

      it 'uses calendar-day boundaries in the account time zone' do
        expect(search('during:2026-10-11')).to eq [end_of_day, start_of_day]
        expect(search('before:2026-10-11')).to eq [before_day]
        expect(search('after:2026-10-11')).to eq [after_day]
        expect(search('-during:2026-10-11')).to eq [after_day, before_day]
      end

      it 'supports explicit instants, Unix milliseconds, and invalid-date errors' do
        expect(search('during:"2026-10-10T15:00:00Z"')).to eq [start_of_day]
        expect(search("during:#{start_of_day.created_at.to_i * 1000}")).to eq [start_of_day]
        expect { search('during:invalid') }.to raise_error(Date::Error)
      end
    end

    context 'with post property operators' do
      let!(:status) { Fabricate(:status, account: author, text: 'properties', reply: true, sensitive: true) }

      it 'supports reply, sensitive, quote, and their negations' do
        Fabricate(:quote, status: status)

        expect(search('is:reply is:sensitive has:quote')).to eq [status]
        expect(search('-has:quote')).to_not include(status)
        expect(search('has:unknown')).to be_empty
      end

      %i(image video audio).each do |type|
        it "matches displayed #{type} attachments without duplicating posts" do
          attachments = Fabricate.times(2, :media_attachment, status: status, account: author, type: type, file: nil, remote_url: 'https://remote.example/media')
          attachments.each { |attachment| attachment.update!(type: type) }

          expect(search("has:media has:#{type}")).to eq [status]

          status.update!(ordered_media_attachment_ids: [])
          expect(search('has:media')).to be_empty

          status.update!(ordered_media_attachment_ids: [attachments.first.id])
          expect(search("has:#{type}")).to eq [status]
        end
      end

      it 'supports poll, link, and embed relationships' do
        poll = Fabricate(:poll, account: author, status: status)
        status.update!(poll_id: poll.id)
        card = Fabricate(:preview_card, type: :video, image: nil)
        PreviewCardsStatus.create!(status: status, preview_card: card)

        expect(search('has:poll has:link has:embed')).to eq [status]
      end

      it 'matches normalized hashtag relationships' do
        status.tags << Fabricate(:tag, name: 'railway')

        expect(search('#Railway')).to eq [status]
        expect(search('properties -#railway')).to be_empty
      end
    end

    context 'with library scopes' do
      it 'searches public library relationships without requiring them for all or public searches' do
        own = Fabricate(:status, account: viewer, text: 'library')
        related = Fabricate.times(5, :status, account: author, text: 'library')
        other = Fabricate(:status, account: author, text: 'library')
        private_post = Fabricate(:status, account: viewer, text: 'library', visibility: :private)
        Fabricate(:mention, status: related[0], account: viewer)
        Fabricate(:favourite, status: related[1], account: viewer)
        Fabricate(:bookmark, status: related[2], account: viewer)
        Fabricate(:status, account: viewer, reblog: related[3])
        poll = Fabricate(:poll, status: related[4], account: author)
        related[4].update!(poll_id: poll.id)
        Fabricate(:poll_vote, poll: poll, account: viewer)
        Fabricate(:mention, status: other, account: viewer, silent: true)

        expect(search('library in:library')).to eq [*related.reverse, own]
        expect(search('library in:public')).to eq [other, *related.reverse, own]
        expect(search('library in:all')).to_not include(private_post)
      end
    end
  end
end
