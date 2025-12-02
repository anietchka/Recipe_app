class UpdateRecipesTable < ActiveRecord::Migration[8.1]
  def change
    # Remove old columns
    remove_column :recipes, :description, :text
    remove_column :recipes, :instructions, :text
    remove_column :recipes, :source_url, :string
    remove_column :recipes, :rating, :decimal
    remove_column :recipes, :ratings_count, :integer
    remove_column :recipes, :total_time_minutes, :integer

    # Add new columns
    add_column :recipes, :cook_time, :integer
    add_column :recipes, :prep_time, :integer
    add_column :recipes, :category, :string
    add_column :recipes, :ratings, :decimal
  end
end
