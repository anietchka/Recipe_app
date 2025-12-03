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

  test "imports recipes from custom file path" do
    fixture_path = Rails.root.join("test", "fixtures", "files", "recipes_minimal.json")

    assert_difference -> { Recipe.count }, 5 do
      # Note: With improved canonicalize, some ingredients are merged (e.g., "eggs" -> "egg", "tomatoes" -> "tomato", "potatoes" -> "potato")
      assert_difference -> { Ingredient.count }, 15 do
        assert_difference -> { RecipeIngredient.count }, 21 do
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
