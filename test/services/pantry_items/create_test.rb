require "test_helper"

module PantryItems
  class CreateTest < ActiveSupport::TestCase
    setup do
      @user = User.find_or_create_by!(email: "demo@example.com")
      @ingredient_name = "Eggs"
      @params = {
        ingredient_name: @ingredient_name,
        quantity: 10.0,
        unit: "pcs"
      }
    end

    test "creates pantry item with new ingredient" do
      assert_difference([ "PantryItem.count", "Ingredient.count" ]) do
        result = PantryItems::Create.call(@user, @params)

        assert result.success?
        assert_not_nil result.pantry_item
        assert_equal @ingredient_name, result.pantry_item.ingredient.name
        assert_equal 10.0, result.pantry_item.quantity
        assert_equal "pcs", result.pantry_item.unit
      end
    end

    test "creates pantry item with existing ingredient" do
      existing_ingredient = Ingredient.create!(name: "Eggs", canonical_name: "eggs")

      assert_difference("PantryItem.count") do
        assert_no_difference("Ingredient.count") do
          result = PantryItems::Create.call(@user, @params)

          assert result.success?
          assert_equal existing_ingredient.id, result.pantry_item.ingredient_id
        end
      end
    end

    test "updates ingredient name if capitalization is better" do
      existing_ingredient = Ingredient.create!(name: "eggs", canonical_name: "eggs")

      result = PantryItems::Create.call(@user, @params)

      assert result.success?
      existing_ingredient.reload
      assert_equal "Eggs", existing_ingredient.name
    end

    test "returns error if ingredient name is blank" do
      params = @params.merge(ingredient_name: "")

      assert_no_difference([ "PantryItem.count", "Ingredient.count" ]) do
        result = PantryItems::Create.call(@user, params)

        assert_not result.success?
        assert_nil result.pantry_item
        assert_includes result.errors, :ingredient
      end
    end

    test "returns error if ingredient name cannot be canonicalized" do
      params = @params.merge(ingredient_name: "123")

      assert_no_difference([ "PantryItem.count", "Ingredient.count" ]) do
        result = PantryItems::Create.call(@user, params)

        assert_not result.success?
        assert_nil result.pantry_item
        assert_includes result.errors, :ingredient
      end
    end

    test "returns error if pantry item validation fails" do
      params = @params.merge(quantity: -1.0)

      assert_no_difference("PantryItem.count") do
        result = PantryItems::Create.call(@user, params)

        assert_not result.success?
        assert_not_nil result.pantry_item
        assert result.pantry_item.errors.any?
      end
    end

    test "handles fraction in params" do
      params = @params.merge(quantity: 1.0, fraction: "1/2")

      result = PantryItems::Create.call(@user, params)

      assert result.success?
      assert_equal "1/2", result.pantry_item.fraction
    end
  end
end
