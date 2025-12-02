require "test_helper"
require "rake"

class RecipesRakeTest < ActiveSupport::TestCase
  def setup
    Rake.application.rake_require "tasks/recipes"
    Rake::Task.define_task(:environment)
    Rake::Task["recipes:import"].reenable
  end

  def teardown
    RecipeIngredient.delete_all
    Recipe.delete_all
    Ingredient.delete_all
  end

  test "imports recipes from default file path" do
    fixture_path = Rails.root.join("test", "fixtures", "files", "recipes_minimal.json")

    # Create a temporary JSON file for testing
    temp_file = Tempfile.new([ "recipes", ".json" ])
    temp_file.write(File.read(fixture_path))
    temp_file.close

    # Mock the default file path
    default_path = Rails.root.join("db", "data", "recipes-en.json")
    FileUtils.mkdir_p(default_path.dirname) unless default_path.dirname.exist?
    FileUtils.cp(temp_file.path, default_path)

    assert_difference -> { Recipe.count }, 3 do
      assert_difference -> { Ingredient.count }, 10 do
        assert_difference -> { RecipeIngredient.count }, 11 do
          Rake::Task["recipes:import"].invoke
        end
      end
    end

    FileUtils.rm_f(default_path)
    temp_file.unlink
  end

  test "imports recipes from custom file path" do
    fixture_path = Rails.root.join("test", "fixtures", "files", "recipes_minimal.json")

    assert_difference -> { Recipe.count }, 3 do
      assert_difference -> { Ingredient.count }, 10 do
        assert_difference -> { RecipeIngredient.count }, 11 do
          Rake::Task["recipes:import"].invoke(fixture_path.to_s)
        end
      end
    end
  end

  test "handles missing file gracefully" do
    non_existent_path = Rails.root.join("tmp", "non_existent.json")

    assert_raises(Errno::ENOENT) do
      Rake::Task["recipes:import"].invoke(non_existent_path.to_s)
    end
  end

  test "handles invalid JSON gracefully" do
    invalid_json_file = Tempfile.new([ "invalid", ".json" ])
    invalid_json_file.write("{ invalid json }")
    invalid_json_file.close

    assert_raises(JSON::ParserError) do
      Rake::Task["recipes:import"].invoke(invalid_json_file.path)
    end

    invalid_json_file.unlink
  end
end
