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
      cook_time: 20,
      prep_time: 10,
      image_url: "https://example.com/pasta.jpg",
      category: "Italian",
      ratings: 4.5
    )
    assert recipe.valid?
  end

  test "cook! decrements pantry items with sufficient quantity" do
    user = User.create!(email: "demo@example.com")
    pasta = Ingredient.create!(name: "Pasta", canonical_name: "pasta")
    eggs = Ingredient.create!(name: "Eggs", canonical_name: "egg")

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

  test "cook! removes pantry item when quantity reaches zero" do
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

    # Pantry item should be deleted when quantity reaches zero
    pasta_item = PantryItem.find_by(user: user, ingredient: pasta)
    assert_nil pasta_item
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

  test "cook! does not modify pantry items without quantity" do
    user = User.create!(email: "demo@example.com")
    salt = Ingredient.create!(name: "Salt", canonical_name: "salt")
    oil = Ingredient.create!(name: "Oil", canonical_name: "oil")

    recipe = Recipe.create!(title: "Simple Recipe")
    RecipeIngredient.create!(
      recipe: recipe,
      ingredient: salt,
      quantity: 1.0,
      unit: "tsp",
      original_text: "1 tsp salt"
    )
    RecipeIngredient.create!(
      recipe: recipe,
      ingredient: oil,
      quantity: 2.0,
      unit: "tbsp",
      original_text: "2 tbsp oil"
    )

    # Create pantry items without quantity (base ingredients)
    salt_item = PantryItem.create!(
      user: user,
      ingredient: salt
    )
    oil_item = PantryItem.create!(
      user: user,
      ingredient: oil
    )

    recipe.cook!(user)

    # Verify that pantry items without quantity are not modified
    salt_item.reload
    assert_nil salt_item.quantity
    assert_nil salt_item.unit

    oil_item.reload
    assert_nil oil_item.quantity
    assert_nil oil_item.unit
  end

  test "cook! does not decrement pantry item when recipe_ingredient quantity is nil" do
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
    assert_equal 10.0, salt_item.quantity
  end

  test "cook! decrements a decimal quantity" do
    user = User.create!(email: "demo@example.com")
    sugar = Ingredient.create!(name: "Sugar", canonical_name: "sugar")

    recipe = Recipe.create!(title: "Cake Recipe")
    RecipeIngredient.create!(
      recipe: recipe,
      ingredient: sugar,
      quantity: 2.25,
      original_text: "2 ¼ cups sugar"
    )

    PantryItem.create!(
      user: user,
      ingredient: sugar,
      quantity: 5.5
    )

    recipe.cook!(user)

    sugar_item = PantryItem.find_by(user: user, ingredient: sugar)
    # 5.5 - 2.25 = 3.25
    assert_equal 3.25, sugar_item.quantity
  end

  test "cook! removes pantry item when quantity reaches zero or below" do
    user = User.create!(email: "demo@example.com")
    oil = Ingredient.create!(name: "Oil", canonical_name: "oil")

    recipe = Recipe.create!(title: "Simple Recipe")
    RecipeIngredient.create!(
      recipe: recipe,
      ingredient: oil,
      quantity: 1.5,
      original_text: "1 ½ tablespoons oil"
    )

    PantryItem.create!(
      user: user,
      ingredient: oil,
      quantity: 0.5
    )

    recipe.cook!(user)

    # 0.5 - 1.5 < 0: the stock is exhausted, so the pantry item is deleted
    assert_nil PantryItem.find_by(user: user, ingredient: oil)
  end

  test "missing_ingredients_for returns ingredients not in user pantry with full quantity" do
    user = User.create!(email: "demo@example.com")
    pasta = Ingredient.create!(name: "Pasta", canonical_name: "pasta")
    eggs = Ingredient.create!(name: "Eggs", canonical_name: "egg")
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
  end

  test "missing_ingredients_for handles decimal quantities" do
    user = User.create!(email: "demo@example.com")
    sugar = Ingredient.create!(name: "Sugar", canonical_name: "sugar")

    recipe = Recipe.create!(title: "Dessert")
    RecipeIngredient.create!(
      recipe: recipe,
      ingredient: sugar,
      original_text: "2 ¾ cups sugar",
      quantity: 2.75
    )

    # User has 1.25 cups, needs 2.75 cups
    PantryItem.create!(user: user, ingredient: sugar, quantity: 1.25)

    missing = recipe.missing_ingredients_for(user)

    assert_equal 1, missing.count
    sugar_missing = missing.find { |m| m[:ingredient_id] == sugar.id }
    assert_not_nil sugar_missing
    assert_equal 1.5, sugar_missing[:missing_quantity]
  end

  test "missing_ingredients_for keeps missing quantity nil when recipe gives no quantity" do
    user = User.create!(email: "demo@example.com")
    salt = Ingredient.create!(name: "Salt", canonical_name: "salt")

    recipe = Recipe.create!(title: "Salted Dish")
    RecipeIngredient.create!(recipe: recipe, ingredient: salt, original_text: "salt to taste", quantity: nil)

    missing = recipe.missing_ingredients_for(user)

    assert_equal 1, missing.count
    assert_nil missing.first[:missing_quantity]
  end

  test "missing_ingredients_for does not include ingredient without recipe quantity when pantry tracks a quantity" do
    user = User.create!(email: "demo@example.com")
    salt = Ingredient.create!(name: "Salt", canonical_name: "salt")

    recipe = Recipe.create!(title: "Salted Dish")
    RecipeIngredient.create!(recipe: recipe, ingredient: salt, original_text: "salt to taste", quantity: nil)
    PantryItem.create!(user: user, ingredient: salt, quantity: 500.0, unit: "g")

    assert_empty recipe.missing_ingredients_for(user)
  end

  test "missing_ingredients_for does not include ingredient when pantry item exists without quantity" do
    user = User.create!(email: "demo@example.com")
    salt = Ingredient.create!(name: "Salt", canonical_name: "salt")

    recipe = Recipe.create!(title: "Salted Dish")
    RecipeIngredient.create!(recipe: recipe, ingredient: salt, original_text: "1 tsp salt", quantity: 1.0, unit: "tsp")

    # User has salt in pantry but no quantity specified (base ingredient)
    PantryItem.create!(user: user, ingredient: salt, quantity: nil, unit: nil)

    missing = recipe.missing_ingredients_for(user)

    # Salt should not be in missing ingredients since it exists in pantry
    salt_missing = missing.find { |m| m[:ingredient_id] == salt.id }
    assert_nil salt_missing, "Ingredient with pantry item (no quantity) should not be missing"
  end

  test "missing_ingredients_for returns all ingredients when user has no pantry items" do
    user = User.create!(email: "demo@example.com")
    pasta = Ingredient.create!(name: "Pasta", canonical_name: "pasta")
    eggs = Ingredient.create!(name: "Eggs", canonical_name: "egg")

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
    # 1kg = 1000g, user has 500g, missing 500g = 0.5kg
    assert_equal 0.5, pasta_missing[:missing_quantity]
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
    # 1kg = 1000g, used 500g, remaining 500g = 0.5kg
    assert_equal 0.5, pantry_item.quantity
    assert_equal "kg", pantry_item.unit
  end

  test "missing_ingredients_for returns empty array when user has sufficient quantities" do
    user = User.create!(email: "demo@example.com")
    pasta = Ingredient.create!(name: "Pasta", canonical_name: "pasta")
    eggs = Ingredient.create!(name: "Eggs", canonical_name: "egg")

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

  test "cook! creates a CookedRecipe for the user" do
    user = User.create!(email: "demo@example.com")
    pasta = Ingredient.create!(name: "Pasta", canonical_name: "pasta")

    recipe = Recipe.create!(title: "Simple Pasta")
    RecipeIngredient.create!(
      recipe: recipe,
      ingredient: pasta,
      quantity: 200.0,
      unit: "g",
      original_text: "200g pasta"
    )

    PantryItem.create!(
      user: user,
      ingredient: pasta,
      quantity: 500.0,
      unit: "g"
    )

    assert_difference "CookedRecipe.count", 1 do
      recipe.cook!(user)
    end

    cooked_recipe = CookedRecipe.find_by(user: user, recipe: recipe)
    assert_not_nil cooked_recipe
    assert_equal user, cooked_recipe.user
    assert_equal recipe, cooked_recipe.recipe
    assert_not_nil cooked_recipe.cooked_at
  end

  test "cook! updates existing CookedRecipe instead of creating duplicate" do
    user = User.create!(email: "demo@example.com")
    pasta = Ingredient.create!(name: "Pasta", canonical_name: "pasta")

    recipe = Recipe.create!(title: "Simple Pasta")
    RecipeIngredient.create!(
      recipe: recipe,
      ingredient: pasta,
      quantity: 200.0,
      unit: "g",
      original_text: "200g pasta"
    )

    PantryItem.create!(
      user: user,
      ingredient: pasta,
      quantity: 1000.0,
      unit: "g"
    )

    # First cook
    old_time = 2.days.ago
    cooked_recipe = CookedRecipe.create!(
      user: user,
      recipe: recipe,
      cooked_at: old_time
    )

    # Cook again - should update existing record, not create new one
    assert_no_difference "CookedRecipe.count" do
      recipe.cook!(user)
    end

    cooked_recipe.reload
    assert_equal user, cooked_recipe.user
    assert_equal recipe, cooked_recipe.recipe
    # cooked_at should be updated to current time
    assert cooked_recipe.cooked_at > old_time
    assert cooked_recipe.cooked_at <= Time.current
  end

  test "missing_ingredients_for treats incompatible units as missing" do
    user = User.create!(email: "demo@example.com")
    milk = Ingredient.create!(name: "Milk", canonical_name: "milk")

    recipe = Recipe.create!(title: "Cake")
    RecipeIngredient.create!(recipe: recipe, ingredient: milk, original_text: "1 cup milk", quantity: 1.0, unit: "cup")

    # Weight can't be compared with volume
    PantryItem.create!(user: user, ingredient: milk, quantity: 500.0, unit: "g")

    missing = recipe.missing_ingredients_for(user)

    assert_equal 1, missing.count
    assert_equal 1.0, missing.first[:missing_quantity]
  end

  test "missing_ingredients_for treats a pantry quantity without unit as missing for a measured recipe unit" do
    user = User.create!(email: "demo@example.com")
    pasta = Ingredient.create!(name: "Pasta", canonical_name: "pasta")

    recipe = Recipe.create!(title: "Pasta Dish")
    RecipeIngredient.create!(recipe: recipe, ingredient: pasta, original_text: "200g pasta", quantity: 200.0, unit: "g")
    PantryItem.create!(user: user, ingredient: pasta, quantity: 500.0, unit: nil)

    missing = recipe.missing_ingredients_for(user)

    assert_equal 1, missing.count
    assert_equal 200.0, missing.first[:missing_quantity]
  end
end
