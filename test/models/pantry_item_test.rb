require "test_helper"

class PantryItemTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "demo@example.com")
    @ingredient = Ingredient.create!(
      name: "Pasta",
      canonical_name: "pasta"
    )
  end

  test "should be valid with user, ingredient, and quantity" do
    pantry_item = PantryItem.new(
      user: @user,
      ingredient: @ingredient,
      quantity: 500.0,
      unit: "g"
    )
    assert pantry_item.valid?
  end

  test "should require user" do
    pantry_item = PantryItem.new(
      ingredient: @ingredient,
      quantity: 500.0
    )
    assert_not pantry_item.valid?
    assert_includes pantry_item.errors[:user], I18n.t("errors.messages.blank")
  end

  test "should require ingredient" do
    pantry_item = PantryItem.new(
      user: @user,
      quantity: 500.0
    )
    assert_not pantry_item.valid?
    assert_includes pantry_item.errors[:ingredient], I18n.t("errors.messages.blank")
  end

  test "should require quantity or fraction" do
    pantry_item = PantryItem.new(
      user: @user,
      ingredient: @ingredient
    )
    assert_not pantry_item.valid?
    assert_includes pantry_item.errors[:base], I18n.t("activerecord.errors.models.pantry_item.attributes.base.quantity_or_fraction_required")
  end

  test "should be valid with only fraction" do
    pantry_item = PantryItem.new(
      user: @user,
      ingredient: @ingredient,
      fraction: "1/2"
    )
    assert pantry_item.valid?
  end

  test "should be valid with only quantity" do
    pantry_item = PantryItem.new(
      user: @user,
      ingredient: @ingredient,
      quantity: 500.0
    )
    assert pantry_item.valid?
  end

  test "should be valid with quantity and fraction" do
    pantry_item = PantryItem.new(
      user: @user,
      ingredient: @ingredient,
      quantity: 1.0,
      fraction: "1/2"
    )
    assert pantry_item.valid?
  end

  test "should validate quantity is numeric" do
    pantry_item = PantryItem.new(
      user: @user,
      ingredient: @ingredient,
      quantity: "not a number"
    )
    assert_not pantry_item.valid?
    assert_includes pantry_item.errors[:quantity], I18n.t("errors.messages.not_a_number")
  end

  test "should validate quantity is greater than or equal to zero" do
    pantry_item = PantryItem.new(
      user: @user,
      ingredient: @ingredient,
      quantity: -1.0
    )
    assert_not pantry_item.valid?
    assert_includes pantry_item.errors[:quantity], I18n.t("errors.messages.greater_than_or_equal_to", count: 0)
  end

  test "should belong to user" do
    pantry_item = PantryItem.create!(
      user: @user,
      ingredient: @ingredient,
      quantity: 500.0
    )
    assert_equal @user, pantry_item.user
  end

  test "should belong to ingredient" do
    pantry_item = PantryItem.create!(
      user: @user,
      ingredient: @ingredient,
      quantity: 500.0
    )
    assert_equal @ingredient, pantry_item.ingredient
  end

  test "should have unique combination of user and ingredient" do
    PantryItem.create!(
      user: @user,
      ingredient: @ingredient,
      quantity: 500.0
    )

    duplicate = PantryItem.new(
      user: @user,
      ingredient: @ingredient,
      quantity: 300.0
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:ingredient_id], I18n.t("errors.messages.taken")
  end

  test "should allow same ingredient for different users" do
    user2 = User.create!(email: "user2@example.com")
    PantryItem.create!(
      user: @user,
      ingredient: @ingredient,
      quantity: 500.0
    )

    pantry_item2 = PantryItem.new(
      user: user2,
      ingredient: @ingredient,
      quantity: 300.0
    )
    assert pantry_item2.valid?
  end

  test "should destroy pantry items when user is destroyed" do
    pantry_item = PantryItem.create!(
      user: @user,
      ingredient: @ingredient,
      quantity: 500.0
    )

    @user.destroy
    assert_nil PantryItem.find_by(id: pantry_item.id)
  end

  test "should destroy pantry items when ingredient is destroyed" do
    pantry_item = PantryItem.create!(
      user: @user,
      ingredient: @ingredient,
      quantity: 500.0
    )

    @ingredient.destroy
    assert_nil PantryItem.find_by(id: pantry_item.id)
  end

  test "available_quantity returns total quantity when quantity and fraction are present" do
    pantry_item = PantryItem.create!(
      user: @user,
      ingredient: @ingredient,
      quantity: 1.0,
      fraction: "1/2"
    )

    # 1 + 0.5 = 1.5
    assert_equal 1.5, pantry_item.available_quantity
  end

  test "available_quantity returns quantity when no fraction" do
    pantry_item = PantryItem.create!(
      user: @user,
      ingredient: @ingredient,
      quantity: 200.0,
      fraction: nil
    )

    assert_equal 200.0, pantry_item.available_quantity
  end

  test "available_quantity returns fraction value when only fraction is present" do
    pantry_item = PantryItem.create!(
      user: @user,
      ingredient: @ingredient,
      quantity: nil,
      fraction: "1/2"
    )

    assert_equal 0.5, pantry_item.available_quantity
  end

  test "available_quantity returns 0.0 when quantity is 0 and fraction is blank" do
    pantry_item = PantryItem.create!(
      user: @user,
      ingredient: @ingredient,
      quantity: 0.0,
      fraction: nil
    )

    assert_equal 0.0, pantry_item.available_quantity
  end

  test "available_quantity handles complex fractions" do
    pantry_item = PantryItem.create!(
      user: @user,
      ingredient: @ingredient,
      quantity: 2.0,
      fraction: "3/4"
    )

    # 2 + 0.75 = 2.75
    assert_equal 2.75, pantry_item.available_quantity
  end
end
