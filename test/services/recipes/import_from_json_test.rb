require "test_helper"

class Recipes::ImportFromJsonTest < ActiveSupport::TestCase
  setup do
    @fixture_path = Rails.root.join("test", "fixtures", "files", "recipes_minimal.json")
    # Clean up before each test
    Recipe.destroy_all
    Ingredient.destroy_all
    RecipeIngredient.destroy_all
  end

  test "imports recipes from JSON file" do
    assert_difference "Recipe.count", 5 do
      Recipes::ImportFromJson.call(@fixture_path)
    end

    pasta = Recipe.find_by(title: "Simple Pasta")
    assert_not_nil pasta
    assert_equal 10, pasta.cook_time
    assert_equal 5, pasta.prep_time
    assert_equal "https://example.com/pasta.jpg", pasta.image_url
    assert_equal "Italian", pasta.category
    assert_equal 4.5, pasta.ratings
  end

  test "creates ingredients with canonical names" do
    Recipes::ImportFromJson.call(@fixture_path)

    # "200g pasta" becomes "pasta" after canonicalize (removes numbers and units)
    pasta_ingredient = Ingredient.find_by(canonical_name: "pasta")
    assert_not_nil pasta_ingredient
    assert_equal "pasta", pasta_ingredient.canonical_name

    egg_ingredient = Ingredient.find_by(canonical_name: "eggs")
    assert_not_nil egg_ingredient
  end

  test "extracts ingredient name without quantity and unit" do
    Recipes::ImportFromJson.call(@fixture_path)

    # "1.5 cups flour" should have name "flour" (not "1.5 cups flour")
    flour_ingredient = Ingredient.find_by(canonical_name: "flour")
    assert_not_nil flour_ingredient
    assert_equal "flour", flour_ingredient.name

    # "200g pasta" should have name "pasta" (not "200g pasta")
    pasta_ingredient = Ingredient.find_by(canonical_name: "pasta")
    assert_not_nil pasta_ingredient
    assert_equal "pasta", pasta_ingredient.name

    # "2 eggs" should have name "eggs" (not "2 eggs")
    egg_ingredient = Ingredient.find_by(canonical_name: "eggs")
    assert_not_nil egg_ingredient
    assert_equal "eggs", egg_ingredient.name

    # "100 g parmesan cheese" should have name "parmesan cheese" (not "100 g parmesan cheese")
    cheese_ingredient = Ingredient.find_by(canonical_name: "parmesan cheese")
    assert_not_nil cheese_ingredient
    assert_equal "parmesan cheese", cheese_ingredient.name
  end

  test "creates recipe_ingredients with original_text" do
    Recipes::ImportFromJson.call(@fixture_path)

    pasta = Recipe.find_by(title: "Simple Pasta")
    assert_equal 4, pasta.recipe_ingredients.count

    recipe_ingredient = pasta.recipe_ingredients.find_by(original_text: "200g pasta, finely chopped")
    assert_not_nil recipe_ingredient
    assert_equal "pasta", recipe_ingredient.ingredient.canonical_name
    assert_equal "finely chopped", recipe_ingredient.precision
  end

  test "parses and stores quantities" do
    Recipes::ImportFromJson.call(@fixture_path)

    pasta = Recipe.find_by(title: "Simple Pasta")

    # "200g pasta, finely chopped" should have quantity: 200, unit: "g"
    pasta_ri = pasta.recipe_ingredients.find_by(original_text: "200g pasta, finely chopped")
    assert_not_nil pasta_ri
    assert_equal 200.0, pasta_ri.quantity
    assert_equal "g", pasta_ri.unit
    assert_equal "finely chopped", pasta_ri.precision

    # "2 eggs, only yellow, beaten" should have quantity: 2, unit: nil (pcs is implicit)
    eggs_ri = pasta.recipe_ingredients.find_by(original_text: "2 eggs, only yellow, beaten")
    assert_not_nil eggs_ri
    assert_equal 2.0, eggs_ri.quantity
    assert_nil eggs_ri.unit
    assert_equal "only yellow, beaten", eggs_ri.precision

    # "100 g parmesan cheese, grated" should have quantity: 100, unit: "g"
    cheese_ri = pasta.recipe_ingredients.find_by(original_text: "100 g parmesan cheese, grated")
    assert_not_nil cheese_ri
    assert_equal 100.0, cheese_ri.quantity
    assert_equal "g", cheese_ri.unit
    assert_equal "grated", cheese_ri.precision

    # "1.5 cups flour, sifted" should have quantity: 1, fraction: "1/2", unit: "cup"
    flour_ri = pasta.recipe_ingredients.find_by(original_text: "1.5 cups flour, sifted")
    assert_not_nil flour_ri
    assert_equal 1.0, flour_ri.quantity
    assert_equal "1/2", flour_ri.fraction
    assert_equal "cup", flour_ri.unit
    assert_equal "sifted", flour_ri.precision
  end

  test "parses Unicode fractions" do
    Recipes::ImportFromJson.call(@fixture_path)

    test_recipe = Recipe.find_by(title: "Test Recipe")
    assert_not_nil test_recipe

    # "½ cup water" should have fraction: "1/2", unit: "cup"
    water_ri = test_recipe.recipe_ingredients.find_by(original_text: "½ cup water")
    assert_not_nil water_ri
    assert_nil water_ri.quantity
    assert_equal "1/2", water_ri.fraction
    assert_equal "cup", water_ri.unit

    # "1 ½ cups flour" should have quantity: 1, fraction: "1/2", unit: "cup"
    flour_ri = test_recipe.recipe_ingredients.find_by(original_text: "1 ½ cups flour")
    assert_not_nil flour_ri
    assert_equal 1.0, flour_ri.quantity
    assert_equal "1/2", flour_ri.fraction
    assert_equal "cup", flour_ri.unit

    # "⅓ teaspoon salt" should have fraction: "1/3", unit: "tsp"
    salt_ri = test_recipe.recipe_ingredients.find_by(original_text: "⅓ teaspoon salt")
    assert_not_nil salt_ri
    assert_nil salt_ri.quantity
    assert_equal "1/3", salt_ri.fraction
    assert_equal "tsp", salt_ri.unit

    # "2 ⅔ tablespoons oil" should have quantity: 2, fraction: "2/3", unit: "tbsp"
    oil_ri = test_recipe.recipe_ingredients.find_by(original_text: "2 ⅔ tablespoons oil")
    assert_not_nil oil_ri
    assert_equal 2.0, oil_ri.quantity
    assert_equal "2/3", oil_ri.fraction
    assert_equal "tbsp", oil_ri.unit
  end

  test "parses decimal quantities" do
    Recipes::ImportFromJson.call(@fixture_path)

    pasta = Recipe.find_by(title: "Simple Pasta")

    # "1.5 cups flour" should be converted to quantity: 1, fraction: "1/2"
    flour_ri = pasta.recipe_ingredients.find_by(original_text: "1.5 cups flour, sifted")
    assert_not_nil flour_ri
    assert_equal 1.0, flour_ri.quantity
    assert_equal "1/2", flour_ri.fraction
  end

  test "parses parenthetical quantities" do
    Recipes::ImportFromJson.call(@fixture_path)

    parenthetical_recipe = Recipe.find_by(title: "Parenthetical Quantities Test")
    assert_not_nil parenthetical_recipe

    # "3 (12 ounce) packages refrigerated biscuit dough"
    # Should use inner quantity (12) and unit (oz), ignore outer quantity (3)
    biscuit_ri = parenthetical_recipe.recipe_ingredients.find_by(
      original_text: "3 (12 ounce) packages refrigerated biscuit dough"
    )
    assert_not_nil biscuit_ri
    assert_equal 12.0, biscuit_ri.quantity
    assert_equal "oz", biscuit_ri.unit
    assert_equal "packages refrigerated biscuit dough", biscuit_ri.ingredient.name

    # "(12 ounce) packages refrigerated biscuit dough" (no outer quantity)
    # Should use inner quantity (12) and unit (oz)
    biscuit2_ri = parenthetical_recipe.recipe_ingredients.find_by(
      original_text: "(12 ounce) packages refrigerated biscuit dough"
    )
    assert_not_nil biscuit2_ri
    assert_equal 12.0, biscuit2_ri.quantity
    assert_equal "oz", biscuit2_ri.unit

    # "2 (1 pound) packages ground beef"
    # Should use inner quantity (1) and unit (lb), ignore outer quantity (2)
    beef_ri = parenthetical_recipe.recipe_ingredients.find_by(
      original_text: "2 (1 pound) packages ground beef"
    )
    assert_not_nil beef_ri
    assert_equal 1.0, beef_ri.quantity
    assert_equal "lb", beef_ri.unit

    # "(3.5 ounce) package instant vanilla pudding mix"
    # Should convert 3.5 to quantity: 3, fraction: "1/2"
    pudding_ri = parenthetical_recipe.recipe_ingredients.find_by(
      original_text: "(3.5 ounce) package instant vanilla pudding mix"
    )
    assert_not_nil pudding_ri
    assert_equal 3.0, pudding_ri.quantity
    assert_equal "1/2", pudding_ri.fraction
    assert_equal "oz", pudding_ri.unit

    # "(.25 ounce) package active dry yeast"
    # Should have quantity: nil, fraction: "1/4"
    yeast_ri = parenthetical_recipe.recipe_ingredients.find_by(
      original_text: "(.25 ounce) package active dry yeast"
    )
    assert_not_nil yeast_ri
    assert_nil yeast_ri.quantity
    assert_equal "1/4", yeast_ri.fraction
    assert_equal "oz", yeast_ri.unit
  end

  test "extracts precision from ingredient name" do
    Recipes::ImportFromJson.call(@fixture_path)

    pasta = Recipe.find_by(title: "Simple Pasta")

    # "200g pasta, finely chopped" should have precision: "finely chopped"
    pasta_ri = pasta.recipe_ingredients.find_by(original_text: "200g pasta, finely chopped")
    assert_not_nil pasta_ri
    assert_equal "finely chopped", pasta_ri.precision

    # "2 eggs, only yellow, beaten" should have precision: "only yellow, beaten"
    eggs_ri = pasta.recipe_ingredients.find_by(original_text: "2 eggs, only yellow, beaten")
    assert_not_nil eggs_ri
    assert_equal "only yellow, beaten", eggs_ri.precision
  end

  test "parses large potatoes correctly without matching l as unit" do
    Recipes::ImportFromJson.call(@fixture_path)

    potatoes_recipe = Recipe.find_by(title: "Large Potatoes Test")
    assert_not_nil potatoes_recipe

    # "2 large potatoes, peeled and thinly sliced"
    # Should have: quantity: 2, unit: nil (not "l"), name: "large potatoes", precision: "peeled and thinly sliced"
    potatoes_ri = potatoes_recipe.recipe_ingredients.find_by(
      original_text: "2 large potatoes, peeled and thinly sliced"
    )
    assert_not_nil potatoes_ri
    assert_equal 2.0, potatoes_ri.quantity
    assert_nil potatoes_ri.unit, "Unit should be nil, not 'l' (litre)"
    assert_equal "large potatoes", potatoes_ri.ingredient.name
    assert_equal "peeled and thinly sliced", potatoes_ri.precision
  end
end
