class RecipeIngredient < ApplicationRecord
  belongs_to :recipe
  belongs_to :ingredient

  validates :recipe, presence: true
  validates :ingredient, presence: true
  validates :unit, inclusion: { in: Ingredient::MEASUREMENT_UNITS }, allow_nil: true

  # Returns the total required quantity for this recipe ingredient
  # Combines quantity and fraction, defaulting to 1.0 if both are nil/blank
  def required_quantity
    total = calculate_total_quantity(quantity, fraction)

    # Default to 1.0 if no quantity specified
    total.zero? && quantity.nil? && fraction.blank? ? 1.0 : total
  end

  private

  # Calculates total quantity from quantity and fraction
  # Converts fraction to decimal and adds to quantity
  def calculate_total_quantity(qty, frac)
    total = qty.to_f

    return total if frac.blank?

    fraction_value = parse_fraction(frac)
    total += fraction_value if fraction_value

    total
  end

  # Parses a fraction string (e.g., "1/2", "3/4") and returns decimal value
  def parse_fraction(fraction_string)
    return nil if fraction_string.blank?

    parts = fraction_string.split("/")
    return nil unless parts.length == 2

    numerator = parts[0].to_f
    denominator = parts[1].to_f

    return nil if denominator.zero?

    numerator / denominator
  end
end
