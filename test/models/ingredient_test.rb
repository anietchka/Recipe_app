require "test_helper"

class IngredientTest < ActiveSupport::TestCase
  # Tests for canonicalize method
  test "canonicalize converts to lowercase" do
    assert_equal "onion", Ingredient.canonicalize("ONION")
    # Note: new logic takes last word as root, so "Yellow Onion" -> "onion"
    assert_equal "onion", Ingredient.canonicalize("Yellow Onion")
  end

  test "canonicalize removes non-alphabetic characters" do
    assert_equal "onion", Ingredient.canonicalize("onion!")
    # Note: new logic takes last word as root
    assert_equal "onion", Ingredient.canonicalize("yellow-onion")
    assert_equal "tomato", Ingredient.canonicalize("tomato123")
  end

  test "canonicalize compresses spaces" do
    # Note: new logic takes last word as root and removes parasitic words
    assert_equal "onion", Ingredient.canonicalize("yellow  onion")
    assert_equal "basil", Ingredient.canonicalize("fresh   basil")
  end

  test "canonicalize trims whitespace" do
    assert_equal "onion", Ingredient.canonicalize("  onion  ")
    # Note: new logic takes last word as root
    assert_equal "onion", Ingredient.canonicalize(" yellow onion ")
  end

  test "canonicalize handles complex examples" do
    # Note: new logic takes last word as root, removes parasitic words, and singularizes
    assert_equal "onion", Ingredient.canonicalize("2 Yellow Onions, finely chopped!")
    assert_equal "leafe", Ingredient.canonicalize("Fresh Basil Leaves (10g)")
  end

  # Tests for improved canonicalize with root extraction and singularization
  test "canonicalize extracts root from potato variants" do
    assert_equal "potato", Ingredient.canonicalize("large potatoes")
    assert_equal "potato", Ingredient.canonicalize("russet potatoes, peeled")
    assert_equal "potato", Ingredient.canonicalize("small potatoes chopped")
    assert_equal "potato", Ingredient.canonicalize("potato")
    assert_equal "potato", Ingredient.canonicalize("potatoes")
  end

  test "canonicalize removes parasitic words" do
    parasitic_words = %w[large small medium chopped diced sliced fresh peeled minced boneless skinless ground]
    parasitic_words.each do |word|
      assert_equal "onion", Ingredient.canonicalize("#{word} onion"), "Should remove '#{word}'"
      assert_equal "onion", Ingredient.canonicalize("onion #{word}"), "Should remove '#{word}' at end"
    end
  end

  test "canonicalize singularizes words ending in es" do
    assert_equal "potato", Ingredient.canonicalize("potatoes")
    assert_equal "tomato", Ingredient.canonicalize("tomatoes")
    assert_equal "onion", Ingredient.canonicalize("onions")
  end

  test "canonicalize singularizes words ending in s" do
    assert_equal "carrot", Ingredient.canonicalize("carrots")
    assert_equal "apple", Ingredient.canonicalize("apples")
    assert_equal "pepper", Ingredient.canonicalize("peppers")
  end

  test "canonicalize handles complex potato examples" do
    assert_equal "potato", Ingredient.canonicalize("2 large potatoes, peeled and thinly sliced")
    assert_equal "potato", Ingredient.canonicalize("russet potatoes, peeled")
    assert_equal "potato", Ingredient.canonicalize("small potatoes chopped")
    assert_equal "potato", Ingredient.canonicalize("potato")
  end

  test "canonicalize takes last word as root when multiple words remain" do
    assert_equal "onion", Ingredient.canonicalize("yellow onion")
    assert_equal "cheese", Ingredient.canonicalize("parmesan cheese")
    assert_equal "leafe", Ingredient.canonicalize("fresh basil leaves")
  end

  test "canonicalize handles words that should not be singularized" do
    assert_equal "rice", Ingredient.canonicalize("rice")
    assert_equal "lettuce", Ingredient.canonicalize("lettuce")
    assert_equal "cheese", Ingredient.canonicalize("cheeses")
  end

  test "canonicalize removes measurement units" do
    assert_equal "pasta", Ingredient.canonicalize("200g pasta")
    assert_equal "milk", Ingredient.canonicalize("500ml milk")
    assert_equal "flour", Ingredient.canonicalize("1 kg flour")
    assert_equal "egg", Ingredient.canonicalize("2 eggs")
    assert_equal "cheese", Ingredient.canonicalize("100g parmesan cheese")
  end

  test "normalize_unit converts cups to cup" do
    assert_equal "cup", UnitNormalizer.normalize_unit("cups")
    assert_equal "cup", UnitNormalizer.normalize_unit("Cups")
    assert_equal "cup", UnitNormalizer.normalize_unit("CUP")
  end

  test "normalize_unit converts tablespoons to tbsp" do
    assert_equal "tbsp", UnitNormalizer.normalize_unit("tablespoon")
    assert_equal "tbsp", UnitNormalizer.normalize_unit("tablespoons")
    assert_equal "tbsp", UnitNormalizer.normalize_unit("Tablespoon")
  end

  test "normalize_unit converts teaspoons to tsp" do
    assert_equal "tsp", UnitNormalizer.normalize_unit("teaspoon")
    assert_equal "tsp", UnitNormalizer.normalize_unit("teaspoons")
    assert_equal "tsp", UnitNormalizer.normalize_unit("Teaspoon")
  end

  test "normalize_unit converts pieces to pcs" do
    assert_equal "pcs", UnitNormalizer.normalize_unit("pieces")
    assert_equal "pcs", UnitNormalizer.normalize_unit("piece")
    assert_equal "pcs", UnitNormalizer.normalize_unit("Pieces")
    assert_equal "pcs", UnitNormalizer.normalize_unit("PIECES")
  end

  test "normalize_unit converts pounds to lb" do
    assert_equal "lb", UnitNormalizer.normalize_unit("pound")
    assert_equal "lb", UnitNormalizer.normalize_unit("pounds")
    assert_equal "lb", UnitNormalizer.normalize_unit("Pound")
    assert_equal "lb", UnitNormalizer.normalize_unit("POUNDS")
  end

  test "normalize_unit converts ounces to oz" do
    assert_equal "oz", UnitNormalizer.normalize_unit("ounce")
    assert_equal "oz", UnitNormalizer.normalize_unit("ounces")
    assert_equal "oz", UnitNormalizer.normalize_unit("Ounce")
    assert_equal "oz", UnitNormalizer.normalize_unit("OUNCES")
  end

  test "normalize_unit does not recognize fluid ounces" do
    assert_nil UnitNormalizer.normalize_unit("fluid ounce")
    assert_nil UnitNormalizer.normalize_unit("fluid ounces")
    assert_nil UnitNormalizer.normalize_unit("Fluid Ounce")
    assert_nil UnitNormalizer.normalize_unit("fl oz")
  end

  test "normalize_unit returns nil for invalid units" do
    assert_nil UnitNormalizer.normalize_unit("invalid")
    assert_nil UnitNormalizer.normalize_unit("")
  end

  test "normalize_unit returns unit as-is if already normalized" do
    assert_equal "cup", UnitNormalizer.normalize_unit("cup")
    assert_equal "tbsp", UnitNormalizer.normalize_unit("tbsp")
    assert_equal "tsp", UnitNormalizer.normalize_unit("tsp")
    assert_equal "g", UnitNormalizer.normalize_unit("g")
    assert_equal "kg", UnitNormalizer.normalize_unit("kg")
    assert_equal "pcs", UnitNormalizer.normalize_unit("pcs")
    assert_equal "oz", UnitNormalizer.normalize_unit("oz")
    assert_equal "lb", UnitNormalizer.normalize_unit("lb")
  end

  # Tests for model validations
  test "should be valid with name and canonical_name" do
    ingredient = Ingredient.new(name: "Yellow Onion", canonical_name: "yellow onion")
    assert ingredient.valid?
  end

  test "should require canonical_name" do
    ingredient = Ingredient.new(name: "Yellow Onion")
    assert_not ingredient.valid?
    assert_includes ingredient.errors[:canonical_name], I18n.t("errors.messages.blank")
  end

  test "should have unique canonical_name" do
    Ingredient.create!(name: "Yellow Onion", canonical_name: "yellow onion")
    duplicate = Ingredient.new(name: "Onion", canonical_name: "yellow onion")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:canonical_name], I18n.t("errors.messages.taken")
  end

  # Tests for associations
  test "should have many recipe_ingredients" do
    ingredient = Ingredient.create!(name: "Onion", canonical_name: "onion")
    assert_respond_to ingredient, :recipe_ingredients
  end

  test "should have many recipes through recipe_ingredients" do
    ingredient = Ingredient.create!(name: "Onion", canonical_name: "onion")
    assert_respond_to ingredient, :recipes
  end

  test "should have many pantry_items" do
    ingredient = Ingredient.create!(name: "Onion", canonical_name: "onion")
    assert_respond_to ingredient, :pantry_items
  end
end
