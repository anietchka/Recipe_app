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
    assert_difference "Recipe.count", 2 do
      Recipes::ImportFromJson.call(@fixture_path)
    end

    test_recipe = Recipe.find_by(title: "Test Recipe")
    assert_not_nil test_recipe
    assert_equal 20, test_recipe.cook_time
    assert_equal 5, test_recipe.prep_time
    assert_nil test_recipe.image_url
    assert_equal "Test", test_recipe.category
    assert_equal 4.0, test_recipe.ratings
  end

  test "all recipes are imported correctly" do
    Recipes::ImportFromJson.call(@fixture_path)
    assert_equal 2, Recipe.count
    assert_equal "Test Recipe", Recipe.first.title
    assert_equal "Tomato Salad", Recipe.last.title
  end

  test "ingredient name is canonical name titleized" do
    Recipes::ImportFromJson.call(@fixture_path)
    assert_equal "Basil", Ingredient.find_by(canonical_name: "basil").name
    assert_equal "Onion", Ingredient.find_by(canonical_name: "onion").name
    assert_equal "Tomato", Ingredient.find_by(canonical_name: "tomato").name
    assert_equal "Beef", Ingredient.find_by(canonical_name: "beef").name
    assert_equal "Parsley", Ingredient.find_by(canonical_name: "parsley").name
  end

  test "all ingredients are parsed correctly" do
    Recipes::ImportFromJson.call(@fixture_path)

    test_recipe = Recipe.find_by(title: "Test Recipe")
    assert_not_nil test_recipe, "Test recipe should exist"


    # Test case 1: "fresh basil" -> canonical_name: "basil"
    fresh_basil_ri = test_recipe.recipe_ingredients.find_by(original_text: "fresh basil")
    assert_not_nil fresh_basil_ri
    assert_equal "Basil", fresh_basil_ri.ingredient.name
    assert_equal "basil", fresh_basil_ri.ingredient.canonical_name
    assert_nil fresh_basil_ri.quantity
    assert_nil fresh_basil_ri.fraction
    assert_nil fresh_basil_ri.unit

    # Test case 2: "chopped onions" -> canonical_name: "onion"
    chopped_onions_ri = test_recipe.recipe_ingredients.find_by(original_text: "chopped onions")
    assert_not_nil chopped_onions_ri
    assert_equal "Onion", chopped_onions_ri.ingredient.name
    assert_equal "onion", chopped_onions_ri.ingredient.canonical_name
    assert_nil chopped_onions_ri.quantity
    assert_nil chopped_onions_ri.fraction
    assert_nil chopped_onions_ri.unit

    # Test case 3: "small tomatoes, diced" -> canonical_name: "tomato"
    small_tomatoes_ri = test_recipe.recipe_ingredients.find_by(original_text: "small tomatoes, diced")
    assert_not_nil small_tomatoes_ri
    assert_equal "Tomato", small_tomatoes_ri.ingredient.name
    assert_equal "tomato", small_tomatoes_ri.ingredient.canonical_name
    assert_nil small_tomatoes_ri.quantity
    assert_nil small_tomatoes_ri.fraction
    assert_nil small_tomatoes_ri.unit

    # Test case 4: "ground beef" -> canonical_name: "beef"
    ground_beef_ri = test_recipe.recipe_ingredients.find_by(original_text: "ground beef")
    assert_not_nil ground_beef_ri
    assert_equal "Beef", ground_beef_ri.ingredient.name
    assert_equal "beef", ground_beef_ri.ingredient.canonical_name
    assert_nil ground_beef_ri.quantity
    assert_nil ground_beef_ri.fraction
    assert_nil ground_beef_ri.unit

    # Test case 5: "finely chopped parsley" -> canonical_name: "parsley"
    parsley_ri = test_recipe.recipe_ingredients.find_by(original_text: "finely chopped parsley")
    assert_not_nil parsley_ri
    assert_equal "Parsley", parsley_ri.ingredient.name
    assert_equal "parsley", parsley_ri.ingredient.canonical_name
    assert_nil parsley_ri.quantity
    assert_nil parsley_ri.fraction
    assert_nil parsley_ri.unit

    # Test case 6: "1 cup warm milk" -> canonical_name: "milk"
    warm_milk_ri = test_recipe.recipe_ingredients.find_by(original_text: "1 cup warm milk")
    assert_not_nil warm_milk_ri
    assert_equal "Milk", warm_milk_ri.ingredient.name
    assert_equal "milk", warm_milk_ri.ingredient.canonical_name
    assert_equal 1, warm_milk_ri.quantity
    assert_nil warm_milk_ri.fraction
    assert_equal "cup", warm_milk_ri.unit

    # Test case 7: "boneless skinless chicken breast, with no bones or skin" -> canonical_name: "chicken"
    chicken_ri = test_recipe.recipe_ingredients.find_by(original_text: "boneless skinless chicken breast, with no bones or skin")
    assert_not_nil chicken_ri
    assert_equal "Chicken", chicken_ri.ingredient.name
    assert_equal "chicken", chicken_ri.ingredient.canonical_name
    assert_nil chicken_ri.quantity
    assert_nil chicken_ri.fraction
    assert_nil chicken_ri.unit

    # Test case 8: "refrigerated biscuit dough" -> canonical_name: "biscuit"
    biscuit_ri = test_recipe.recipe_ingredients.find_by(original_text: "refrigerated biscuit dough")
    assert_not_nil biscuit_ri
    assert_equal "Biscuit", biscuit_ri.ingredient.name
    assert_equal "biscuit", biscuit_ri.ingredient.canonical_name
    assert_nil biscuit_ri.quantity
    assert_nil biscuit_ri.fraction
    assert_nil biscuit_ri.unit
    # Test case 9: "lukewarm water" -> canonical_name: "water"
    water_ri = test_recipe.recipe_ingredients.find_by(original_text: "½ cup lukewarm water")
    assert_not_nil water_ri
    assert_equal "Water", water_ri.ingredient.name
    assert_equal "water", water_ri.ingredient.canonical_name
    assert_nil water_ri.quantity
    assert_equal "1/2", water_ri.fraction
    assert_equal "cup", water_ri.unit

    # Test case 10: "(.25 ounce) package active dry yeast" -> canonical_name: "yeast"
    yeast_ri = test_recipe.recipe_ingredients.find_by(original_text: "(.25 ounce) package active dry yeast")
    assert_not_nil yeast_ri
    assert_equal "Yeast", yeast_ri.ingredient.name
    assert_equal "yeast", yeast_ri.ingredient.canonical_name
    assert_nil yeast_ri.quantity
    assert_equal "1/4", yeast_ri.fraction
    assert_equal "oz", yeast_ri.unit

    # Test case 11: "3 (12 ounce) packages refrigerated biscuit dough" -> canonical_name: "biscuit"
    biscuit_ri = test_recipe.recipe_ingredients.find_by(original_text: "3 (12 ounce) packages refrigerated biscuit dough")
    assert_not_nil biscuit_ri
    assert_equal "Biscuit", biscuit_ri.ingredient.name
    assert_equal "biscuit", biscuit_ri.ingredient.canonical_name
    assert_equal 12, biscuit_ri.quantity
    assert_nil biscuit_ri.fraction
    assert_equal "oz", biscuit_ri.unit

    # Test case 12: "(12 ounce) packages refrigerated biscuit dough" -> canonical_name: "biscuit"
    biscuit_ri = test_recipe.recipe_ingredients.find_by(original_text: "(12 ounce) packages refrigerated biscuit dough")
    assert_not_nil biscuit_ri
    assert_equal "Biscuit", biscuit_ri.ingredient.name
    assert_equal "biscuit", biscuit_ri.ingredient.canonical_name
    assert_equal 12, biscuit_ri.quantity
    assert_nil biscuit_ri.fraction
    assert_equal "oz", biscuit_ri.unit

    # Test case 13: "2 (1 pound) packages ground beef" -> canonical_name: "beef"
    beef_ri = test_recipe.recipe_ingredients.find_by(original_text: "2 (1 pound) packages ground beef")
    assert_not_nil beef_ri
    assert_equal "Beef", beef_ri.ingredient.name
    assert_equal "beef", beef_ri.ingredient.canonical_name
    assert_equal 1, beef_ri.quantity
    assert_nil beef_ri.fraction
    assert_equal "lb", beef_ri.unit

    # Test case 14: "1 pound ground beef" -> canonical_name: "beef"
    beef_ri = test_recipe.recipe_ingredients.find_by(original_text: "1 pound ground beef")
    assert_not_nil beef_ri
    assert_equal "Beef", beef_ri.ingredient.name
    assert_equal "beef", beef_ri.ingredient.canonical_name
    assert_equal 1, beef_ri.quantity
    assert_nil beef_ri.fraction
    assert_equal "lb", beef_ri.unit

    # Test case 15: "2 pounds chicken" -> canonical_name: "chicken"
    chicken_ri = test_recipe.recipe_ingredients.find_by(original_text: "2 pounds chicken")
    assert_not_nil chicken_ri
    assert_equal "Chicken", chicken_ri.ingredient.name
    assert_equal "chicken", chicken_ri.ingredient.canonical_name
    assert_equal 2, chicken_ri.quantity
    assert_nil chicken_ri.fraction
    assert_equal "lb", chicken_ri.unit

    # Test case 16: "8 ounce cheese" -> canonical_name: "cheese"
    cheese_ri = test_recipe.recipe_ingredients.find_by(original_text: "8 ounce cheese")
    assert_not_nil cheese_ri
    assert_equal "Cheese", cheese_ri.ingredient.name
    assert_equal "cheese", cheese_ri.ingredient.canonical_name
    assert_equal 8, cheese_ri.quantity
    assert_nil cheese_ri.fraction
    assert_equal "oz", cheese_ri.unit

    # Test case 17: "12 ounces flour" -> canonical_name: "flour"
    flour_ri = test_recipe.recipe_ingredients.find_by(original_text: "12 ounces flour")
    assert_not_nil flour_ri
    assert_equal "Flour", flour_ri.ingredient.name
    assert_equal "flour", flour_ri.ingredient.canonical_name
    assert_equal 12, flour_ri.quantity
    assert_nil flour_ri.fraction
    assert_equal "oz", flour_ri.unit

    # Test case 18: "200g pasta, finely chopped" -> canonical_name: "pasta"
    pasta_ri = test_recipe.recipe_ingredients.find_by(original_text: "200g pasta, finely chopped")
    assert_not_nil pasta_ri
    assert_equal "Pasta", pasta_ri.ingredient.name
    assert_equal "pasta", pasta_ri.ingredient.canonical_name
    assert_equal 200, pasta_ri.quantity
    assert_nil pasta_ri.fraction
    assert_equal "g", pasta_ri.unit

    # Test case 19: "2 eggs, only yellow, beaten" -> canonical_name: "egg"
    eggs_ri = test_recipe.recipe_ingredients.find_by(original_text: "2 eggs, only yellow, beaten")
    assert_not_nil eggs_ri
    assert_equal "Egg", eggs_ri.ingredient.name
    assert_equal "egg", eggs_ri.ingredient.canonical_name
    assert_equal 2, eggs_ri.quantity
    assert_nil eggs_ri.fraction
    assert_equal "pcs", eggs_ri.unit #when quantity is present and no unit is present, pcs is implicit

    # Test case 20: "100 g parmesan cheese, grated" -> canonical_name: "cheese"
    cheese_ri = test_recipe.recipe_ingredients.find_by(original_text: "100 g parmesan cheese, grated")
    assert_not_nil cheese_ri
    assert_equal "Cheese", cheese_ri.ingredient.name
    assert_equal "cheese", cheese_ri.ingredient.canonical_name
    assert_equal 100, cheese_ri.quantity
    assert_nil cheese_ri.fraction
    assert_equal "g", cheese_ri.unit

    # Test case 21: "1.5 cups flour, sifted" -> canonical_name: "flour"
    flour_ri = test_recipe.recipe_ingredients.find_by(original_text: "1.5 cups flour, sifted")
    assert_not_nil flour_ri
    assert_equal "Flour", flour_ri.ingredient.name
    assert_equal "flour", flour_ri.ingredient.canonical_name
    assert_equal 1.0, flour_ri.quantity
    assert_equal "1/2", flour_ri.fraction
    assert_equal "cup", flour_ri.unit

    # Test case 22: "2 large potatoes, peeled and thinly sliced" -> canonical_name: "potato"
    potatoes_ri = test_recipe.recipe_ingredients.find_by(original_text: "2 large potatoes, peeled and thinly sliced")
    assert_not_nil potatoes_ri
    assert_equal "Potato", potatoes_ri.ingredient.name
    assert_equal "potato", potatoes_ri.ingredient.canonical_name
    assert_equal 2, potatoes_ri.quantity
    assert_nil potatoes_ri.fraction
    assert_equal "pcs", potatoes_ri.unit #when quantity is present and no unit is present, pcs is implicit

    # Test case 23: "1 ½ cups all-purpose flour, sifted" -> canonical_name: "flour"
    flour_ri = test_recipe.recipe_ingredients.find_by(original_text: "1 ½ cups all-purpose flour, sifted")
    assert_not_nil flour_ri
    assert_equal "Flour", flour_ri.ingredient.name
    assert_equal "flour", flour_ri.ingredient.canonical_name
    assert_equal 1.0, flour_ri.quantity
    assert_equal "1/2", flour_ri.fraction
    assert_equal "cup", flour_ri.unit

    # Test case 24: "⅓ teaspoon salt" -> canonical_name: "salt"
    salt_ri = test_recipe.recipe_ingredients.find_by(original_text: "⅓ teaspoon salt")
    assert_not_nil salt_ri
    assert_equal "Salt", salt_ri.ingredient.name
    assert_equal "salt", salt_ri.ingredient.canonical_name
    assert_nil salt_ri.quantity
    assert_equal "1/3", salt_ri.fraction

    # Test case 25: "2 ⅔ tablespoons oil, sifted" -> canonical_name: "oil"
    oil_ri = test_recipe.recipe_ingredients.find_by(original_text: "2 ⅔ tablespoons oil, sifted")
    assert_not_nil oil_ri
    assert_equal "Oil", oil_ri.ingredient.name
    assert_equal "oil", oil_ri.ingredient.canonical_name
    assert_equal 2, oil_ri.quantity
    assert_equal "2/3", oil_ri.fraction
    assert_equal "tbsp", oil_ri.unit

    # Test case 26: "1L milk" -> canonical_name: "milk"
    milk_ri = test_recipe.recipe_ingredients.find_by(original_text: "1L milk")
    assert_not_nil milk_ri
    assert_equal "Milk", milk_ri.ingredient.name
    assert_equal "milk", milk_ri.ingredient.canonical_name
    assert_equal 1, milk_ri.quantity
    assert_nil milk_ri.fraction
    assert_equal "l", milk_ri.unit

    # Test case 27: "2l water" -> canonical_name: "water"
    water_ri = test_recipe.recipe_ingredients.find_by(original_text: "2l water")
    assert_not_nil water_ri
    assert_equal "Water", water_ri.ingredient.name
    assert_equal "water", water_ri.ingredient.canonical_name
    assert_equal 2, water_ri.quantity
    assert_nil water_ri.fraction
    assert_equal "l", water_ri.unit
  end
end
