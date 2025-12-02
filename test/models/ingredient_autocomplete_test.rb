require "test_helper"

class IngredientAutocompleteTest < ActiveSupport::TestCase
  setup do
    # Create test ingredients with various characteristics
    @simple_sugar = Ingredient.create!(
      name: "sugar",
      canonical_name: "sugar"
    )

    @brown_sugar = Ingredient.create!(
      name: "brown sugar",
      canonical_name: "brown sugar"
    )

    @powdered_sugar = Ingredient.create!(
      name: "powdered sugar",
      canonical_name: "powdered sugar"
    )

    @long_complex_name = Ingredient.create!(
      name: "barbeque sauce (such as Sweet Baby Ray's Hickory & Brown Sugar)",
      canonical_name: "barbeque sauce such as sweet baby ray hickory brown sugar"
    )

    @medium_name = Ingredient.create!(
      name: "sugar with vanilla extract and cinnamon",
      canonical_name: "sugar with vanilla extract and cinnamon"
    )

    @starts_with_term = Ingredient.create!(
      name: "sugar cane",
      canonical_name: "sugar cane"
    )

    @contains_such_as = Ingredient.create!(
      name: "sauce such as ketchup",
      canonical_name: "sauce such as ketchup"
    )

    @with_parentheses = Ingredient.create!(
      name: "flour (all-purpose)",
      canonical_name: "flour all purpose"
    )

    @very_long_name = Ingredient.create!(
      name: "a" * 50, # 50 characters
      canonical_name: "a" * 50
    )
  end

  test "returns empty relation for blank term" do
    assert_equal 0, Ingredient.autocomplete("").count
    assert_equal 0, Ingredient.autocomplete("   ").count
    assert_equal 0, Ingredient.autocomplete(nil).count
  end

  test "limits results to specified limit" do
    # Create more than 15 ingredients matching "sugar"
    20.times do |i|
      Ingredient.create!(
        name: "sugar variant #{i}",
        canonical_name: "sugar variant #{i}"
      )
    end

    results = Ingredient.autocomplete("sugar", limit: 15)
    assert_operator results.to_a.length, :<=, 15
  end

  test "filters out names longer than 40 characters" do
    results = Ingredient.autocomplete("a")
    result_names = results.pluck(:name)

    assert_not_includes result_names, @very_long_name.name
  end

  test "does not filter out names containing 'such as'" do
    results = Ingredient.autocomplete("sauce")
    result_names = results.pluck(:name)

    assert_includes result_names, @contains_such_as.name
    # @long_complex_name is still filtered out because it's longer than 40 characters
    assert_not_includes result_names, @long_complex_name.name
  end

  test "filters out names containing parentheses" do
    results = Ingredient.autocomplete("flour")
    result_names = results.pluck(:name)

    assert_not_includes result_names, @with_parentheses.name
  end

  test "prioritizes names that start with the search term" do
    results = Ingredient.autocomplete("sugar")
    result_names = results.pluck(:name)

    # Find positions
    starts_with_index = result_names.index(@starts_with_term.name)
    contains_index = result_names.index(@medium_name.name)

    # Names starting with "sugar" should come before names containing it
    assert_not_nil starts_with_index
    assert_not_nil contains_index
    assert starts_with_index < contains_index, "Names starting with term should come first"
  end

  test "sorts by length within same relevance group" do
    results = Ingredient.autocomplete("sugar")
    result_names = results.pluck(:name)

    # Among names starting with "sugar", shorter ones should come first
    sugar_index = result_names.index(@simple_sugar.name)
    sugar_cane_index = result_names.index(@starts_with_term.name)

    assert_not_nil sugar_index
    assert_not_nil sugar_cane_index
    assert sugar_index < sugar_cane_index, "Shorter names should come first"
  end

  test "sorts alphabetically when lengths are equal" do
    # Create ingredients with same length but different names
    ingredient_a = Ingredient.create!(
      name: "sugar apple",
      canonical_name: "sugar apple"
    )

    ingredient_b = Ingredient.create!(
      name: "sugar berry",
      canonical_name: "sugar berry"
    )

    results = Ingredient.autocomplete("sugar")
    result_names = results.pluck(:name)

    apple_index = result_names.index(ingredient_a.name)
    berry_index = result_names.index(ingredient_b.name)

    assert_not_nil apple_index
    assert_not_nil berry_index
    assert apple_index < berry_index, "Should sort alphabetically when lengths are equal"
  end

  test "searches in both name and canonical_name" do
    # Create ingredient where canonical_name matches but name doesn't start with term
    # Use a unique canonical_name to avoid conflicts
    ingredient = Ingredient.create!(
      name: "granulated sweetener",
      canonical_name: "sugar sweetener"
    )

    results = Ingredient.autocomplete("sugar")
    result_names = results.pluck(:name)

    assert_includes result_names, ingredient.name
  end

  test "case-insensitive search" do
    results_upper = Ingredient.autocomplete("SUGAR")
    results_lower = Ingredient.autocomplete("sugar")
    results_mixed = Ingredient.autocomplete("SuGaR")

    assert_equal results_upper.pluck(:id).sort, results_lower.pluck(:id).sort
    assert_equal results_lower.pluck(:id).sort, results_mixed.pluck(:id).sort
  end

  test "returns simple relevant results for 'sugar' search" do
    results = Ingredient.autocomplete("sugar")
    result_names = results.pluck(:name)

    # Should include simple, relevant results
    assert_includes result_names, @simple_sugar.name
    assert_includes result_names, @brown_sugar.name
    assert_includes result_names, @powdered_sugar.name
    assert_includes result_names, @starts_with_term.name

    # Should NOT include overly complex names
    assert_not_includes result_names, @long_complex_name.name
  end

  test "default limit is 15" do
    # Create 20 ingredients
    20.times do |i|
      Ingredient.create!(
        name: "test ingredient #{i}",
        canonical_name: "test ingredient #{i}"
      )
    end

    results = Ingredient.autocomplete("test")
    assert_operator results.to_a.length, :<=, 15
  end
end
