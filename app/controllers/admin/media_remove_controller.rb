# frozen_string_literal: true

module Admin
  class MediaRemoveController < BaseController
    def edit
      authorize :settings, :show?

      @media_remove = Form::MediaRemove.new
    end

    def update
      authorize :settings, :update?

      @media_remove = Form::MediaRemove.new(media_remove_params)

      if @media_remove.save
        flash[:notice] = I18n.t 'generic.changes_saved_msg'
        redirect_to edit_admin_media_remove_path
      else
        render :edit
      end
    end

    private

    def media_remove_params
      params.require(:form_media_remove).permit(*Form::MediaRemove::KEYS)
    end
  end
end
