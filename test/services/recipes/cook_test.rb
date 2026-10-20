require "test_helper"

module Recipes
  class CookTest < ActiveSupport::TestCase
    setup do
      @user = User.create!(email: "demo@example.com")
      @recipe = Recipe.create!(title: "Test Recipe")
      @flour = Ingredient.create!(name: "Flour", canonical_name: "flour")
      @sugar = Ingredient.create!(name: "Sugar", canonical_name: "sugar")
    end

    def add_to_recipe(ingredient, quantity, unit)
      RecipeIngredient.create!(recipe: @recipe, ingredient: ingredient, original_text: ingredient.name, quantity: quantity, unit: unit)
    end

    def add_to_pantry(ingredient, quantity, unit)
      PantryItem.create!(user: @user, ingredient: ingredient, quantity: quantity, unit: unit)
    end

    # Cooks a recipe with a single ingredient and returns the pantry item afterwards (nil if removed)
    def cook_single(pantry:, recipe:)
      add_to_recipe(@flour, *recipe)
      pantry_item = add_to_pantry(@flour, *pantry)

      result = Cook.call(@recipe, @user)

      assert result.success?
      PantryItem.find_by(id: pantry_item.id)
    end

    test "skips an ingredient absent from the pantry and still records the cook" do
      add_to_recipe(@flour, 200, "g")

      result = Cook.call(@recipe, @user)

      assert result.success?
      assert_not PantryItem.exists?(user: @user, ingredient: @flour)
      assert CookedRecipe.exists?(user: @user, recipe: @recipe)
    end

    test "does not decrement an untracked pantry quantity" do
      item = cook_single(pantry: [ nil, nil ], recipe: [ 200, "g" ])

      assert_nil item.quantity
    end

    test "does not decrement when the recipe gives no quantity" do
      item = cook_single(pantry: [ 10, "g" ], recipe: [ nil, nil ])

      assert_equal 10, item.quantity
    end

    test "subtracts the recipe quantity from sufficient stock" do
      item = cook_single(pantry: [ 500, "g" ], recipe: [ 200, "g" ])

      assert_equal 300, item.quantity
    end

    test "removes the pantry item when the stock is exactly exhausted" do
      item = cook_single(pantry: [ 200, "g" ], recipe: [ 200, "g" ])

      assert_nil item
    end

    test "consumes insufficient stock and removes the pantry item" do
      item = cook_single(pantry: [ 200, "g" ], recipe: [ 500, "g" ])

      assert_nil item
    end

    test "converts compatible weight units into the pantry unit" do
      item = cook_single(pantry: [ 1, "kg" ], recipe: [ 500, "g" ])

      assert_equal 0.5, item.quantity
      assert_equal "kg", item.unit
    end

    test "converts compatible volume units into the pantry unit" do
      item = cook_single(pantry: [ 1, "l" ], recipe: [ 500, "ml" ])

      assert_equal 0.5, item.quantity
      assert_equal "l", item.unit
    end

    test "counts a pantry quantity without unit against a recipe in pcs" do
      item = cook_single(pantry: [ 6, nil ], recipe: [ 2, "pcs" ])

      assert_equal 4, item.quantity
    end

    test "subtracts numerically when both units are blank" do
      item = cook_single(pantry: [ 5, nil ], recipe: [ 2, nil ])

      assert_equal 3, item.quantity
    end

    test "does not decrement a pantry quantity without unit for a measured recipe unit" do
      item = cook_single(pantry: [ 1000, nil ], recipe: [ 200, "g" ])

      assert_equal 1000, item.quantity
    end

    test "does not decrement pantry pcs for a recipe quantity without unit" do
      item = cook_single(pantry: [ 6, "pcs" ], recipe: [ 2, nil ])

      assert_equal 6, item.quantity
    end

    test "does not decrement incompatible measured units" do
      item = cook_single(pantry: [ 1, "cup" ], recipe: [ 200, "g" ])

      assert_equal 1, item.quantity
      assert_equal "cup", item.unit
    end

    test "creates a CookedRecipe on first cook" do
      Cook.call(@recipe, @user)

      cooked_recipe = CookedRecipe.find_by(user: @user, recipe: @recipe)
      assert_not_nil cooked_recipe.cooked_at
    end

    test "updates the existing CookedRecipe when cooking again" do
      cooked_recipe = CookedRecipe.create!(user: @user, recipe: @recipe, cooked_at: 2.days.ago)

      Cook.call(@recipe, @user)

      assert_equal 1, CookedRecipe.where(user: @user, recipe: @recipe).count
      assert_in_delta Time.current, cooked_recipe.reload.cooked_at, 5.seconds
    end

    test "rolls back every pantry change when a pantry write fails" do
      add_to_recipe(@flour, 200, "g")
      add_to_recipe(@sugar, 100, "g")
      flour = add_to_pantry(@flour, 500, "g")
      sugar = add_to_pantry(@sugar, 300, "g")
      # Simulate a stored row that no longer passes validation: its update! raises RecordInvalid
      sugar.update_columns(unit: "invalid")
      @recipe.recipe_ingredients.find_by(ingredient: @sugar).update_columns(unit: "invalid")

      result = Cook.call(@recipe, @user)

      assert_not result.success?
      assert result.errors[:base].present?
      assert_equal 500, flour.reload.quantity
      assert_equal 300, sugar.reload.quantity
      assert_not CookedRecipe.exists?(user: @user, recipe: @recipe)
    end

    test "rolls back every pantry change when the CookedRecipe can't be saved" do
      add_to_recipe(@flour, 200, "g")
      add_to_recipe(@sugar, 300, "g")
      flour = add_to_pantry(@flour, 500, "g")
      sugar = add_to_pantry(@sugar, 300, "g")
      # A recipe marked for destruction fails CookedRecipe's `validates :recipe, presence: true`
      @recipe.mark_for_destruction

      result = Cook.call(@recipe, @user)

      assert_not result.success?
      assert result.errors[:base].present?
      assert_equal 500, flour.reload.quantity
      assert PantryItem.exists?(sugar.id), "Exhausted pantry item should be restored"
      assert_not CookedRecipe.exists?(user: @user, recipe: @recipe)
    end
  end
end
