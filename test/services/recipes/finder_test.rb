require "test_helper"

module Recipes
  class FinderTest < ActiveSupport::TestCase
    setup do
      @user = User.create!(email: "demo@example.com")

      # Create ingredients
      @pasta = Ingredient.create!(name: "Pasta", canonical_name: "pasta")
      @eggs = Ingredient.create!(name: "Eggs", canonical_name: "egg")
      @cheese = Ingredient.create!(name: "Cheese", canonical_name: "cheese")
      @tomato = Ingredient.create!(name: "Tomato", canonical_name: "tomato")
      @onion = Ingredient.create!(name: "Onion", canonical_name: "onion")
      @garlic = Ingredient.create!(name: "Garlic", canonical_name: "garlic")

      # Create recipes
      @recipe1 = Recipe.create!(title: "Pasta with Eggs")
      RecipeIngredient.create!(recipe: @recipe1, ingredient: @pasta, original_text: "200g pasta")
      RecipeIngredient.create!(recipe: @recipe1, ingredient: @eggs, original_text: "2 eggs")

      @recipe2 = Recipe.create!(title: "Pasta with Cheese")
      RecipeIngredient.create!(recipe: @recipe2, ingredient: @pasta, original_text: "200g pasta")
      RecipeIngredient.create!(recipe: @recipe2, ingredient: @cheese, original_text: "100g cheese")

      @recipe3 = Recipe.create!(title: "Tomato Pasta")
      RecipeIngredient.create!(recipe: @recipe3, ingredient: @pasta, original_text: "200g pasta")
      RecipeIngredient.create!(recipe: @recipe3, ingredient: @tomato, original_text: "2 tomatoes")
      RecipeIngredient.create!(recipe: @recipe3, ingredient: @onion, original_text: "1 onion")
      RecipeIngredient.create!(recipe: @recipe3, ingredient: @garlic, original_text: "2 cloves garlic")
    end

    test "returns recipes sorted by matched_count DESC then missing_count ASC" do
      # User has pasta and eggs in pantry
      PantryItem.create!(user: @user, ingredient: @pasta, quantity: 500.0, unit: "g")
      PantryItem.create!(user: @user, ingredient: @eggs, quantity: 6.0, unit: "pcs")

      recipes = Finder.call(@user)

      # Recipe1 should be first (2/2 ingredients matched)
      assert_equal @recipe1.id, recipes.first.id
      # Recipe2 should be second (1/2 ingredients matched)
      assert_equal @recipe2.id, recipes.second.id
      # Recipe3 should be last (1/4 ingredients matched)
      assert_equal @recipe3.id, recipes.third.id
    end

    test "returns recipes with precalculated scores" do
      PantryItem.create!(user: @user, ingredient: @pasta, quantity: 500.0, unit: "g")
      PantryItem.create!(user: @user, ingredient: @eggs, quantity: 6.0, unit: "pcs")

      recipes = Finder.call(@user)

      recipe1 = recipes.find { |r| r.id == @recipe1.id }
      assert_not_nil recipe1
      # Check precalculated scores
      assert_equal 2, recipe1.matched_ingredients_count
      assert_equal 2, recipe1.total_ingredients_count
      assert_equal 0, recipe1.missing_ingredients_count
    end

    test "supports pagination with limit and offset" do
      # Create more recipes with same ingredient (all will have same score)
      10.times do |i|
        recipe = Recipe.create!(title: "Recipe #{i}")
        RecipeIngredient.create!(recipe: recipe, ingredient: @pasta, original_text: "200g pasta")
      end

      PantryItem.create!(user: @user, ingredient: @pasta, quantity: 500.0, unit: "g")

      # First page: 5 recipes
      page1 = Finder.call(@user, limit: 5, offset: 0)
      assert_equal 5, page1.count

      # Second page: next 5 recipes
      page2 = Finder.call(@user, limit: 5, offset: 5)
      assert page2.count > 0, "Second page should have recipes"

      # Verify limit works
      page3 = Finder.call(@user, limit: 3, offset: 0)
      assert_equal 3, page3.count
    end

    test "returns empty array when user has no pantry items" do
      recipes = Finder.call(@user)
      # Should still return recipes, just sorted differently
      assert recipes.is_a?(Array)
    end

    # Matching rules (same as PantryItem#sufficient_for? used by the recipe detail)

    def recipe_needing(quantity, unit)
      recipe = Recipe.create!(title: "Needs #{quantity} #{unit}")
      RecipeIngredient.create!(recipe: recipe, ingredient: @cheese, original_text: "cheese", quantity: quantity, unit: unit)
      recipe
    end

    def scores_for(recipe)
      found = Finder.call(@user).find { |r| r.id == recipe.id }
      [ found.matched_ingredients_count, found.missing_ingredients_count ]
    end

    test "ingredient absent from the pantry is missing" do
      recipe = recipe_needing(100, "g")

      assert_equal [ 0, 1 ], scores_for(recipe)
    end

    test "pantry item with untracked quantity is matched" do
      recipe = recipe_needing(100, "g")
      PantryItem.create!(user: @user, ingredient: @cheese)

      assert_equal [ 1, 0 ], scores_for(recipe)
    end

    test "recipe ingredient without quantity is matched when present in the pantry" do
      recipe = recipe_needing(nil, nil)
      PantryItem.create!(user: @user, ingredient: @cheese, quantity: 1, unit: "g")

      assert_equal [ 1, 0 ], scores_for(recipe)
    end

    test "compatible units are converted: 1 kg covers 500 g" do
      recipe = recipe_needing(500, "g")
      PantryItem.create!(user: @user, ingredient: @cheese, quantity: 1, unit: "kg")

      assert_equal [ 1, 0 ], scores_for(recipe)
    end

    test "insufficient quantity is missing: 300 g does not cover 500 g" do
      recipe = recipe_needing(500, "g")
      PantryItem.create!(user: @user, ingredient: @cheese, quantity: 300, unit: "g")

      assert_equal [ 0, 1 ], scores_for(recipe)
    end

    test "compatible volume units are converted: 1 l covers 500 ml" do
      recipe = recipe_needing(500, "ml")
      PantryItem.create!(user: @user, ingredient: @cheese, quantity: 1, unit: "l")

      assert_equal [ 1, 0 ], scores_for(recipe)
    end

    test "incompatible units are missing" do
      recipe = recipe_needing(500, "ml")
      PantryItem.create!(user: @user, ingredient: @cheese, quantity: 1000, unit: "g")

      assert_equal [ 0, 1 ], scores_for(recipe)
    end

    test "pantry quantity without unit is compared as a count with a recipe in pcs" do
      recipe = recipe_needing(2, "pcs")
      PantryItem.create!(user: @user, ingredient: @cheese, quantity: 6)

      assert_equal [ 1, 0 ], scores_for(recipe)
    end

    test "a quantity shortfall ranks a recipe below one that is fully covered" do
      PantryItem.create!(user: @user, ingredient: @pasta, quantity: 300, unit: "g")
      PantryItem.create!(user: @user, ingredient: @eggs, quantity: 6, unit: "pcs")

      short = Recipe.create!(title: "Needs 500 g pasta")
      RecipeIngredient.create!(recipe: short, ingredient: @pasta, original_text: "500 g pasta", quantity: 500, unit: "g")
      RecipeIngredient.create!(recipe: short, ingredient: @eggs, original_text: "2 eggs", quantity: 2, unit: "pcs")

      covered = Recipe.create!(title: "Needs 200 g pasta")
      RecipeIngredient.create!(recipe: covered, ingredient: @pasta, original_text: "200 g pasta", quantity: 200, unit: "g")
      RecipeIngredient.create!(recipe: covered, ingredient: @eggs, original_text: "2 eggs", quantity: 2, unit: "pcs")

      ids = Finder.call(@user).map(&:id)

      assert_operator ids.index(covered.id), :<, ids.index(short.id)
    end

    test "applies rating, prep time and cook time filters" do
      matching = Recipe.create!(title: "Quick and good", ratings: 4.5, prep_time: 10, cook_time: 15)
      RecipeIngredient.create!(recipe: matching, ingredient: @pasta, original_text: "pasta")
      [
        { ratings: 3.0, prep_time: 10, cook_time: 15 },
        { ratings: 4.5, prep_time: 60, cook_time: 15 },
        { ratings: 4.5, prep_time: 10, cook_time: 90 }
      ].each do |attributes|
        recipe = Recipe.create!(title: "Filtered out", **attributes)
        RecipeIngredient.create!(recipe: recipe, ingredient: @pasta, original_text: "pasta")
      end

      recipes = Finder.call(@user, filters: { min_rating: 4.0, max_prep_time: 20, max_cook_time: 30 })

      assert_equal [ matching.id ], recipes.map(&:id)
    end

    test "missing count is consistent with the recipe detail" do
      PantryItem.create!(user: @user, ingredient: @pasta, quantity: 100, unit: "g")
      PantryItem.create!(user: @user, ingredient: @eggs)
      PantryItem.create!(user: @user, ingredient: @cheese, quantity: 1, unit: "l")

      recipe = Recipe.create!(title: "Mixed")
      RecipeIngredient.create!(recipe: recipe, ingredient: @pasta, original_text: "200 g pasta", quantity: 200, unit: "g")
      RecipeIngredient.create!(recipe: recipe, ingredient: @eggs, original_text: "2 eggs", quantity: 2, unit: "pcs")
      RecipeIngredient.create!(recipe: recipe, ingredient: @cheese, original_text: "100 g cheese", quantity: 100, unit: "g")
      RecipeIngredient.create!(recipe: recipe, ingredient: @tomato, original_text: "1 tomato", quantity: 1, unit: "pcs")

      Finder.call(@user).each do |found|
        assert_equal found.missing_ingredients_count, found.missing_ingredients_for(@user).size,
                     "Finder and recipe detail disagree for #{found.title}"
      end
    end

    test "runs a fixed number of queries" do
      PantryItem.create!(user: @user, ingredient: @pasta, quantity: 500, unit: "g")
      PantryItem.create!(user: @user, ingredient: @eggs, quantity: 6, unit: "pcs")

      assert_queries_count(4) { Finder.call(@user) }
    end
  end
end
