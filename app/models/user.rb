class User < ApplicationRecord
  has_many :pantry_items, dependent: :destroy
  has_many :cooked_recipes, dependent: :destroy

  validates :email, presence: true, uniqueness: true
end
