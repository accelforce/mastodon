# frozen_string_literal: true

require 'rails_helper'

RSpec.describe REST::StatusEditSerializer do
  subject do
    serialized_record_json(
      status_edit,
      described_class,
      options: { scope: nil, scope_name: :current_user }
    )
  end

  let(:status_edit) { Fabricate(:status_edit) }

  context 'with a Cat author and a different editor' do
    let(:author) { Fabricate(:account, cat: true) }
    let(:status) { Fabricate(:status, account: author) }
    let(:status_edit) { Fabricate(:status_edit, status: status, account: Fabricate(:account, cat: false), text: 'な 나') }

    it 'uses the post author for historical content' do
      expect(subject).to include('content' => '<p>にゃ 냐</p>')
    end

    context 'when the author disables Cat status' do
      before { author.update!(cat: false) }

      it 'renders the original historical body' do
        expect(subject).to include('content' => '<p>な 나</p>')
      end
    end
  end

  context 'when created_at is populated' do
    it 'parses as RFC 3339 datetime' do
      expect(subject)
        .to include(
          'created_at' => match_api_datetime_format
        )
    end
  end
end
