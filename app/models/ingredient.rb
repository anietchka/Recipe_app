class Ingredient < ApplicationRecord
  has_many :recipe_ingredients, dependent: :destroy
  has_many :recipes, through: :recipe_ingredients
  has_many :pantry_items, dependent: :destroy

  validates :canonical_name, presence: true, uniqueness: true

  # Canonicalize a string to a normalized form
  # - converts to lowercase
  # - removes non-alphabetic characters (replaces with space)
  # - compresses spaces
  # - trims whitespace
  def self.canonicalize(string)
    return nil if string.nil?

    string.to_s
          .downcase
          .gsub(/[^a-z\s]/, " ") # Replace non-alphabetic characters with space
          .gsub(/\s+/, " ")       # Compress multiple spaces to single space
          .strip                 # Trim whitespace
  end
end
