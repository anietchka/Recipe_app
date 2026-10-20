module PantryItems
  class UpdateQuantity
    def self.call(pantry_item, operation)
      new(pantry_item, operation).call
    end

    def initialize(pantry_item, operation)
      @pantry_item = pantry_item
      @operation = operation
      @errors = {}
    end

    def call
      # Untracked pantry items (quantity: nil) have no quantity to change
      return build_success_result if @pantry_item.quantity.nil?

      new_quantity = calculate_new_quantity

      # A tracked quantity reaching zero means the stock is exhausted: remove the item
      saved =
        if new_quantity <= 0
          @pantry_item.destroy
        else
          @pantry_item.update(quantity: new_quantity)
        end

      saved ? build_success_result : build_error_result
    end

    private

    attr_reader :pantry_item, :operation, :errors

    def calculate_new_quantity
      case @operation
      when :increment
        @pantry_item.quantity + 1
      when :decrement
        @pantry_item.quantity - 1
      else
        raise ArgumentError, "Unknown operation: #{@operation}"
      end
    end

    def build_success_result
      Result.new(success: true, pantry_item: @pantry_item, errors: {})
    end

    def build_error_result
      item_errors = @pantry_item.errors.to_hash || {}
      all_errors = errors.merge(item_errors)

      Result.new(success: false, pantry_item: @pantry_item, errors: all_errors)
    end

    # Simple result object
    class Result
      attr_reader :pantry_item, :errors

      def initialize(success:, pantry_item:, errors:)
        @success = success
        @pantry_item = pantry_item
        @errors = errors
      end

      def success?
        @success
      end
    end
  end
end
