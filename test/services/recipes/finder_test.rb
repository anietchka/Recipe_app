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

    test "returns fully makeable recipes first, then by share of matched ingredients" do
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

    # Ranking: fewer missing ingredients, then higher share of matched ingredients, then id

    # Creates a recipe with `total` ingredients, the first `matched` of them in the user's pantry
    def recipe_with(matched:, total:)
      recipe = Recipe.create!(title: "#{matched}/#{total}")
      total.times do |i|
        ingredient = Ingredient.create!(name: "Ingredient #{recipe.id}-#{i}", canonical_name: "ingredient-#{recipe.id}-#{i}")
        RecipeIngredient.create!(recipe: recipe, ingredient: ingredient, original_text: ingredient.name)
        PantryItem.create!(user: @user, ingredient: ingredient) if i < matched
      end
      recipe
    end

    def ranked_ids
      Finder.call(@user).map(&:id)
    end

    test "ranks fewer missing ingredients before a higher share of matched ingredients" do
      # Regression: percentage-first ranking would put 3/5 (60%) before 1/2 (50%)
      three_of_five = recipe_with(matched: 3, total: 5)
      one_of_two = recipe_with(matched: 1, total: 2)

      assert_operator ranked_ids.index(one_of_two.id), :<, ranked_ids.index(three_of_five.id)
    end

    test "ranks fully makeable recipes first" do
      nine_of_ten = recipe_with(matched: 9, total: 10)
      four_of_four = recipe_with(matched: 4, total: 4)

      assert_operator ranked_ids.index(four_of_four.id), :<, ranked_ids.index(nine_of_ten.id)
    end

    test "ranks fewer missing ingredients first when the share is equal" do
      six_of_eight = recipe_with(matched: 6, total: 8)
      three_of_four = recipe_with(matched: 3, total: 4)

      assert_operator ranked_ids.index(three_of_four.id), :<, ranked_ids.index(six_of_eight.id)
    end

    test "ranks a higher share of matched ingredients first when the missing count is equal" do
      three_of_five = recipe_with(matched: 3, total: 5)
      eight_of_ten = recipe_with(matched: 8, total: 10)

      assert_operator ranked_ids.index(eight_of_ten.id), :<, ranked_ids.index(three_of_five.id)
    end

    test "ranks by recipe id when missing count and share are equal" do
      first = recipe_with(matched: 1, total: 2)
      second = recipe_with(matched: 1, total: 2)

      assert_operator ranked_ids.index(first.id), :<, ranked_ids.index(second.id)
    end

    test "orders recipes by fewer missing ingredients, then higher share" do
      three_of_five = recipe_with(matched: 3, total: 5)
      eight_of_ten = recipe_with(matched: 8, total: 10)
      one_of_two = recipe_with(matched: 1, total: 2)
      three_of_four = recipe_with(matched: 3, total: 4)
      four_of_four = recipe_with(matched: 4, total: 4)

      expected = [ four_of_four, three_of_four, one_of_two, eight_of_ten, three_of_five ].map(&:id)

      assert_equal expected, ranked_ids.first(5)
    end

    # Maximum missing ingredients filter

    def ids_with(**filters)
      Finder.call(@user, limit: 100, filters: filters).map(&:id)
    end

    test "max_missing 0 keeps only fully makeable recipes" do
      complete = recipe_with(matched: 4, total: 4)
      one_missing = recipe_with(matched: 3, total: 4)

      recipes = Finder.call(@user, filters: { max_missing: 0 })

      assert_includes recipes.map(&:id), complete.id
      assert_not_includes recipes.map(&:id), one_missing.id
      assert recipes.all? { |recipe| recipe.missing_ingredients_count.zero? }
    end

    test "max_missing 2 keeps recipes with up to two missing ingredients" do
      one_missing = recipe_with(matched: 3, total: 4)
      two_missing = recipe_with(matched: 2, total: 4)
      three_missing = recipe_with(matched: 1, total: 4)

      ids = ids_with(max_missing: 2)

      assert_includes ids, one_missing.id
      assert_includes ids, two_missing.id
      assert_not_includes ids, three_missing.id
    end

    test "without max_missing every recipe is returned" do
      complete = recipe_with(matched: 4, total: 4)
      three_missing = recipe_with(matched: 1, total: 4)

      ids = ids_with

      assert_includes ids, complete.id
      assert_includes ids, three_missing.id
      assert_equal Recipe.joins(:recipe_ingredients).distinct.count, ids.size
    end

    test "max_missing keeps the ranking of the remaining recipes" do
      recipe_with(matched: 6, total: 12)
      recipe_with(matched: 6, total: 8)
      recipe_with(matched: 3, total: 4)
      recipe_with(matched: 9, total: 10)
      recipe_with(matched: 4, total: 4)

      filtered = ids_with(max_missing: 2)
      unfiltered = ids_with

      assert_equal unfiltered & filtered, filtered
    end

    test "pagination applies after the max_missing filter" do
      5.times { recipe_with(matched: 1, total: 1) }
      2.times { recipe_with(matched: 1, total: 4) }

      pages = [ 0, 2, 4 ].map { |offset| Finder.call(@user, limit: 2, offset: offset, filters: { max_missing: 0 }) }

      assert_equal [ 2, 2, 1 ], pages.map(&:size)
      assert_equal ids_with(max_missing: 0), pages.flatten.map(&:id)
    end

    test "max_missing combines with existing filters" do
      wanted = recipe_with(matched: 2, total: 2).tap { |recipe| recipe.update!(ratings: 4.5) }
      recipe_with(matched: 2, total: 2).update!(ratings: 3.0)
      recipe_with(matched: 1, total: 4).update!(ratings: 4.5)

      assert_equal [ wanted.id ], ids_with(max_missing: 0, min_rating: 4.0)
    end
  end
end
