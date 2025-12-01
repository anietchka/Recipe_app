class User < ApplicationRecord
  has_many :pantry_items, dependent: :destroy

  validates :email, presence: true, uniqueness: true
end
