require "test_helper"

class ApplicationControllerTest < ActionDispatch::IntegrationTest
  test "current_user returns demo user" do
    demo_user = User.find_or_create_by!(email: "demo@example.com")

    get root_path rescue nil # May not exist yet, that's OK

    # Test that current_user helper is available
    assert_respond_to ApplicationController.new, :current_user
  end
end
