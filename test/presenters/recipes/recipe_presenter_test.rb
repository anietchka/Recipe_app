require "test_helper"

module Recipes
  class RecipePresenterTest < ActiveSupport::TestCase
    setup do
      @user = User.create!(email: "demo@example.com")

      # Create ingredients
      @pasta = Ingredient.create!(name: "Pasta", canonical_name: "pasta")
      @eggs = Ingredient.create!(name: "Eggs", canonical_name: "egg")
      @cheese = Ingredient.create!(name: "Cheese", canonical_name: "cheese")
      @salt = Ingredient.create!(name: "Salt", canonical_name: "salt")

      # Create recipe
      @recipe = Recipe.create!(
        title: "Pasta Carbonara",
        cook_time: 20,
        prep_time: 10,
        image_url: "https://example.com/pasta.jpg",
        category: "Italian",
        ratings: 4.5
      )

      RecipeIngredient.create!(
        recipe: @recipe,
        ingredient: @pasta,
        quantity: 200.0,
        unit: "g",
        original_text: "200g pasta"
      )

      RecipeIngredient.create!(
        recipe: @recipe,
        ingredient: @eggs,
        quantity: 2.0,
        unit: "pcs",
        original_text: "2 eggs"
      )

      RecipeIngredient.create!(
        recipe: @recipe,
        ingredient: @cheese,
        quantity: 100.0,
        unit: "g",
        original_text: "100g cheese"
      )

      RecipeIngredient.create!(
        recipe: @recipe,
        ingredient: @salt,
        quantity: nil,
        fraction: nil,
        original_text: "salt to taste"
      )

      @presenter = RecipePresenter.new(@recipe, @user)
    end

    test "initializes with recipe and user" do
      assert_equal @recipe, @presenter.recipe
      assert_equal @user, @presenter.user
    end

    test "delegates id to recipe" do
      assert_equal @recipe.id, @presenter.id
    end

    test "delegates to_param to recipe" do
      assert_equal @recipe.to_param, @presenter.to_param
    end

    test "delegates title to recipe" do
      assert_equal "Pasta Carbonara", @presenter.title
    end

    test "delegates cook_time to recipe" do
      assert_equal 20, @presenter.cook_time
    end

    test "delegates prep_time to recipe" do
      assert_equal 10, @presenter.prep_time
    end

    test "delegates image_url to recipe" do
      assert_equal "https://example.com/pasta.jpg", @presenter.image_url
    end

    test "delegates category to recipe" do
      assert_equal "Italian", @presenter.category
    end

    test "delegates ratings to recipe" do
      assert_equal 4.5, @presenter.ratings
    end

    test "has_time_info? returns true when prep_time or cook_time present" do
      assert @presenter.has_time_info?
    end

    test "has_time_info? returns false when no time info" do
      recipe_no_time = Recipe.create!(title: "No Time Recipe")
      presenter = RecipePresenter.new(recipe_no_time, @user)
      assert_not presenter.has_time_info?
    end

    test "has_prep_time? returns true when prep_time present" do
      assert @presenter.has_prep_time?
    end

    test "has_cook_time? returns true when cook_time present" do
      assert @presenter.has_cook_time?
    end

    test "has_ratings? returns true when ratings present" do
      assert @presenter.has_ratings?
    end

    test "has_category? returns true when category present" do
      assert @presenter.has_category?
    end

    test "has_image_url? returns true when image_url present" do
      assert @presenter.has_image_url?
    end

    test "total_ingredients_count returns count of recipe ingredients" do
      assert_equal 4, @presenter.total_ingredients_count
    end

    test "total_ingredients_count uses precalculated value when available" do
      @recipe.instance_variable_set(:@total_ingredients_count, 10)
      assert_equal 10, @presenter.total_ingredients_count
    end

    test "missing_ingredients returns array of missing ingredients" do
      missing = @presenter.missing_ingredients
      assert missing.is_a?(Array)
      # All ingredients should be missing since user has no pantry items
      assert_equal 4, missing.count
    end

    test "missing_count returns count of missing ingredients" do
      assert_equal 4, @presenter.missing_count
    end

    test "missing_count uses precalculated value when available" do
      @recipe.instance_variable_set(:@missing_ingredients_count, 2)
      assert_equal 2, @presenter.missing_count
    end

    test "matched_ingredients returns count when user has all ingredients" do
      PantryItem.create!(user: @user, ingredient: @pasta, quantity: 500.0, unit: "g")
      PantryItem.create!(user: @user, ingredient: @eggs, quantity: 6.0, unit: "pcs")
      PantryItem.create!(user: @user, ingredient: @cheese, quantity: 200.0, unit: "g")
      PantryItem.create!(user: @user, ingredient: @salt)

      presenter = RecipePresenter.new(@recipe, @user)
      assert_equal 4, presenter.matched_ingredients
    end

    test "matched_ingredients uses precalculated value when available" do
      @recipe.instance_variable_set(:@matched_ingredients_count, 3)
      assert_equal 3, @presenter.matched_ingredients
    end

    test "completion_percentage calculates correctly" do
      PantryItem.create!(user: @user, ingredient: @pasta, quantity: 500.0, unit: "g")
      PantryItem.create!(user: @user, ingredient: @eggs, quantity: 6.0, unit: "pcs")

      presenter = RecipePresenter.new(@recipe, @user)
      # 2 out of 4 ingredients = 50%
      assert_equal 50, presenter.completion_percentage
    end

    test "completion_percentage returns 0 when no ingredients" do
      empty_recipe = Recipe.create!(title: "Empty Recipe")
      presenter = RecipePresenter.new(empty_recipe, @user)
      assert_equal 0, presenter.completion_percentage
    end

    test "status_class returns ready when no missing ingredients" do
      PantryItem.create!(user: @user, ingredient: @pasta, quantity: 500.0, unit: "g")
      PantryItem.create!(user: @user, ingredient: @eggs, quantity: 6.0, unit: "pcs")
      PantryItem.create!(user: @user, ingredient: @cheese, quantity: 200.0, unit: "g")
      PantryItem.create!(user: @user, ingredient: @salt)

      presenter = RecipePresenter.new(@recipe, @user)
      assert_equal "recipe-status--ready", presenter.status_class
    end

    test "status_class returns almost when 1-3 missing ingredients" do
      PantryItem.create!(user: @user, ingredient: @pasta, quantity: 500.0, unit: "g")
      PantryItem.create!(user: @user, ingredient: @eggs, quantity: 6.0, unit: "pcs")

      presenter = RecipePresenter.new(@recipe, @user)
      assert_equal "recipe-status--almost", presenter.status_class
    end

    test "status_class returns shopping when more than 3 missing ingredients" do
      presenter = RecipePresenter.new(@recipe, @user)
      assert_equal "recipe-status--shopping", presenter.status_class
    end

    test "status_text returns correct translation for ready status" do
      PantryItem.create!(user: @user, ingredient: @pasta, quantity: 500.0, unit: "g")
      PantryItem.create!(user: @user, ingredient: @eggs, quantity: 6.0, unit: "pcs")
      PantryItem.create!(user: @user, ingredient: @cheese, quantity: 200.0, unit: "g")
      PantryItem.create!(user: @user, ingredient: @salt)

      presenter = RecipePresenter.new(@recipe, @user)
      assert_equal I18n.t("recipes.index.status_ready"), presenter.status_text
    end

    test "no_available_ingredients? returns true when no matched ingredients" do
      assert @presenter.no_available_ingredients?
    end

    test "no_available_ingredients? returns false when some ingredients available" do
      PantryItem.create!(user: @user, ingredient: @pasta, quantity: 500.0, unit: "g")
      presenter = RecipePresenter.new(@recipe, @user)
      assert_not presenter.no_available_ingredients?
    end

    test "available_ingredients returns array with available ingredients and pantry items" do
      PantryItem.create!(user: @user, ingredient: @pasta, quantity: 500.0, unit: "g")
      PantryItem.create!(user: @user, ingredient: @eggs, quantity: 6.0, unit: "pcs")

      presenter = RecipePresenter.new(@recipe, @user)
      available = presenter.available_ingredients

      assert_equal 2, available.count
      assert_equal @pasta.id, available.first[:recipe_ingredient].ingredient_id
      assert_not_nil available.first[:pantry_item]
    end

    test "available_ingredients includes pantry items without quantity" do
      PantryItem.create!(user: @user, ingredient: @salt)
      presenter = RecipePresenter.new(@recipe, @user)
      available = presenter.available_ingredients

      salt_item = available.find { |a| a[:recipe_ingredient].ingredient_id == @salt.id }
      assert_not_nil salt_item
      assert_not_nil salt_item[:pantry_item]
    end

    test "format_ingredient_quantity formats quantity with unit" do
      recipe_ingredient = @recipe.recipe_ingredients.find_by(ingredient: @pasta)
      formatted = @presenter.format_ingredient_quantity(recipe_ingredient)
      assert_equal "200.0 g", formatted
    end

    test "format_ingredient_quantity formats quantity with fraction" do
      recipe_ingredient = RecipeIngredient.create!(
        recipe: @recipe,
        ingredient: @eggs,
        quantity: 1.0,
        fraction: "1/2",
        unit: "cup"
      )
      formatted = @presenter.format_ingredient_quantity(recipe_ingredient)
      assert_equal "1.0 1/2 cup", formatted
    end

    test "format_ingredient_quantity returns original_text when no quantity" do
      recipe_ingredient = @recipe.recipe_ingredients.find_by(ingredient: @salt)
      formatted = @presenter.format_ingredient_quantity(recipe_ingredient)
      assert_equal "salt to taste", formatted
    end

    test "format_pantry_quantity formats quantity with unit" do
      pantry_item = PantryItem.create!(
        user: @user,
        ingredient: @pasta,
        quantity: 500.0,
        unit: "g"
      )
      formatted = @presenter.format_pantry_quantity(pantry_item)
      assert_equal "500.0 g", formatted
    end

    test "format_pantry_quantity returns present translation when empty" do
      pantry_item = PantryItem.create!(user: @user, ingredient: @salt)
      formatted = @presenter.format_pantry_quantity(pantry_item)
      assert_equal I18n.t("recipes.show.present"), formatted
    end

    test "format_missing_quantity formats missing quantity with unit" do
      missing_info = {
        missing_quantity: 100.0,
        missing_fraction: nil,
        recipe_ingredient: @recipe.recipe_ingredients.find_by(ingredient: @pasta)
      }
      formatted = @presenter.format_missing_quantity(missing_info)
      assert_equal "100.0 g", formatted
    end

    test "format_missing_quantity formats missing quantity with fraction" do
      missing_info = {
        missing_quantity: 1.0,
        missing_fraction: "1/2",
        recipe_ingredient: @recipe.recipe_ingredients.find_by(ingredient: @eggs)
      }
      formatted = @presenter.format_missing_quantity(missing_info)
      assert_equal "1.0 1/2 pcs", formatted
    end

    test "format_missing_quantity handles missing quantity without unit" do
      recipe_ingredient = RecipeIngredient.create!(
        recipe: @recipe,
        ingredient: @salt,
        quantity: nil,
        original_text: "salt"
      )
      missing_info = {
        missing_quantity: nil,
        missing_fraction: nil,
        recipe_ingredient: recipe_ingredient
      }
      formatted = @presenter.format_missing_quantity(missing_info)
      assert_equal "", formatted
    end
  end
end
