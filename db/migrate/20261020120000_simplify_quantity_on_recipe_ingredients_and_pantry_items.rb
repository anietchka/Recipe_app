class SimplifyQuantityOnRecipeIngredientsAndPantryItems < ActiveRecord::Migration[8.1]
  TABLES = %i[recipe_ingredients pantry_items].freeze

  def up
    TABLES.each do |table|
      execute <<~SQL
        UPDATE #{table}
        SET quantity = COALESCE(quantity, 0)
          + split_part(fraction, '/', 1)::float / NULLIF(split_part(fraction, '/', 2)::float, 0)
        WHERE fraction ~ '^\\d+/\\d+$'
      SQL

      remove_column table, :fraction, :string
      change_column table, :quantity, :decimal, precision: 10, scale: 3
    end
  end

  def down
    TABLES.each do |table|
      change_column table, :quantity, :float
      add_column table, :fraction, :string
    end
  end
end
