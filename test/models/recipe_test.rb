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

  test "cook! decrements pantry items with sufficient quantity" do
    user = User.create!(email: "demo@example.com")
    pasta = Ingredient.create!(name: "Pasta", canonical_name: "pasta")
    eggs = Ingredient.create!(name: "Eggs", canonical_name: "eggs")

    recipe = Recipe.create!(title: "Simple Pasta")
    RecipeIngredient.create!(
      recipe: recipe,
      ingredient: pasta,
      quantity: 200.0,
      unit: "g",
      original_text: "200g pasta"
    )
    RecipeIngredient.create!(
      recipe: recipe,
      ingredient: eggs,
      quantity: 2.0,
      original_text: "2 eggs"
    )

    PantryItem.create!(
      user: user,
      ingredient: pasta,
      quantity: 500.0,
      unit: "g"
    )
    PantryItem.create!(
      user: user,
      ingredient: eggs,
      quantity: 5.0
    )

    recipe.cook!(user)

    pasta_item = PantryItem.find_by(user: user, ingredient: pasta)
    assert_equal 300.0, pasta_item.quantity

    eggs_item = PantryItem.find_by(user: user, ingredient: eggs)
    assert_equal 3.0, eggs_item.quantity
  end

  test "cook! does not decrement below zero with insufficient quantity" do
    user = User.create!(email: "demo@example.com")
    pasta = Ingredient.create!(name: "Pasta", canonical_name: "pasta")

    recipe = Recipe.create!(title: "Simple Pasta")
    RecipeIngredient.create!(
      recipe: recipe,
      ingredient: pasta,
      quantity: 500.0,
      unit: "g",
      original_text: "500g pasta"
    )

    PantryItem.create!(
      user: user,
      ingredient: pasta,
      quantity: 200.0,
      unit: "g"
    )

    recipe.cook!(user)

    pasta_item = PantryItem.find_by(user: user, ingredient: pasta)
    assert_equal 0.0, pasta_item.quantity
  end

  test "cook! ignores ingredients not in pantry" do
    user = User.create!(email: "demo@example.com")
    pasta = Ingredient.create!(name: "Pasta", canonical_name: "pasta")
    cheese = Ingredient.create!(name: "Cheese", canonical_name: "cheese")

    recipe = Recipe.create!(title: "Pasta with Cheese")
    RecipeIngredient.create!(
      recipe: recipe,
      ingredient: pasta,
      quantity: 200.0,
      unit: "g",
      original_text: "200g pasta"
    )
    RecipeIngredient.create!(
      recipe: recipe,
      ingredient: cheese,
      quantity: 100.0,
      unit: "g",
      original_text: "100g cheese"
    )

    PantryItem.create!(
      user: user,
      ingredient: pasta,
      quantity: 500.0,
      unit: "g"
    )
    # No cheese in pantry

    recipe.cook!(user)

    pasta_item = PantryItem.find_by(user: user, ingredient: pasta)
    assert_equal 300.0, pasta_item.quantity

    cheese_item = PantryItem.find_by(user: user, ingredient: cheese)
    assert_nil cheese_item
  end

  test "cook! uses symbolic unit when recipe_ingredient quantity is nil" do
    user = User.create!(email: "demo@example.com")
    salt = Ingredient.create!(name: "Salt", canonical_name: "salt")

    recipe = Recipe.create!(title: "Simple Recipe")
    RecipeIngredient.create!(
      recipe: recipe,
      ingredient: salt,
      quantity: nil,
      original_text: "salt to taste"
    )

    PantryItem.create!(
      user: user,
      ingredient: salt,
      quantity: 10.0
    )

    recipe.cook!(user)

    salt_item = PantryItem.find_by(user: user, ingredient: salt)
    assert_equal 9.0, salt_item.quantity
  end

  test "cook! decrements fraction from quantity" do
    user = User.create!(email: "demo@example.com")
    flour = Ingredient.create!(name: "Flour", canonical_name: "flour")

    recipe = Recipe.create!(title: "Cake Recipe")
    RecipeIngredient.create!(
      recipe: recipe,
      ingredient: flour,
      quantity: 1.0,
      fraction: "1/2",
      original_text: "1 ½ cups flour"
    )

    PantryItem.create!(
      user: user,
      ingredient: flour,
      quantity: 5.0
    )

    recipe.cook!(user)

    flour_item = PantryItem.find_by(user: user, ingredient: flour)
    assert_equal 3, flour_item.quantity
    assert_equal "1/2", flour_item.fraction
  end

  test "cook! decrements fraction from fraction" do
    user = User.create!(email: "demo@example.com")
    water = Ingredient.create!(name: "Water", canonical_name: "water")

    recipe = Recipe.create!(title: "Simple Recipe")
    RecipeIngredient.create!(
      recipe: recipe,
      ingredient: water,
      quantity: nil,
      fraction: "1/2",
      original_text: "½ cup water"
    )

    PantryItem.create!(
      user: user,
      ingredient: water,
      quantity: nil,
      fraction: "3/4"
    )

    recipe.cook!(user)

    water_item = PantryItem.find_by(user: user, ingredient: water)
    # 3/4 - 1/2 = 0.75 - 0.5 = 0.25 = 1/4
    assert_equal 0.0, water_item.quantity
    assert_equal "1/4", water_item.fraction
  end

  test "cook! decrements quantity with fraction from quantity with fraction" do
    user = User.create!(email: "demo@example.com")
    sugar = Ingredient.create!(name: "Sugar", canonical_name: "sugar")

    recipe = Recipe.create!(title: "Cake Recipe")
    RecipeIngredient.create!(
      recipe: recipe,
      ingredient: sugar,
      quantity: 2.0,
      fraction: "1/4",
      original_text: "2 ¼ cups sugar"
    )

    PantryItem.create!(
      user: user,
      ingredient: sugar,
      quantity: 5.0,
      fraction: "1/2"
    )

    recipe.cook!(user)

    sugar_item = PantryItem.find_by(user: user, ingredient: sugar)
    # 5.5 - 2.25 = 3.25
    assert_equal 3.0, sugar_item.quantity
    assert_equal "1/4", sugar_item.fraction
  end

  test "cook! handles fraction when pantry item has only fraction" do
    user = User.create!(email: "demo@example.com")
    oil = Ingredient.create!(name: "Oil", canonical_name: "oil")

    recipe = Recipe.create!(title: "Simple Recipe")
    RecipeIngredient.create!(
      recipe: recipe,
      ingredient: oil,
      quantity: 1.0,
      fraction: "1/3",
      original_text: "1 ⅓ tablespoons oil"
    )

    PantryItem.create!(
      user: user,
      ingredient: oil,
      quantity: nil,
      fraction: "2/3"
    )

    recipe.cook!(user)

    oil_item = PantryItem.find_by(user: user, ingredient: oil)
    # 2/3 - 1 1/3 = 0.666... - 1.333... = -0.666... -> 0 (ne peut pas être négatif)
    assert_equal 0.0, oil_item.quantity
  end

  test "missing_ingredients_for returns ingredients not in user pantry with full quantity" do
    user = User.create!(email: "demo@example.com")
    pasta = Ingredient.create!(name: "Pasta", canonical_name: "pasta")
    eggs = Ingredient.create!(name: "Eggs", canonical_name: "eggs")
    cheese = Ingredient.create!(name: "Cheese", canonical_name: "cheese")

    recipe = Recipe.create!(title: "Pasta Carbonara")
    RecipeIngredient.create!(recipe: recipe, ingredient: pasta, original_text: "200g pasta", quantity: 200.0)
    RecipeIngredient.create!(recipe: recipe, ingredient: eggs, original_text: "2 eggs", quantity: 2.0)
    RecipeIngredient.create!(recipe: recipe, ingredient: cheese, original_text: "100g cheese", quantity: 100.0)

    # User has pasta and eggs in pantry, but not cheese
    PantryItem.create!(user: user, ingredient: pasta, quantity: 500.0)
    PantryItem.create!(user: user, ingredient: eggs, quantity: 5.0)

    missing = recipe.missing_ingredients_for(user)

    assert_equal 1, missing.count
    cheese_missing = missing.find { |m| m[:ingredient_id] == cheese.id }
    assert_not_nil cheese_missing
    assert_equal 100.0, cheese_missing[:missing_quantity]
    assert_nil cheese_missing[:missing_fraction]
  end

  test "missing_ingredients_for calculates missing quantity when insufficient in pantry" do
    user = User.create!(email: "demo@example.com")
    pasta = Ingredient.create!(name: "Pasta", canonical_name: "pasta")

    recipe = Recipe.create!(title: "Pasta Dish")
    RecipeIngredient.create!(recipe: recipe, ingredient: pasta, original_text: "500g pasta", quantity: 500.0)

    # User has only 200g of pasta, needs 500g
    PantryItem.create!(user: user, ingredient: pasta, quantity: 200.0)

    missing = recipe.missing_ingredients_for(user)

    assert_equal 1, missing.count
    pasta_missing = missing.find { |m| m[:ingredient_id] == pasta.id }
    assert_not_nil pasta_missing
    assert_equal 300.0, pasta_missing[:missing_quantity]
    assert_nil pasta_missing[:missing_fraction]
  end

  test "missing_ingredients_for handles fractions correctly" do
    user = User.create!(email: "demo@example.com")
    flour = Ingredient.create!(name: "Flour", canonical_name: "flour")

    recipe = Recipe.create!(title: "Cake")
    RecipeIngredient.create!(
      recipe: recipe,
      ingredient: flour,
      original_text: "1 ½ cups flour",
      quantity: 1.0,
      fraction: "1/2"
    )

    # User has only 1/2 cup of flour, needs 1 1/2 cups
    PantryItem.create!(user: user, ingredient: flour, quantity: 0.0, fraction: "1/2")

    missing = recipe.missing_ingredients_for(user)

    assert_equal 1, missing.count
    flour_missing = missing.find { |m| m[:ingredient_id] == flour.id }
    assert_not_nil flour_missing
    assert_equal 1.0, flour_missing[:missing_quantity]
    assert_nil flour_missing[:missing_fraction]
  end

  test "missing_ingredients_for handles complex fraction calculations" do
    user = User.create!(email: "demo@example.com")
    sugar = Ingredient.create!(name: "Sugar", canonical_name: "sugar")

    recipe = Recipe.create!(title: "Dessert")
    RecipeIngredient.create!(
      recipe: recipe,
      ingredient: sugar,
      original_text: "2 ¾ cups sugar",
      quantity: 2.0,
      fraction: "3/4"
    )

    # User has 1 1/4 cups, needs 2 3/4 cups
    PantryItem.create!(user: user, ingredient: sugar, quantity: 1.0, fraction: "1/4")

    missing = recipe.missing_ingredients_for(user)

    assert_equal 1, missing.count
    sugar_missing = missing.find { |m| m[:ingredient_id] == sugar.id }
    assert_not_nil sugar_missing
    # 2 3/4 - 1 1/4 = 1 1/2
    assert_equal 1.0, sugar_missing[:missing_quantity]
    assert_equal "1/2", sugar_missing[:missing_fraction]
  end

  test "missing_ingredients_for returns all ingredients when user has no pantry items" do
    user = User.create!(email: "demo@example.com")
    pasta = Ingredient.create!(name: "Pasta", canonical_name: "pasta")
    eggs = Ingredient.create!(name: "Eggs", canonical_name: "eggs")

    recipe = Recipe.create!(title: "Pasta with Eggs")
    RecipeIngredient.create!(recipe: recipe, ingredient: pasta, original_text: "200g pasta", quantity: 200.0)
    RecipeIngredient.create!(recipe: recipe, ingredient: eggs, original_text: "2 eggs", quantity: 2.0)

    missing = recipe.missing_ingredients_for(user)

    assert_equal 2, missing.count
    pasta_missing = missing.find { |m| m[:ingredient_id] == pasta.id }
    eggs_missing = missing.find { |m| m[:ingredient_id] == eggs.id }
    assert_not_nil pasta_missing
    assert_not_nil eggs_missing
    assert_equal 200.0, pasta_missing[:missing_quantity]
    assert_equal 2.0, eggs_missing[:missing_quantity]
  end

  test "missing_ingredients_for handles unit conversion for weight units" do
    user = User.create!(email: "demo@example.com")
    pasta = Ingredient.create!(name: "Pasta", canonical_name: "pasta")

    recipe = Recipe.create!(title: "Pasta Dish")
    RecipeIngredient.create!(recipe: recipe, ingredient: pasta, original_text: "1 kg pasta", quantity: 1.0, unit: "kg")

    # User has 500g of pasta, needs 1kg (1000g)
    PantryItem.create!(user: user, ingredient: pasta, quantity: 500.0, unit: "g")

    missing = recipe.missing_ingredients_for(user)

    assert_equal 1, missing.count
    pasta_missing = missing.find { |m| m[:ingredient_id] == pasta.id }
    assert_not_nil pasta_missing
    # 1kg = 1000g, user has 500g, missing 500g = 0.5kg = 1/2 kg
    assert_equal 0, pasta_missing[:missing_quantity]
    assert_equal "1/2", pasta_missing[:missing_fraction]
    assert_equal "kg", pasta_missing[:recipe_ingredient].unit
  end

  test "missing_ingredients_for handles unit conversion for volume units" do
    user = User.create!(email: "demo@example.com")
    milk = Ingredient.create!(name: "Milk", canonical_name: "milk")

    recipe = Recipe.create!(title: "Cake")
    RecipeIngredient.create!(recipe: recipe, ingredient: milk, original_text: "500ml milk", quantity: 500.0, unit: "ml")

    # User has 0.5l of milk, needs 500ml
    PantryItem.create!(user: user, ingredient: milk, quantity: 0.5, unit: "l")

    missing = recipe.missing_ingredients_for(user)

    assert_equal 0, missing.count # 0.5l = 500ml, sufficient
  end

  test "cook! handles unit conversion when decrementing" do
    user = User.create!(email: "demo@example.com")
    pasta = Ingredient.create!(name: "Pasta", canonical_name: "pasta")

    recipe = Recipe.create!(title: "Pasta Dish")
    RecipeIngredient.create!(recipe: recipe, ingredient: pasta, original_text: "500g pasta", quantity: 500.0, unit: "g")

    # User has 1kg of pasta
    pantry_item = PantryItem.create!(user: user, ingredient: pasta, quantity: 1.0, unit: "kg")

    recipe.cook!(user)

    pantry_item.reload
    # 1kg = 1000g, used 500g, remaining 500g = 0.5kg = 1/2 kg
    assert_equal 0.0, pantry_item.quantity
    assert_equal "1/2", pantry_item.fraction
    assert_equal "kg", pantry_item.unit
  end

  test "missing_ingredients_for returns empty array when user has sufficient quantities" do
    user = User.create!(email: "demo@example.com")
    pasta = Ingredient.create!(name: "Pasta", canonical_name: "pasta")
    eggs = Ingredient.create!(name: "Eggs", canonical_name: "eggs")

    recipe = Recipe.create!(title: "Pasta with Eggs")
    RecipeIngredient.create!(recipe: recipe, ingredient: pasta, original_text: "200g pasta", quantity: 200.0)
    RecipeIngredient.create!(recipe: recipe, ingredient: eggs, original_text: "2 eggs", quantity: 2.0)

    PantryItem.create!(user: user, ingredient: pasta, quantity: 500.0)
    PantryItem.create!(user: user, ingredient: eggs, quantity: 5.0)

    missing = recipe.missing_ingredients_for(user)

    assert_equal 0, missing.count
  end

  test "missing_ingredients_for returns empty when user has more than needed" do
    user = User.create!(email: "demo@example.com")
    pasta = Ingredient.create!(name: "Pasta", canonical_name: "pasta")

    recipe = Recipe.create!(title: "Pasta Dish")
    RecipeIngredient.create!(recipe: recipe, ingredient: pasta, original_text: "200g pasta", quantity: 200.0)

    PantryItem.create!(user: user, ingredient: pasta, quantity: 500.0)

    missing = recipe.missing_ingredients_for(user)

    assert_equal 0, missing.count
  end
end
