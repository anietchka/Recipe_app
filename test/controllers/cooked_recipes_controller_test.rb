require "test_helper"

class CookedRecipesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.find_or_create_by!(email: "demo@example.com")

    # Create recipes
    @recipe1 = Recipe.create!(
      title: "Pasta Carbonara",
      cook_time: 20,
      prep_time: 10,
      image_url: "https://example.com/pasta.jpg",
      category: "Italian",
      ratings: 4.5
    )

    @recipe2 = Recipe.create!(
      title: "Chocolate Cake",
      cook_time: 45,
      prep_time: 15,
      image_url: "https://example.com/cake.jpg",
      category: "Dessert",
      ratings: 4.8
    )

    # Create cooked recipes for the user
    @cooked_recipe1 = CookedRecipe.create!(
      user: @user,
      recipe: @recipe1,
      cooked_at: 2.days.ago
    )

    @cooked_recipe2 = CookedRecipe.create!(
      user: @user,
      recipe: @recipe2,
      cooked_at: 1.day.ago
    )
  end

  test "should get index" do
    get cooked_recipes_url
    assert_response :success
  end

  test "index should display user's cooked recipes" do
    get cooked_recipes_url
    assert_response :success
  end

  test "index should list all cooked recipes for the user" do
    get cooked_recipes_url
    assert_response :success
    assert_select ".recipe-card", count: 2
  end

  test "index should display recipes in reverse chronological order" do
    get cooked_recipes_url
    assert_response :success

    # Most recent first (recipe2 cooked 1 day ago)
    # Check that recipe2 appears before recipe1
    body = response.body
    recipe2_index = body.index(@recipe2.title)
    recipe1_index = body.index(@recipe1.title)

    assert_not_nil recipe2_index
    assert_not_nil recipe1_index
    assert recipe2_index < recipe1_index, "Most recent recipe should appear first"
  end

  test "cooking a recipe again moves it to the top of history" do
    # Cook recipe1 again (it was cooked 2 days ago)
    @recipe1.cook!(@user)

    get cooked_recipes_url
    assert_response :success

    # recipe1 should now appear first (most recent)
    body = response.body
    recipe1_index = body.index(@recipe1.title)
    recipe2_index = body.index(@recipe2.title)

    assert_not_nil recipe1_index
    assert_not_nil recipe2_index
    assert recipe1_index < recipe2_index, "Recipe1 should appear first after being cooked again"

    # Should still have only 2 recipes (no duplicates)
    assert_select ".recipe-card", count: 2
  end

  test "index should only show cooked recipes for current user" do
    other_user = User.create!(email: "other@example.com")
    other_recipe = Recipe.create!(title: "Other Recipe")
    CookedRecipe.create!(user: other_user, recipe: other_recipe)

    get cooked_recipes_url
    assert_response :success

    # Should not show other user's cooked recipes
    assert_select ".recipe-card", count: 2
    assert_not_includes response.body, other_recipe.title
  end
end
