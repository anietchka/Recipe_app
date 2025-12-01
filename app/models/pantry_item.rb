class PantryItem < ApplicationRecord
  belongs_to :user
  belongs_to :ingredient

  validates :user, presence: true
  validates :ingredient, presence: true
  validates :quantity, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :ingredient_id, uniqueness: { scope: :user_id }

  validate :quantity_or_fraction_required

  private

  def quantity_or_fraction_required
    return if quantity.present? || fraction.present?

    errors.add(:base, :quantity_or_fraction_required)
  end
end
