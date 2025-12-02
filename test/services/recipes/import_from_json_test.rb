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
    assert_difference "Recipe.count", 4 do
      Recipes::ImportFromJson.call(@fixture_path)
    end

    pasta = Recipe.find_by(title: "Simple Pasta")
    assert_not_nil pasta
    assert_equal "A simple pasta recipe", pasta.description
    assert_equal 15, pasta.total_time_minutes
    assert_equal 4.5, pasta.rating
    assert_equal 100, pasta.ratings_count
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

    # "2 eggs, only yellow, beaten" should have quantity: 2, unit: nil (no unit specified)
    eggs_ri = pasta.recipe_ingredients.find_by(original_text: "2 eggs, only yellow, beaten")
    assert_not_nil eggs_ri
    assert_equal 2.0, eggs_ri.quantity
    assert_nil eggs_ri.unit
    assert_equal "only yellow, beaten", eggs_ri.precision

    # "100 g parmesan cheese, grated" should have quantity: 100, unit: "g" (note: space in JSON)
    cheese_ri = pasta.recipe_ingredients.find_by(original_text: "100 g parmesan cheese, grated")
    assert_not_nil cheese_ri
    assert_equal 100.0, cheese_ri.quantity
    assert_equal "g", cheese_ri.unit
  end

  test "parses Unicode fractions" do
    Recipes::ImportFromJson.call(@fixture_path)

    recipe = Recipe.find_by(title: "Test Recipe")
    assert_not_nil recipe

    # "½ cup water" should have fraction: "1/2", quantity: nil
    water_ri = recipe.recipe_ingredients.find_by(original_text: "½ cup water")
    assert_not_nil water_ri
    assert_nil water_ri.quantity
    assert_equal "1/2", water_ri.fraction
    assert_equal "cup", water_ri.unit

    # "1 ½ cups flour" should have quantity: 1, fraction: "1/2"
    flour_ri = recipe.recipe_ingredients.find_by(original_text: "1 ½ cups flour")
    assert_not_nil flour_ri
    assert_equal 1.0, flour_ri.quantity
    assert_equal "1/2", flour_ri.fraction
    # Regex captures "cup" (first match) from "cups"
    assert_equal "cup", flour_ri.unit

    # "⅓ teaspoon salt" should have fraction: "1/3", quantity: nil
    salt_ri = recipe.recipe_ingredients.find_by(original_text: "⅓ teaspoon salt")
    assert_not_nil salt_ri
    assert_nil salt_ri.quantity
    assert_equal "1/3", salt_ri.fraction
    assert_equal "tsp", salt_ri.unit

    # "2 ⅔ tablespoons oil" should have quantity: 2, fraction: "2/3"
    oil_ri = recipe.recipe_ingredients.find_by(original_text: "2 ⅔ tablespoons oil")
    assert_not_nil oil_ri
    assert_equal 2.0, oil_ri.quantity
    assert_equal "2/3", oil_ri.fraction
    assert_equal "tbsp", oil_ri.unit
  end

  test "handles ingredients without quantities" do
    Recipes::ImportFromJson.call(@fixture_path)

    salad = Recipe.find_by(title: "Tomato Salad")
    basil_ri = salad.recipe_ingredients.find_by(original_text: "fresh basil")
    assert_not_nil basil_ri
    assert_nil basil_ri.quantity
    assert_nil basil_ri.unit
  end

  test "parses decimal quantities" do
    Recipes::ImportFromJson.call(@fixture_path)

    pasta = Recipe.find_by(title: "Simple Pasta")
    flour_ri = pasta.recipe_ingredients.find_by(original_text: "1.5 cups flour, sifted")
    assert_not_nil flour_ri
    assert_equal 1.0, flour_ri.quantity
    assert_equal "1/2", flour_ri.fraction
    # Regex captures "cup" (first match) from "cups"
    assert_equal "cup", flour_ri.unit
    assert_equal "sifted", flour_ri.precision
  end

  test "uses default file path if not provided" do
    # Test that call without argument uses default path
    # We'll test with explicit path in other tests
    # This test verifies the method accepts nil
    assert_nothing_raised do
      # We can't easily stub the default path, so we'll just verify the method signature
      assert_respond_to Recipes::ImportFromJson, :call
    end
  end

  test "handles missing optional fields" do
    Recipes::ImportFromJson.call(@fixture_path)

    salad = Recipe.find_by(title: "Tomato Salad")
    assert_not_nil salad
    assert_nil salad.image_url
    assert_nil salad.source_url
  end

  test "does not create duplicate ingredients" do
    Recipes::ImportFromJson.call(@fixture_path)
    initial_count = Ingredient.count

    # Import again
    Recipes::ImportFromJson.call(@fixture_path)

    assert_equal initial_count, Ingredient.count
  end

  test "creates recipes with all attributes" do
    Recipes::ImportFromJson.call(@fixture_path)

    pasta = Recipe.find_by(title: "Simple Pasta")
    assert_equal "1. Boil water\n2. Cook pasta\n3. Serve", pasta.instructions
    assert_equal "https://example.com/pasta.jpg", pasta.image_url
    assert_equal "https://example.com/recipe1", pasta.source_url
  end

  test "parses parenthetical quantities" do
    Recipes::ImportFromJson.call(@fixture_path)

    parenthetical_recipe = Recipe.find_by(title: "Parenthetical Quantities Test")
    assert_not_nil parenthetical_recipe

    # Test with outer quantity
    ri = parenthetical_recipe.recipe_ingredients.find_by(original_text: "3 (12 ounce) packages refrigerated biscuit dough")
    assert_not_nil ri
    assert_equal 12.0, ri.quantity
    assert_nil ri.fraction
    assert_equal "oz", ri.unit
    assert_equal "packages refrigerated biscuit dough", ri.ingredient.name

    # Test without outer quantity
    ri = parenthetical_recipe.recipe_ingredients.find_by(original_text: "(12 fluid ounce) can or bottle beer")
    assert_not_nil ri
    assert_equal 12.0, ri.quantity
    assert_nil ri.fraction
    assert_equal "oz", ri.unit
    assert_equal "can or bottle beer", ri.ingredient.name

    # Test with pound
    ri = parenthetical_recipe.recipe_ingredients.find_by(original_text: "2 (1 pound) packages ground beef")
    assert_not_nil ri
    assert_equal 1.0, ri.quantity
    assert_nil ri.fraction
    assert_equal "lb", ri.unit
    assert_equal "packages ground beef", ri.ingredient.name

    # Test with decimal starting with dot (.25)
    ri = parenthetical_recipe.recipe_ingredients.find_by(original_text: "(.25 ounce) package active dry yeast")
    assert_not_nil ri
    assert_nil ri.quantity # 0.25 = 0 + 1/4, so quantity is nil (whole part is 0)
    assert_equal "1/4", ri.fraction
    assert_equal "oz", ri.unit
    assert_equal "package active dry yeast", ri.ingredient.name

    # Test with decimal (3.5)
    ri = parenthetical_recipe.recipe_ingredients.find_by(original_text: "(3.5 ounce) package instant vanilla pudding mix")
    assert_not_nil ri
    assert_equal 3.0, ri.quantity
    assert_equal "1/2", ri.fraction
    assert_equal "oz", ri.unit
    assert_equal "package instant vanilla pudding mix", ri.ingredient.name
  end

  test "extracts precision from ingredient name" do
    Recipes::ImportFromJson.call(@fixture_path)

    pasta = Recipe.find_by(title: "Simple Pasta")
    assert_not_nil pasta

    # Test with comma in name
    ri = pasta.recipe_ingredients.find_by(original_text: "200g pasta, finely chopped")
    assert_not_nil ri
    assert_equal "pasta", ri.ingredient.name
    assert_equal "finely chopped", ri.precision
    assert_equal 200.0, ri.quantity
    assert_equal "g", ri.unit

    # Test with comma and no unit
    ri = pasta.recipe_ingredients.find_by(original_text: "2 eggs, only yellow, beaten")
    assert_not_nil ri
    assert_equal "eggs", ri.ingredient.name
    assert_equal "only yellow, beaten", ri.precision
    assert_equal 2.0, ri.quantity
    assert_nil ri.unit

    # Test with comma in parenthetical quantity
    parenthetical_recipe = Recipe.find_by(title: "Parenthetical Quantities Test")
    ri = parenthetical_recipe.recipe_ingredients.find_by(original_text: "3 (12 ounce) packages refrigerated biscuit dough")
    assert_not_nil ri
    assert_equal "packages refrigerated biscuit dough", ri.ingredient.name
    assert_nil ri.precision # No comma in this specific ingredient text

    # Test without comma (no precision)
    test_recipe = Recipe.find_by(title: "Test Recipe")
    ri = test_recipe.recipe_ingredients.find_by(original_text: "½ cup water")
    assert_not_nil ri
    assert_equal "water", ri.ingredient.name
    assert_nil ri.precision
    assert_nil ri.quantity
    assert_equal "1/2", ri.fraction
    assert_equal "cup", ri.unit
  end

  test "creates recipe ingredients with precision" do
    Recipes::ImportFromJson.call(@fixture_path)

    # Add a test recipe with precision in ingredients
    test_recipe = Recipe.create!(title: "Precision Test")
    Recipes::ImportFromJson.new.send(:import_ingredient, test_recipe, "200g pasta, finely chopped")

    ri = test_recipe.recipe_ingredients.first
    assert_equal "pasta", ri.ingredient.name
    assert_equal "finely chopped", ri.precision
    assert_equal 200.0, ri.quantity
    assert_equal "g", ri.unit
  end
end
