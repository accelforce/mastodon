# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Admin::MediaRemoveController, type: :controller do
  render_views

  describe 'When signed ina as an admin' do
    before do
      sign_in Fabricate(:user, admin: true), scope: :user
    end

    describe 'GET #edit' do
      it 'returns http success' do
        get :edit

        expect(response).to have_http_status 200
      end
    end

    describe 'PUT #update' do
      before do
        allow_any_instance_of(Form::MediaRemove).to receive(:valid?).and_return(true)
      end

      describe 'for a valid request' do
        around do |example|
          enabled = Setting.media_remove_enabled
          example.run
          Setting.media_remove_enabled = enabled
        end

        it 'updates a settings value' do
          Setting.media_remove_enabled = false
          patch :update, params: { form_media_remove: { enabled: '1' } }

          expect(response).to redirect_to edit_admin_media_remove_path
          expect(Setting.media_remove_enabled).to be_truthy
        end
      end

      describe 'for a non-existent record' do
        around do |example|
          enabled = Setting.media_remove_enabled
          Setting.media_remove_enabled = nil
          example.run
          Setting.media_remove_enabled = enabled
          Setting.media_remove_test = nil
        end

        it 'creates a settings record that did not exist before' do
          expect(Setting.media_remove_enabled).to be_blank

          patch :update, params: { form_media_remove: { enabled: '1' } }

          expect(response).to redirect_to edit_admin_media_remove_path
          expect(Setting.media_remove_enabled).to be_truthy
        end

        it 'does not create a non-existent record' do
          expect(Setting.media_remove_test).to be_blank

          patch :update, params: { form_media_remove: { test: '1' } }

          expect(response).to redirect_to edit_admin_media_remove_path
          expect(Setting.media_remove_test).to be_nil
        end
      end
    end
  end
end
