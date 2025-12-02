class PantryItem < ApplicationRecord
  belongs_to :user
  belongs_to :ingredient

  validates :user, presence: true
  validates :ingredient, presence: true
  validates :quantity, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :ingredient_id, uniqueness: { scope: :user_id }
  validates :unit, inclusion: { in: Ingredient::MEASUREMENT_UNITS }, allow_nil: true

  validate :quantity_or_fraction_required

  # Returns the total available quantity for this pantry item
  # Combines quantity and fraction into a single decimal value
  def available_quantity
    calculate_total_quantity(quantity, fraction)
  end

  private

  def quantity_or_fraction_required
    return if quantity.present? || fraction.present?

    errors.add(:base, :quantity_or_fraction_required)
  end

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
