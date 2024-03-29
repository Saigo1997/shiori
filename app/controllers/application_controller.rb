# frozen_string_literal: true

class ApplicationController < ActionController::Base
  before_action :load_playlists

  def check_signed_in
    return if user_signed_in?

    redirect_to new_user_session_url
  end

  private

  def load_playlists
    return unless user_signed_in?

    @playlists = current_user.playlist.order(:order)
  end

  def check_guest
    email = resource&.email || params[:user][:email].downcase
    return if email != 'guest@example.com'

    redirect_to root_path, alert: 'ゲストユーザーの変更・削除はできません'
  end

  def playlist_param
    { playlist: params[:playlist] } if params[:playlist]
  end

  def redirect_to_media_manage(media_manage)
    redirect_to media_manage_url(media_manage, playlist_param)
  end
end
