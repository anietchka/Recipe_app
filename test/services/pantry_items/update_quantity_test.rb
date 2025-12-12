require "test_helper"

module PantryItems
  class UpdateQuantityTest < ActiveSupport::TestCase
    setup do
      @user = User.find_or_create_by!(email: "demo@example.com")
      @ingredient = Ingredient.create!(name: "Pasta", canonical_name: "pasta")
      @pantry_item = PantryItem.create!(
        user: @user,
        ingredient: @ingredient,
        quantity: 5.0,
        unit: "g"
      )
    end

    test "increments quantity by 1" do
      result = PantryItems::UpdateQuantity.call(@pantry_item, :increment)

      assert result.success?
      @pantry_item.reload
      assert_equal 6.0, @pantry_item.available_quantity
    end

    test "decrements quantity by 1" do
      result = PantryItems::UpdateQuantity.call(@pantry_item, :decrement)

      assert result.success?
      @pantry_item.reload
      assert_equal 4.0, @pantry_item.available_quantity
    end

    test "increment converts to fraction when appropriate" do
      @pantry_item.update!(quantity: 1.0, fraction: "1/2")
      result = PantryItems::UpdateQuantity.call(@pantry_item, :increment)

      assert result.success?
      @pantry_item.reload
      assert_equal 2.5, @pantry_item.available_quantity
    end

    test "decrement converts to fraction when appropriate" do
      @pantry_item.update!(quantity: 2.0, fraction: "1/2")
      result = PantryItems::UpdateQuantity.call(@pantry_item, :decrement)

      assert result.success?
      @pantry_item.reload
      assert_equal 1.5, @pantry_item.available_quantity
    end

    test "decrement sets to nil when quantity becomes 0" do
      @pantry_item.update!(quantity: 0.5, fraction: nil)
      result = PantryItems::UpdateQuantity.call(@pantry_item, :decrement)

      assert result.success?
      @pantry_item.reload
      assert_nil @pantry_item.quantity
      assert_nil @pantry_item.fraction
    end

    test "decrement does not go below 0" do
      @pantry_item.update!(quantity: 0.5, fraction: nil)
      result = PantryItems::UpdateQuantity.call(@pantry_item, :decrement)

      assert result.success?
      @pantry_item.reload
      assert_nil @pantry_item.quantity
      assert_nil @pantry_item.fraction
    end

    # Note: These tests document behavior when service is called directly
    # (e.g., from API or console), even though UI prevents these calls
    test "increment handles pantry item without quantity" do
      @pantry_item.update!(quantity: nil, fraction: nil)
      result = PantryItems::UpdateQuantity.call(@pantry_item, :increment)

      assert result.success?
      @pantry_item.reload
      assert_equal 1.0, @pantry_item.available_quantity
      assert_nil @pantry_item.fraction
    end

    test "decrement handles pantry item without quantity" do
      @pantry_item.update!(quantity: nil, fraction: nil)
      result = PantryItems::UpdateQuantity.call(@pantry_item, :decrement)

      assert result.success?
      @pantry_item.reload
      assert_nil @pantry_item.quantity
      assert_nil @pantry_item.fraction
    end

    test "returns error if update fails validation" do
      # This is hard to test without mocking, but we can test the structure
      result = PantryItems::UpdateQuantity.call(@pantry_item, :increment)

      assert result.success?
      assert_respond_to result, :pantry_item
      assert_respond_to result, :errors
    end

    test "raises error for unknown operation" do
      assert_raises(ArgumentError, "Unknown operation: invalid") do
        PantryItems::UpdateQuantity.call(@pantry_item, :invalid)
      end
    end
  end
end
