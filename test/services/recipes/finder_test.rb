require "test_helper"

module Recipes
  class FinderTest < ActiveSupport::TestCase
    setup do
      @user = User.create!(email: "demo@example.com")

      # Create ingredients
      @pasta = Ingredient.create!(name: "Pasta", canonical_name: "pasta")
      @eggs = Ingredient.create!(name: "Eggs", canonical_name: "eggs")
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
      PantryItem.create!(user: @user, ingredient: @pasta, quantity: 500.0)
      PantryItem.create!(user: @user, ingredient: @eggs, quantity: 5.0)

      recipes = Recipes::Finder.call(@user)

      # Recipe1: 2/2 matched (pasta, eggs) - best match
      # Recipe2: 1/2 matched (pasta) - second
      # Recipe3: 1/4 matched (pasta) - third
      assert_equal @recipe1.id, recipes.first.id
      assert_equal @recipe2.id, recipes.second.id
      assert_equal @recipe3.id, recipes.third.id
    end

    test "sorts by missing_count ASC when matched_count is equal" do
      # User has pasta, eggs, and cheese in pantry
      PantryItem.create!(user: @user, ingredient: @pasta, quantity: 500.0)
      PantryItem.create!(user: @user, ingredient: @eggs, quantity: 5.0)
      PantryItem.create!(user: @user, ingredient: @cheese, quantity: 200.0)

      recipes = Recipes::Finder.call(@user)

      # Recipe1: 2/2 matched, 0 missing
      # Recipe2: 2/2 matched, 0 missing
      # Recipe3: 1/4 matched, 3 missing
      # Recipe1 and Recipe2 both have 2 matched, 0 missing - order should be consistent
      # Recipe3 should be last
      assert_includes [ @recipe1.id, @recipe2.id ], recipes.first.id
      assert_includes [ @recipe1.id, @recipe2.id ], recipes.second.id
      assert_equal @recipe3.id, recipes.third.id
    end

    test "returns empty array when user has no pantry items" do
      recipes = Recipes::Finder.call(@user)

      # All recipes have 0 matched ingredients
      assert_equal 3, recipes.count
      # All should have 0 matched, but different missing counts
      # Recipe1: 0/2 matched, 2 missing
      # Recipe2: 0/2 matched, 2 missing
      # Recipe3: 0/4 matched, 4 missing
      # Recipe1 and Recipe2 should come before Recipe3 (same matched, but Recipe3 has more missing)
      assert_includes [ @recipe1.id, @recipe2.id ], recipes.first.id
      assert_includes [ @recipe1.id, @recipe2.id ], recipes.second.id
      assert_equal @recipe3.id, recipes.third.id
    end

    test "returns all recipes even when none match" do
      # User has only garlic (not used in any recipe)
      PantryItem.create!(user: @user, ingredient: @garlic, quantity: 5.0)

      recipes = Recipes::Finder.call(@user)

      assert_equal 3, recipes.count
      # All recipes have 0 matched
      # Recipe1: 0/2 matched, 2 missing
      # Recipe2: 0/2 matched, 2 missing
      # Recipe3: 1/4 matched, 3 missing (garlic is in recipe3)
      assert_equal @recipe3.id, recipes.first.id
      assert_includes [ @recipe1.id, @recipe2.id ], recipes.second.id
      assert_includes [ @recipe1.id, @recipe2.id ], recipes.third.id
    end

    test "handles recipes with no ingredients" do
      # User has pasta and eggs in pantry
      PantryItem.create!(user: @user, ingredient: @pasta, quantity: 500.0)
      PantryItem.create!(user: @user, ingredient: @eggs, quantity: 5.0)

      empty_recipe = Recipe.create!(title: "Empty Recipe")

      recipes = Recipes::Finder.call(@user)

      # Empty recipe should always be last (0 matched, 0 missing)
      assert_equal 4, recipes.count
      assert_equal empty_recipe.id, recipes.last.id
      # Other recipes should come before empty recipe
      assert_not_equal empty_recipe.id, recipes.first.id
    end
  end
end
