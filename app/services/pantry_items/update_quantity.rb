module PantryItems
  class UpdateQuantity
    include FractionConverter

    def self.call(pantry_item, operation)
      new(pantry_item, operation).call
    end

    def initialize(pantry_item, operation)
      @pantry_item = pantry_item
      @operation = operation
      @errors = {}
    end

    def call
      new_quantity_total = calculate_new_quantity_total
      quantity, fraction = convert_to_quantity_and_fraction(new_quantity_total)

      # Handle special cases based on operation
      quantity, fraction = handle_special_cases(quantity, fraction)

      if @pantry_item.update(quantity: quantity, fraction: fraction)
        build_success_result
      else
        build_error_result
      end
    end

    private

    attr_reader :pantry_item, :operation, :errors

    def calculate_new_quantity_total
      current_quantity = @pantry_item.available_quantity

      case @operation
      when :increment
        current_quantity + 1.0
      when :decrement
        [ current_quantity - 1.0, 0.0 ].max
      else
        raise ArgumentError, "Unknown operation: #{@operation}"
      end
    end

    def convert_to_quantity_and_fraction(decimal)
      return [ 0.0, nil ] if decimal.zero?

      whole = decimal.to_i
      decimal_part = decimal - whole

      return [ whole, nil ] if decimal_part.zero?

      # Try to convert decimal part to common fractions
      fraction = convert_decimal_to_fraction(decimal_part)
      return [ whole, fraction ] if fraction

      # If no common fraction matches, store as decimal in quantity
      [ decimal, nil ]
    end

    def handle_special_cases(quantity, fraction)
      case @operation
      when :increment
        # For increment, we should always have a quantity > 0
        # If quantity is 0.0 or nil, set to 1.0
        if (quantity.nil? || quantity == 0.0) && fraction.nil?
          [ 1.0, nil ]
        else
          [ quantity, fraction ]
        end
      when :decrement
        # If quantity becomes 0, set both to nil (base ingredient)
        if (quantity.nil? || quantity == 0.0) && fraction.nil?
          [ nil, nil ]
        else
          [ quantity, fraction ]
        end
      else
        [ quantity, fraction ]
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
