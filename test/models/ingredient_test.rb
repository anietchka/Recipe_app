require "test_helper"

class IngredientTest < ActiveSupport::TestCase
  # Tests for canonicalize method
  test "canonicalize converts to lowercase" do
    assert_equal "onion", Ingredient.canonicalize("ONION")
    assert_equal "yellow onion", Ingredient.canonicalize("Yellow Onion")
  end

  test "canonicalize removes non-alphabetic characters" do
    assert_equal "onion", Ingredient.canonicalize("onion!")
    assert_equal "yellow onion", Ingredient.canonicalize("yellow-onion")
    assert_equal "tomato", Ingredient.canonicalize("tomato123")
  end

  test "canonicalize compresses spaces" do
    assert_equal "yellow onion", Ingredient.canonicalize("yellow  onion")
    assert_equal "fresh basil", Ingredient.canonicalize("fresh   basil")
  end

  test "canonicalize trims whitespace" do
    assert_equal "onion", Ingredient.canonicalize("  onion  ")
    assert_equal "yellow onion", Ingredient.canonicalize(" yellow onion ")
  end

  test "canonicalize handles complex examples" do
    assert_equal "yellow onions finely chopped", Ingredient.canonicalize("2 Yellow Onions, finely chopped!")
    assert_equal "fresh basil leaves g", Ingredient.canonicalize("Fresh Basil Leaves (10g)")
  end

  # Tests for model validations
  test "should be valid with name and canonical_name" do
    ingredient = Ingredient.new(name: "Yellow Onion", canonical_name: "yellow onion")
    assert ingredient.valid?
  end

  test "should require canonical_name" do
    ingredient = Ingredient.new(name: "Yellow Onion")
    assert_not ingredient.valid?
    assert_includes ingredient.errors[:canonical_name], I18n.t("errors.messages.blank")
  end

  test "should have unique canonical_name" do
    Ingredient.create!(name: "Yellow Onion", canonical_name: "yellow onion")
    duplicate = Ingredient.new(name: "Onion", canonical_name: "yellow onion")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:canonical_name], I18n.t("errors.messages.taken")
  end

  # Tests for associations
  test "should have many recipe_ingredients" do
    ingredient = Ingredient.create!(name: "Onion", canonical_name: "onion")
    assert_respond_to ingredient, :recipe_ingredients
  end

  test "should have many recipes through recipe_ingredients" do
    ingredient = Ingredient.create!(name: "Onion", canonical_name: "onion")
    assert_respond_to ingredient, :recipes
  end

  test "should have many pantry_items" do
    ingredient = Ingredient.create!(name: "Onion", canonical_name: "onion")
    assert_respond_to ingredient, :pantry_items
  end
end
