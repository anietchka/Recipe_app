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

  desc "Download recipes-en.json from S3"
  task download: :environment do
    file_path = Rails.root.join("db", "data", "recipes-en.json")
    gz_path = Rails.root.join("db", "data", "recipes-en.json.gz")
    url = "https://pennylane-interviewing-assets-20220328.s3.eu-west-1.amazonaws.com/recipes-en.json.gz"

    # Create directory if it doesn't exist
    FileUtils.mkdir_p(File.dirname(file_path))

    puts "Downloading recipes-en.json from S3..."
    puts "URL: #{url}"

    begin
      # Download the gzipped file
      require "open-uri"
      require "zlib"

      URI.open(url) do |remote_file|
        File.open(gz_path, "wb") do |local_file|
          local_file.write(remote_file.read)
        end
      end

      puts "✓ Download completed"

      # Decompress the file
      puts "Decompressing file..."
      Zlib::GzipReader.open(gz_path) do |gz|
        File.open(file_path, "wb") do |out|
          out.write(gz.read)
        end
      end

      # Remove the gzipped file
      FileUtils.rm_f(gz_path)

      size = File.size(file_path)
      size_mb = (size / 1024.0 / 1024.0).round(2)
      puts "✓ File ready: #{file_path}"
      puts "  Size: #{size_mb} MB"
    rescue OpenURI::HTTPError => e
      puts "✗ Download failed: HTTP error #{e.message}"
      raise
    rescue Zlib::GzipFile::Error => e
      puts "✗ Decompression failed: #{e.message}"
      raise
    rescue StandardError => e
      puts "✗ Download failed: #{e.message}"
      raise
    end
  end

  desc "Delete all recipes, recipe ingredients, and unused ingredients"
  task clean: :environment do
    puts "Cleaning recipes and ingredients..."

    recipe_count = Recipe.count
    ingredient_count = Ingredient.count
    recipe_ingredient_count = RecipeIngredient.count

    # Delete in correct order due to foreign keys
    RecipeIngredient.delete_all
    Recipe.delete_all

    # Only delete ingredients that are not used in pantry_items
    # Ingredients used in pantry_items should be kept
    unused_ingredients = Ingredient.left_joins(:pantry_items)
                                   .where(pantry_items: { id: nil })
    unused_count = unused_ingredients.count
    unused_ingredients.delete_all

    puts "✓ Cleanup completed!"
    puts "  - Recipes deleted: #{recipe_count}"
    puts "  - Recipe ingredients deleted: #{recipe_ingredient_count}"
    puts "  - Unused ingredients deleted: #{unused_count}"
    puts "  - Ingredients kept (used in pantry): #{ingredient_count - unused_count}"
  end

  desc "Check if recipes-en.json exists and is accessible"
  task check_file: :environment do
    file_path = Rails.root.join("db", "data", "recipes-en.json")

    if File.exist?(file_path)
      size = File.size(file_path)
      size_mb = (size / 1024.0 / 1024.0).round(2)
      puts "✓ File exists: #{file_path}"
      puts "  Size: #{size_mb} MB"

      # Quick validation: check if it starts with JSON structure
      begin
        first_chars = File.read(file_path, 100)
        if first_chars.strip.start_with?("[", "{")
          puts "  ✓ File appears to be valid JSON"
        else
          puts "  ⚠️  File exists but may not be valid JSON (doesn't start with [ or {)"
        end
      rescue StandardError => e
        puts "  ⚠️  Could not validate file: #{e.message}"
      end
    else
      puts "✗ File not found: #{file_path}"
      puts "  Run 'rails recipes:download' to download it from S3"
    end
  end
end
