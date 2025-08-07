class UsersController < ApplicationController
  before_action :set_user, only: [ :show, :edit, :update, :destroy, :change_role, :remove_avatar ]

  def index
    @users = policy_scope(User).includes(:organization)
    authorize @users
  end

  def show
    authorize @user
  end

  def new
    @user = current_organization.users.build
    authorize @user
  end

  def create
    @user = current_organization.users.build(user_params)
    @user.invited_by = current_user
    authorize @user

    if @user.save
      # Send invitation email
      UserMailer.invitation_email(@user).deliver_later
      redirect_to users_path, notice: "User invitation sent successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @user
  end

  def update
    authorize @user

    if @user.update(user_params)
      redirect_to @user, notice: "User updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @user

    @user.destroy
    redirect_to users_path, notice: "User removed successfully."
  end

  def change_role
    authorize @user, :change_role?

    if @user.update(role: params[:role])
      redirect_to @user, notice: "User role updated successfully."
    else
      redirect_to @user, alert: "Failed to update user role."
    end
  end

  def remove_avatar
    authorize @user

    if @user.avatar.attached?
      @user.avatar.purge
      redirect_to edit_user_path(@user), notice: "Profile photo removed successfully."
    else
      redirect_to edit_user_path(@user), alert: "No profile photo to remove."
    end
  end

  private

  def set_user
    @user = policy_scope(User).find(params[:id])
  end

  def user_params
    # SECURITY FIX: Remove :role from mass assignment to prevent privilege escalation
    # Role changes should be handled separately by administrators
    base_params = params.require(:user).permit(:email, :first_name, :last_name, :avatar, :password, :password_confirmation)
    
    # Only allow role changes if current user is an admin and it's not their own account
    if can_modify_user_roles? && params[:id] != current_user.id.to_s
      base_params[:role] = params[:user][:role] if params[:user][:role].present?
    end
    
    base_params
  end

  private

  def can_modify_user_roles?
    # Only organization owners and system admins can modify roles
    current_user&.owner? || current_user&.admin?
  end
end
