require "test_helper"

class CookedRecipeTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "demo@example.com")
    @recipe = Recipe.create!(title: "Pasta Carbonara")
  end

  test "should be valid with user and recipe" do
    cooked_recipe = CookedRecipe.new(
      user: @user,
      recipe: @recipe
    )
    assert cooked_recipe.valid?
  end

  test "should require user" do
    cooked_recipe = CookedRecipe.new(recipe: @recipe)
    assert_not cooked_recipe.valid?
    assert_includes cooked_recipe.errors[:user], I18n.t("errors.messages.required")
  end

  test "should require recipe" do
    cooked_recipe = CookedRecipe.new(user: @user)
    assert_not cooked_recipe.valid?
    assert_includes cooked_recipe.errors[:recipe], I18n.t("errors.messages.required")
  end

  test "should set cooked_at to current time by default" do
    before_time = Time.current
    cooked_recipe = CookedRecipe.create!(
      user: @user,
      recipe: @recipe
    )
    after_time = Time.current

    assert_not_nil cooked_recipe.cooked_at
    assert cooked_recipe.cooked_at >= before_time
    assert cooked_recipe.cooked_at <= after_time
  end

  test "should allow setting cooked_at explicitly" do
    custom_time = 1.day.ago
    cooked_recipe = CookedRecipe.create!(
      user: @user,
      recipe: @recipe,
      cooked_at: custom_time
    )

    assert_equal custom_time.to_i, cooked_recipe.cooked_at.to_i
  end

  test "should belong to user" do
    cooked_recipe = CookedRecipe.create!(
      user: @user,
      recipe: @recipe
    )
    assert_equal @user, cooked_recipe.user
  end

  test "should belong to recipe" do
    cooked_recipe = CookedRecipe.create!(
      user: @user,
      recipe: @recipe
    )
    assert_equal @recipe, cooked_recipe.recipe
  end
end
