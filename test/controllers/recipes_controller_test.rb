require "test_helper"

class RecipesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.find_or_create_by!(email: "demo@example.com")

    # Create ingredients
    @pasta = Ingredient.create!(name: "Pasta", canonical_name: "pasta")
    @eggs = Ingredient.create!(name: "Eggs", canonical_name: "egg")
    @cheese = Ingredient.create!(name: "Cheese", canonical_name: "cheese")

    # Create recipe
    @recipe = Recipe.create!(
      title: "Pasta Carbonara",
      cook_time: 20,
      prep_time: 10,
      image_url: "https://example.com/pasta.jpg",
      category: "Italian",
      ratings: 4.5
    )

    RecipeIngredient.create!(recipe: @recipe, ingredient: @pasta, original_text: "200g pasta", quantity: 200.0, unit: "g")
    RecipeIngredient.create!(recipe: @recipe, ingredient: @eggs, original_text: "2 eggs", quantity: 2.0, unit: "pcs")
    RecipeIngredient.create!(recipe: @recipe, ingredient: @cheese, original_text: "100g cheese", quantity: 100.0, unit: "g")

    # Add some ingredients to user's pantry
    PantryItem.create!(user: @user, ingredient: @pasta, quantity: 500.0, unit: "g")
    PantryItem.create!(user: @user, ingredient: @eggs, quantity: 6.0, unit: "pcs")
  end

  test "should get index" do
    get recipes_url
    assert_response :success
  end

  test "index should display recipes found by Finder service" do
    get recipes_url
    assert_response :success
    assert_select "h1", text: /Recipes/
    assert_select ".recipe-card", minimum: 1
  end

  test "index should show recipe score information" do
    get recipes_url
    assert_response :success
    assert_select ".recipe-card__score"
  end

  test "should get show" do
    get recipe_url(@recipe)
    assert_response :success
  end

  test "show should display recipe details" do
    get recipe_url(@recipe)
    assert_response :success
    assert_select ".recipe-show-title", text: @recipe.title
    assert_select ".recipe-show-ingredients"
    assert_select ".recipe-show-ingredients-list"
  end

  test "show should display missing ingredients" do
    get recipe_url(@recipe)
    assert_response :success
    # Cheese is missing from pantry
    assert_select ".recipe-show-ingredient-item--missing"
  end

  test "show should display available ingredients" do
    get recipe_url(@recipe)
    assert_response :success
    # Pasta and eggs are in pantry
    assert_select ".recipe-show-ingredient-item--available"
  end

  test "should cook recipe and decrement pantry items" do
    pasta_item = @user.pantry_items.find_by(ingredient: @pasta)
    eggs_item = @user.pantry_items.find_by(ingredient: @eggs)

    initial_pasta_quantity = pasta_item.available_quantity
    initial_eggs_quantity = eggs_item.available_quantity

    post cook_recipe_url(@recipe)

    assert_redirected_to pantry_items_url
    assert_equal I18n.t("recipes.cook.success"), flash[:notice]

    pasta_item.reload
    eggs_item.reload

    # Pasta: 500g - 200g = 300g
    assert_equal 300.0, pasta_item.available_quantity
    # Eggs: 6 - 2 = 4
    assert_equal 4.0, eggs_item.available_quantity
  end

  test "cook should handle recipe with insufficient ingredients" do
    # Reduce pasta to less than required
    pasta_item = @user.pantry_items.find_by(ingredient: @pasta)
    pasta_item.update!(quantity: 100.0, fraction: nil)

    post cook_recipe_url(@recipe)

    assert_redirected_to pantry_items_url
    pasta_item.reload

    # Should not go below 0
    assert_equal 0.0, pasta_item.available_quantity
  end

  test "cook should ignore ingredients not in pantry" do
    # Cheese is not in pantry, should be ignored
    cheese_count_before = PantryItem.where(user: @user, ingredient: @cheese).count

    post cook_recipe_url(@recipe)

    assert_redirected_to pantry_items_url
    cheese_count_after = PantryItem.where(user: @user, ingredient: @cheese).count

    assert_equal cheese_count_before, cheese_count_after
  end

  test "cook should work with PATCH method" do
    patch cook_recipe_url(@recipe)

    assert_redirected_to pantry_items_url
  end
end
