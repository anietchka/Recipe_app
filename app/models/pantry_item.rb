class PantryItem < ApplicationRecord
  include UnitConverter

  belongs_to :user
  belongs_to :ingredient

  validates :user, presence: true
  validates :ingredient, presence: true
  validates :quantity, numericality: { greater_than: 0 }, allow_nil: true
  validates :ingredient_id, uniqueness: { scope: :user_id }
  validates :unit, inclusion: { in: Ingredient::MEASUREMENT_UNITS }, allow_nil: true

  # Returns the total available quantity for this pantry item
  # Combines quantity and fraction into a single decimal value
  def available_quantity
    calculate_total_quantity(quantity, fraction)
  end

  # Check if pantry item has no quantity specified (both quantity and fraction are nil/blank)
  def without_quantity?
    quantity.nil? && fraction.blank?
  end

  # Check if this pantry item has insufficient quantity compared to a recipe ingredient requirement
  def insufficient_quantity?(recipe_ingredient)
    # If no units specified, compare directly
    if unit.nil? && recipe_ingredient.unit.nil?
      return recipe_ingredient.required_quantity > available_quantity
    end

    # If one has unit and other doesn't, treat as insufficient (can't compare)
    return true if unit.nil? || recipe_ingredient.unit.nil?

    # If units are incompatible, treat as insufficient
    return true unless units_compatible?(unit, recipe_ingredient.unit)

    # Convert pantry quantity to recipe unit for comparison
    available_in_recipe_unit = convert_quantity(
      available_quantity,
      unit,
      recipe_ingredient.unit
    )

    return true unless available_in_recipe_unit

    recipe_ingredient.required_quantity > available_in_recipe_unit
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
