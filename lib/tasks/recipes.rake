namespace :recipes do
  desc "Import recipes from JSON file (default: db/data/recipes-en.json)"
  task :import, [ :file_path ] => :environment do |_t, args|
    file_path = args[:file_path]

    if file_path
      file_path = Rails.root.join(file_path) unless Pathname.new(file_path).absolute?
    end

    default_path = Rails.root.join("db", "data", "recipes-en.json")
    puts "Starting recipe import..."
    puts "File: #{file_path || default_path}"

    begin
      Recipes::ImportFromJson.call(file_path)
      puts "✓ Recipe import completed successfully!"
      puts "  - Recipes created: #{Recipe.count}"
      puts "  - Ingredients created: #{Ingredient.count}"
      puts "  - Recipe ingredients created: #{RecipeIngredient.count}"
    rescue StandardError => e
      puts "✗ Recipe import failed: #{e.message}"
      puts e.backtrace.first(5).join("\n")
      raise
    end
  end
end
