require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "should be valid with email" do
    user = User.new(email: "demo@example.com")
    assert user.valid?
  end

  test "should require email" do
    user = User.new
    assert_not user.valid?
    assert_includes user.errors[:email], I18n.t("errors.messages.blank")
  end

  test "should have unique email" do
    User.create!(email: "demo@example.com")
    duplicate_user = User.new(email: "demo@example.com")
    assert_not duplicate_user.valid?
    assert_includes duplicate_user.errors[:email], I18n.t("errors.messages.taken")
  end

  test "should have many pantry_items" do
    user = User.create!(email: "demo@example.com")
    assert_respond_to user, :pantry_items
  end
end
