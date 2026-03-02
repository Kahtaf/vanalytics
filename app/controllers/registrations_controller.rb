class RegistrationsController < ApplicationController
  skip_authentication

  layout "auth"

  before_action :ensure_signup_open, if: :self_hosted?
  before_action :set_user, only: :create
  before_action :validate_password_requirements, only: :create

  def new
    @user = User.new
  end

  def create
    family = Family.new
    @user.family = family
    @user.role = User.role_for_new_family_creator

    if @user.save
      @session = create_session_for(@user)
      redirect_to root_path, notice: t(".success")
    else
      render :new, status: :unprocessable_entity, alert: t(".failure")
    end
  end

  private

    def set_user
      @user = User.new user_params
    end

    def user_params
      params.require(:user).permit(:name, :email, :password, :password_confirmation)
    end

    def validate_password_requirements
      password = user_params[:password]
      return if password.blank?

      if password.length < 8
        @user.errors.add(:password, "must be at least 8 characters")
      end

      unless password.match?(/[A-Z]/) && password.match?(/[a-z]/)
        @user.errors.add(:password, "must include both uppercase and lowercase letters")
      end

      unless password.match?(/\d/)
        @user.errors.add(:password, "must include at least one number")
      end

      unless password.match?(/[!@#$%^&*(),.?":{}|<>]/)
        @user.errors.add(:password, "must include at least one special character")
      end

      if @user.errors.present?
        render :new, status: :unprocessable_entity
      end
    end

    def ensure_signup_open
      return unless Setting.onboarding_state == "closed"

      redirect_to new_session_path, alert: t("registrations.closed")
    end
end
