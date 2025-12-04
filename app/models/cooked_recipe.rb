class CookedRecipe < ApplicationRecord
  belongs_to :user
  belongs_to :recipe

  validates :user, presence: true
  validates :recipe, presence: true

  before_create :set_cooked_at_default, if: -> { cooked_at.nil? }

  private

  def set_cooked_at_default
    self.cooked_at = Time.current
  end
end
