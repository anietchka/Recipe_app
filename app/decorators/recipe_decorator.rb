class RecipeDecorator < SimpleDelegator
  def initialize(recipe)
    super(recipe)
    @recipe = recipe
  end

  def total_ingredients_count
    recipe.instance_variable_get(:@total_ingredients_count) || recipe.recipe_ingredients.count
  end

  def matched_ingredients
    recipe.instance_variable_get(:@matched_ingredients_count) || 0
  end

  def missing_count
    recipe.instance_variable_get(:@missing_ingredients_count) || (total_ingredients_count - matched_ingredients)
  end

  def completion_percentage
    return 0 if total_ingredients_count.zero?

    (matched_ingredients.to_f / total_ingredients_count * 100).round
  end

  def status_class
    if missing_count == 0
      "recipe-status--ready"
    elsif missing_count <= 3
      "recipe-status--almost"
    else
      "recipe-status--shopping"
    end
  end

  def status_text
    if missing_count == 0
      I18n.t("recipes.index.status_ready")
    elsif missing_count <= 3
      I18n.t("recipes.index.status_almost")
    else
      I18n.t("recipes.index.status_shopping")
    end
  end

  private

  attr_reader :recipe
end
