class Settings::ProfilesController < ApplicationController
  layout :layout_for_settings_profile

  def show
    @user = Current.user
    @users = Current.family.users.order(:created_at)
    @breadcrumbs = [
      [ "Home", root_path ],
      [ "Profile Info", nil ]
    ]
  end

  def destroy
    unless Current.user.admin?
      flash[:alert] = t("settings.profiles.destroy.not_authorized")
      redirect_to settings_profile_path
      return
    end

    @user = Current.family.users.find(params[:user_id])

    if @user == Current.user
      flash[:alert] = t("settings.profiles.destroy.cannot_remove_self")
      redirect_to settings_profile_path
      return
    end

    if @user.destroy
      flash[:notice] = "Member removed successfully."
    else
      flash[:alert] = "Failed to remove member."
    end

    redirect_to settings_profile_path
  end

  private

    def layout_for_settings_profile
      Current.user&.ui_layout_intro? ? "application" : "settings"
    end
end
