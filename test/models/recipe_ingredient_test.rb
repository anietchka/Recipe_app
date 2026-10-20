require "test_helper"

class RecipeIngredientTest < ActiveSupport::TestCase
  setup do
    @recipe = Recipe.create!(title: "Pasta Carbonara")
    @ingredient = Ingredient.create!(name: "Eggs", canonical_name: "egg")
  end

  test "should be valid with recipe and ingredient" do
    recipe_ingredient = RecipeIngredient.new(
      recipe: @recipe,
      ingredient: @ingredient,
      original_text: "2 eggs, beaten"
    )
    assert recipe_ingredient.valid?
  end

  test "should require recipe" do
    recipe_ingredient = RecipeIngredient.new(
      ingredient: @ingredient,
      original_text: "2 eggs"
    )
    assert_not recipe_ingredient.valid?
    assert_includes recipe_ingredient.errors[:recipe], I18n.t("errors.messages.required")
  end

  test "should require ingredient" do
    recipe_ingredient = RecipeIngredient.new(
      recipe: @recipe,
      original_text: "2 eggs"
    )
    assert_not recipe_ingredient.valid?
    assert_includes recipe_ingredient.errors[:ingredient], I18n.t("errors.messages.required")
  end

  test "should accept optional quantity and unit" do
    recipe_ingredient = RecipeIngredient.new(
      recipe: @recipe,
      ingredient: @ingredient,
      original_text: "2 eggs",
      quantity: 2.0,
      unit: "pcs"
    )
    assert recipe_ingredient.valid?
    assert_equal 2.0, recipe_ingredient.quantity
    assert_equal "pcs", recipe_ingredient.unit
  end

  test "should belong to recipe" do
    recipe_ingredient = RecipeIngredient.create!(
      recipe: @recipe,
      ingredient: @ingredient,
      original_text: "2 eggs"
    )
    assert_equal @recipe, recipe_ingredient.recipe
  end

  test "should belong to ingredient" do
    recipe_ingredient = RecipeIngredient.create!(
      recipe: @recipe,
      ingredient: @ingredient,
      original_text: "2 eggs"
    )
    assert_equal @ingredient, recipe_ingredient.ingredient
  end

  test "should accept nil quantity" do
    recipe_ingredient = RecipeIngredient.new(
      recipe: @recipe,
      ingredient: @ingredient,
      original_text: "some eggs",
      quantity: nil
    )
    assert recipe_ingredient.valid?
    assert_nil recipe_ingredient.quantity
  end

  test "stores a fractional quantity as a single decimal" do
    recipe_ingredient = RecipeIngredient.create!(
      recipe: @recipe,
      ingredient: @ingredient,
      original_text: "1 ½ kg flour",
      quantity: 1.5,
      unit: "kg"
    )

    assert_equal 1.5, recipe_ingredient.reload.quantity
  end

  test "does not default a missing quantity to 1" do
    recipe_ingredient = RecipeIngredient.create!(
      recipe: @recipe,
      ingredient: @ingredient,
      original_text: "salt to taste"
    )

    assert_nil recipe_ingredient.reload.quantity
  end

  test "should accept valid unit from MEASUREMENT_UNITS" do
    Ingredient::MEASUREMENT_UNITS.each do |unit|
      recipe_ingredient = RecipeIngredient.new(
        recipe: @recipe,
        ingredient: @ingredient,
        original_text: "100 #{unit} ingredient",
        quantity: 100.0,
        unit: unit
      )
      assert recipe_ingredient.valid?, "Unit #{unit} should be valid"
    end
  end

  test "should reject invalid unit" do
    recipe_ingredient = RecipeIngredient.new(
      recipe: @recipe,
      ingredient: @ingredient,
      original_text: "100 invalid_unit ingredient",
      quantity: 100.0,
      unit: "invalid_unit"
    )
    assert_not recipe_ingredient.valid?
    assert_includes recipe_ingredient.errors[:unit], I18n.t("errors.messages.inclusion")
  end

  test "should accept nil unit" do
    recipe_ingredient = RecipeIngredient.new(
      recipe: @recipe,
      ingredient: @ingredient,
      original_text: "some ingredient",
      quantity: 100.0,
      unit: nil
    )
    assert recipe_ingredient.valid?
  end
end
