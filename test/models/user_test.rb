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

  test "should only access own pantry items" do
    user1 = User.create!(email: "user1@example.com")
    user2 = User.create!(email: "user2@example.com")
    ingredient = Ingredient.create!(name: "Pasta", canonical_name: "pasta")

    pantry_item1 = PantryItem.create!(
      user: user1,
      ingredient: ingredient,
      quantity: 500.0
    )

    pantry_item2 = PantryItem.create!(
      user: user2,
      ingredient: ingredient,
      quantity: 300.0
    )

    assert_includes user1.pantry_items, pantry_item1
    assert_not_includes user1.pantry_items, pantry_item2

    assert_includes user2.pantry_items, pantry_item2
    assert_not_includes user2.pantry_items, pantry_item1
  end
end
