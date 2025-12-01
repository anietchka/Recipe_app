require "test_helper"

class RecipeTest < ActiveSupport::TestCase
  test "should be valid with title" do
    recipe = Recipe.new(title: "Pasta Carbonara")
    assert recipe.valid?
  end

  test "should require title" do
    recipe = Recipe.new
    assert_not recipe.valid?
    assert_includes recipe.errors[:title], I18n.t("errors.messages.blank")
  end

  test "should have many recipe_ingredients" do
    recipe = Recipe.create!(title: "Pasta Carbonara")
    assert_respond_to recipe, :recipe_ingredients
  end

  test "should have many ingredients through recipe_ingredients" do
    recipe = Recipe.create!(title: "Pasta Carbonara")
    assert_respond_to recipe, :ingredients
  end

  test "should accept optional attributes" do
    recipe = Recipe.new(
      title: "Pasta Carbonara",
      description: "A classic Italian dish",
      instructions: "Cook pasta, mix with eggs and bacon",
      total_time_minutes: 30,
      image_url: "https://example.com/pasta.jpg",
      source_url: "https://example.com/recipe",
      rating: 4.5,
      ratings_count: 100
    )
    assert recipe.valid?
  end
end
