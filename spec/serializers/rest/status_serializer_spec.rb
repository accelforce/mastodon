# frozen_string_literal: true

require 'rails_helper'

RSpec.describe REST::StatusSerializer do
  subject do
    serialized_record_json(
      status,
      described_class,
      options: {
        scope: current_user,
        scope_name: :current_user,
      }
    )
  end

  let(:current_user) { Fabricate(:user) }
  let(:alice) { Fabricate(:account, username: 'alice') }
  let(:bob)   { Fabricate(:account, username: 'bob', domain: 'other.com') }
  let(:status) { Fabricate(:status, account: alice) }

  context 'with a local status' do
    context 'with a Cat author' do
      let(:alice) { Fabricate(:account, username: 'alice', cat: true) }
      let(:status) { Fabricate(:status, account: alice, text: 'な 나', spoiler_text: 'な', language: 'en') }

      it 'converts content independently of language while preserving the editing source and CW' do
        expect(subject).to include('content' => '<p>にゃ 냐</p>', 'spoiler_text' => 'な', 'account' => a_hash_including('cat' => true))
        expect(serialized_record_json(status, REST::StatusSourceSerializer)).to include('text' => 'な 나')
        expect(status.reload.text).to eq 'な 나'
      end

      context 'when the author disables Cat status' do
        before { alice.update!(cat: false) }

        it 'renders the original body' do
          expect(subject).to include('content' => '<p>な 나</p>', 'account' => a_hash_including('cat' => false))
        end
      end
    end

    context 'with a quote and a CW but no contents' do
      let(:quoted_status) { Fabricate(:status, account: alice) }
      let(:status) { Fabricate.build(:status, account: alice, text: '', spoiler_text: 'this is a CW') }

      before do
        Fabricate(:quote, status: status, quoted_status: quoted_status, state: :accepted)
      end

      it 'renders the status with a CW and fallback link' do
        expect(subject)
          .to include(
            'content' => /RE: <a/,
            'spoiler_text' => 'this is a CW'
          )
      end

      context 'with a Cat author' do
        let(:alice) { Fabricate(:account, cat: true) }

        it 'preserves the quote fallback' do
          expect(subject['content']).to include('RE: <a', ActivityPub::TagManager.instance.url_for(quoted_status))
        end
      end
    end
  end

  context 'with a remote status' do
    let(:status) { Fabricate(:status, account: bob) }

    before do
      status.status_stat.tap do |status_stat|
        status_stat.reblogs_count = 10
        status_stat.favourites_count = 20
        status_stat.quotes_count = 15
        status_stat.save
      end
    end

    context 'with a Cat author' do
      let(:bob) { Fabricate(:account, username: 'bob', domain: 'other.com', cat: true) }
      let(:status) { Fabricate(:status, account: bob, text: '<p>な 나</p>') }

      it 'preserves received content and exposes Cat status' do
        expect(subject).to include('content' => '<p>な 나</p>', 'account' => a_hash_including('cat' => true))
      end
    end

    context 'with only trusted counts' do
      it 'shows the trusted counts' do
        expect(subject['reblogs_count']).to eq(10)
        expect(subject['favourites_count']).to eq(20)
        expect(subject['quotes_count']).to eq(15)
      end
    end

    context 'with untrusted counts' do
      before do
        status.status_stat.tap do |status_stat|
          status_stat.untrusted_reblogs_count = 30
          status_stat.untrusted_favourites_count = 40
          status_stat.save
        end
      end

      it 'shows the untrusted counts' do
        expect(subject['reblogs_count']).to eq(30)
        expect(subject['favourites_count']).to eq(40)
      end
    end

    context 'with created_at' do
      it 'is serialized as RFC 3339 datetime' do
        expect(subject)
          .to include(
            'created_at' => match_api_datetime_format
          )
      end
    end

    context 'when edited_at is populated' do
      let(:status) { Fabricate.build :status, edited_at: 3.days.ago }

      it 'is serialized as RFC 3339 datetime' do
        expect(subject)
          .to include(
            'edited_at' => match_api_datetime_format
          )
      end
    end

    context 'with a tagged collection' do
      let(:collection) { Fabricate(:collection) }

      before do
        status.tagged_objects.create!(object: collection, ap_type: 'FeaturedCollection', uri: ActivityPub::TagManager.instance.uri_for(collection))
      end

      it 'contains the tagged collection' do
        expect(subject)
          .to include(
            'tagged_collections' => [a_hash_including(
              'id' => collection.id.to_s
            )]
          )
      end
    end
  end
end
