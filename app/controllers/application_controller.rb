class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # Simple authentication: return the demo user
  # For this prototype, we use a single demo user
  def current_user
    @current_user ||= User.find_by(email: "demo@example.com") || User.first
  end
  helper_method :current_user

  # Helper method to determine if a navbar link should be active
  def navbar_active?(controller)
    controller_name == controller
  end
  helper_method :navbar_active?
end
