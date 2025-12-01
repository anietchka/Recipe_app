require "test_helper"

class RecipeIngredientTest < ActiveSupport::TestCase
  setup do
    @recipe = Recipe.create!(title: "Pasta Carbonara")
    @ingredient = Ingredient.create!(name: "Eggs", canonical_name: "eggs")
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
      unit: "pieces"
    )
    assert recipe_ingredient.valid?
    assert_equal 2.0, recipe_ingredient.quantity
    assert_equal "pieces", recipe_ingredient.unit
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
end
