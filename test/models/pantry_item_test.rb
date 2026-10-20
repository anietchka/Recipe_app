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

  test "should be valid with only ingredient (no quantity, no unit) - untracked quantity" do
    pantry_item = PantryItem.new(
      user: @user,
      ingredient: @ingredient
    )
    assert pantry_item.valid?
  end

  test "should validate quantity is strictly greater than zero when present" do
    pantry_item = PantryItem.new(
      user: @user,
      ingredient: @ingredient,
      quantity: 0.0
    )
    assert_not pantry_item.valid?
    assert_includes pantry_item.errors[:quantity], I18n.t("errors.messages.greater_than", count: 0)
  end

  test "should validate quantity is strictly greater than zero when present (negative)" do
    pantry_item = PantryItem.new(
      user: @user,
      ingredient: @ingredient,
      quantity: -1.0
    )
    assert_not pantry_item.valid?
    assert_includes pantry_item.errors[:quantity], I18n.t("errors.messages.greater_than", count: 0)
  end

  test "should be valid with a fractional decimal quantity" do
    pantry_item = PantryItem.new(
      user: @user,
      ingredient: @ingredient,
      quantity: 0.5,
      unit: "kg"
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

  test "should validate quantity is numeric" do
    pantry_item = PantryItem.new(
      user: @user,
      ingredient: @ingredient,
      quantity: "not a number"
    )
    assert_not pantry_item.valid?
    assert_includes pantry_item.errors[:quantity], I18n.t("errors.messages.not_a_number")
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

  test "keeps quantity nil when created without quantity" do
    pantry_item = PantryItem.create!(user: @user, ingredient: @ingredient)

    assert_nil pantry_item.reload.quantity
  end

  test "should accept valid unit from MEASUREMENT_UNITS" do
    Ingredient::MEASUREMENT_UNITS.each do |unit|
      pantry_item = PantryItem.new(
        user: @user,
        ingredient: @ingredient,
        quantity: 100.0,
        unit: unit
      )
      assert pantry_item.valid?, "Unit #{unit} should be valid"
    end
  end

  test "should reject invalid unit" do
    pantry_item = PantryItem.new(
      user: @user,
      ingredient: @ingredient,
      quantity: 100.0,
      unit: "invalid_unit"
    )
    assert_not pantry_item.valid?
    assert_includes pantry_item.errors[:unit], I18n.t("errors.messages.inclusion")
  end

  test "should accept nil unit" do
    pantry_item = PantryItem.new(
      user: @user,
      ingredient: @ingredient,
      quantity: 100.0,
      unit: nil
    )
    assert pantry_item.valid?
  end

  # sufficient_for? (matching rule shared by Recipes::Finder and the recipe detail)

  def pantry(quantity, unit)
    PantryItem.new(user: @user, ingredient: @ingredient, quantity: quantity, unit: unit)
  end

  def required(quantity, unit)
    RecipeIngredient.new(ingredient: @ingredient, quantity: quantity, unit: unit)
  end

  test "sufficient_for? is true when the pantry quantity is untracked" do
    assert pantry(nil, nil).sufficient_for?(required(500, "g"))
  end

  test "sufficient_for? is true when the recipe gives no quantity" do
    assert pantry(1, "g").sufficient_for?(required(nil, nil))
  end

  test "sufficient_for? compares quantities in the same unit" do
    assert pantry(500, "g").sufficient_for?(required(500, "g"))
    assert_not pantry(300, "g").sufficient_for?(required(500, "g"))
  end

  test "sufficient_for? converts compatible weight units" do
    assert pantry(1, "kg").sufficient_for?(required(500, "g"))
  end

  test "sufficient_for? converts compatible volume units" do
    assert pantry(1, "l").sufficient_for?(required(500, "ml"))
  end

  test "sufficient_for? is false for weight vs volume units" do
    assert_not pantry(1000, "g").sufficient_for?(required(500, "ml"))
    assert_not pantry(1000, "g").sufficient_for?(required(1, "cup"))
  end

  test "sufficient_for? treats a pantry quantity without unit as a count for a recipe in pcs" do
    assert pantry(6, nil).sufficient_for?(required(2, "pcs"))
    assert_not pantry(1, nil).sufficient_for?(required(2, "pcs"))
  end

  test "sufficient_for? compares numbers directly when both units are blank" do
    assert pantry(3, nil).sufficient_for?(required(2, nil))
    assert_not pantry(1, nil).sufficient_for?(required(2, nil))
  end

  test "sufficient_for? is false for a pantry quantity without unit vs a recipe with a measured unit" do
    assert_not pantry(1000, nil).sufficient_for?(required(500, "g"))
  end

  test "sufficient_for? does not treat a recipe quantity without unit as pcs" do
    assert_not pantry(6, "pcs").sufficient_for?(required(2, nil))
  end

  # quantity_consumed_by (used by Recipes::Cook)

  test "quantity_consumed_by converts the recipe quantity into the pantry unit" do
    assert_equal 0.5, pantry(1, "kg").quantity_consumed_by(required(500, "g"))
  end

  test "quantity_consumed_by counts a recipe in pcs against a pantry quantity without unit" do
    assert_equal 2, pantry(6, nil).quantity_consumed_by(required(2, "pcs"))
  end

  test "quantity_consumed_by is nil when the recipe gives no quantity" do
    assert_nil pantry(1, "kg").quantity_consumed_by(required(nil, nil))
  end

  test "quantity_consumed_by is nil when the units can't be compared" do
    assert_nil pantry(1000, nil).quantity_consumed_by(required(200, "g"))
    assert_nil pantry(6, "pcs").quantity_consumed_by(required(2, nil))
    assert_nil pantry(1, "cup").quantity_consumed_by(required(200, "g"))
  end
end
