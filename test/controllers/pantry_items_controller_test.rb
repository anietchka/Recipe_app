require "test_helper"

class PantryItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.find_or_create_by!(email: "demo@example.com")
    @ingredient = Ingredient.create!(name: "Pasta", canonical_name: "pasta")
    @pantry_item = PantryItem.create!(
      user: @user,
      ingredient: @ingredient,
      quantity: 500.0,
      unit: "g"
    )
  end

  test "should get index" do
    get pantry_items_url
    assert_response :success
  end

  test "index header points to Recipes, in singular and plural" do
    get pantry_items_url
    assert_select ".pantry-header-text", text: "You have 1 ingredient in your pantry. Go to Recipes to see what you can cook."

    PantryItem.create!(user: @user, ingredient: Ingredient.create!(name: "Rice", canonical_name: "rice"))

    get pantry_items_url
    assert_select ".pantry-header-text", text: "You have 2 ingredients in your pantry. Go to Recipes to see what you can cook."
  end

  test "index lists pantry ingredients alphabetically, ignoring case" do
    %w[cherry Apple banana].each do |name|
      ingredient = Ingredient.create!(name: name, canonical_name: name.downcase)
      PantryItem.create!(user: @user, ingredient: ingredient)
    end

    get pantry_items_url

    assert_equal %w[Apple banana cherry Pasta], css_select(".pantry-card-title").map { |title| title.text.strip }
  end

  test "should create pantry_item" do
    assert_difference("PantryItem.count") do
      post pantry_items_url, params: {
        pantry_item: {
          ingredient_name: "Eggs",
          quantity: 10.0,
          unit: "pcs"
        }
      }
    end

    assert_redirected_to pantry_items_url
    assert_equal "egg", PantryItem.last.ingredient.canonical_name
  end

  test "should create ingredient if it doesn't exist" do
    assert_difference([ "PantryItem.count", "Ingredient.count" ]) do
      post pantry_items_url, params: {
        pantry_item: {
          ingredient_name: "New Ingredient",
          quantity: 5.0,
          unit: "g"
        }
      }
    end

    assert_redirected_to pantry_items_url
    # Note: new canonicalize takes last word as root, so "New Ingredient" -> "ingredient"
    ingredient = Ingredient.find_by(canonical_name: "ingredient")
    assert_not_nil ingredient
    assert_equal "New Ingredient", ingredient.name
  end

  test "should destroy pantry_item" do
    assert_difference("PantryItem.count", -1) do
      delete pantry_item_url(@pantry_item)
    end

    assert_redirected_to pantry_items_url
  end

  test "should handle invalid pantry_item creation" do
    assert_no_difference("PantryItem.count") do
      post pantry_items_url, params: {
        pantry_item: {
          ingredient_name: "",
          quantity: 10.0
        }
      }
    end

    assert_response :unprocessable_entity
  end
end
