# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Settings preferences posting defaults page' do
  let(:user) { Fabricate :user }

  before { sign_in user }

  it 'Views and updates user prefs' do
    visit settings_preferences_posting_defaults_path

    expect(page)
      .to have_private_cache_control

    check mark_sensitive_field

    expect { save_changes }
      .to change { user.reload.settings.default_sensitive }.to(true)
    expect(page)
      .to have_title(I18n.t('preferences.posting_defaults'))
  end

  it 'saves and reloads followees-only posting defaults' do
    visit settings_preferences_posting_defaults_path
    select I18n.t('statuses.visibilities.unleakable'), from: form_label('defaults.setting_default_privacy'), exact: false

    expect { save_changes }
      .to change { user.reload.setting_default_privacy }.to('unleakable')

    visit settings_preferences_posting_defaults_path
    expect(find_field(form_label('defaults.setting_default_privacy')).value).to eq('unleakable')
  end

  def save_changes
    click_on submit_button
  end

  def mark_sensitive_field
    form_label('defaults.setting_default_sensitive')
  end
end
