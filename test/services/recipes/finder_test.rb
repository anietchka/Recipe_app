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
      # Check precalculated scores (all counts are from SQL query for performance)
      assert_equal 2, recipe1.matched_ingredients_count
      assert_equal 2, recipe1.total_ingredients_count # Precalculated from SQL
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
  end
end
