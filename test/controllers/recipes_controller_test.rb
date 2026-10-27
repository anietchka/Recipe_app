require "test_helper"

class RecipesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.find_or_create_by!(email: "demo@example.com")

    # Create ingredients
    @pasta = Ingredient.create!(name: "Pasta", canonical_name: "pasta")
    @eggs = Ingredient.create!(name: "Eggs", canonical_name: "egg")
    @cheese = Ingredient.create!(name: "Cheese", canonical_name: "cheese")

    # Create recipe
    @recipe = Recipe.create!(
      title: "Pasta Carbonara",
      cook_time: 20,
      prep_time: 10,
      image_url: "https://example.com/pasta.jpg",
      category: "Italian",
      ratings: 4.5
    )

    RecipeIngredient.create!(recipe: @recipe, ingredient: @pasta, original_text: "200g pasta", quantity: 200.0, unit: "g")
    RecipeIngredient.create!(recipe: @recipe, ingredient: @eggs, original_text: "2 eggs", quantity: 2.0, unit: "pcs")
    RecipeIngredient.create!(recipe: @recipe, ingredient: @cheese, original_text: "100g cheese", quantity: 100.0, unit: "g")

    # Add some ingredients to user's pantry
    PantryItem.create!(user: @user, ingredient: @pasta, quantity: 500.0, unit: "g")
    PantryItem.create!(user: @user, ingredient: @eggs, quantity: 6.0, unit: "pcs")
  end

  test "should get index" do
    get recipes_url
    assert_response :success
  end

  test "index should display recipes found by Finder service" do
    PantryItem.create!(user: @user, ingredient: @cheese, quantity: 200.0, unit: "g")

    get recipes_url
    assert_response :success
    assert_select ".recipe-card", minimum: 1
  end

  test "index should show recipe score information" do
    PantryItem.create!(user: @user, ingredient: @cheese, quantity: 200.0, unit: "g")

    get recipes_url
    assert_response :success
    assert_select ".recipe-card__score"
  end

  # Maximum missing ingredients filter

  def create_recipe_missing(count, title)
    recipe = Recipe.create!(title: title)
    count.times do |i|
      ingredient = Ingredient.create!(name: "#{title} #{i}", canonical_name: "#{title.parameterize}-#{i}")
      RecipeIngredient.create!(recipe: recipe, ingredient: ingredient, original_text: ingredient.name)
    end
    recipe
  end

  def card_titles
    css_select(".recipe-card__title").map { |title| title.text.strip }
  end

  def selected_max_missing
    css_select("select[name=max_missing] option[selected]").map { |option| option.text.strip }
  end

  test "index limits recipes to 0 missing ingredients by default" do
    complete = Recipe.create!(title: "Plain Pasta")
    RecipeIngredient.create!(recipe: complete, ingredient: @pasta, original_text: "200g pasta", quantity: 200, unit: "g")
    create_recipe_missing(3, "Three Missing")

    get recipes_url

    assert_includes card_titles, "Plain Pasta"
    assert_not_includes card_titles, @recipe.title # 1 missing (cheese)
    assert_not_includes card_titles, "Three Missing"
    assert_equal [ "0" ], selected_max_missing
  end

  test "index explains the empty state without implying an empty pantry" do
    get recipes_url # the only recipe is missing cheese

    assert_empty card_titles
    assert_select ".empty-state p", text: I18n.t("recipes.index.no_recipes")
  end

  test "index with max_missing=any shows every recipe" do
    create_recipe_missing(3, "Three Missing")

    get recipes_url(max_missing: "any")

    assert_includes card_titles, "Three Missing"
    assert_equal [ "Any" ], selected_max_missing
  end

  test "index with max_missing=0 shows only fully makeable recipes" do
    complete = Recipe.create!(title: "Plain Pasta")
    RecipeIngredient.create!(recipe: complete, ingredient: @pasta, original_text: "200g pasta", quantity: 200, unit: "g")

    get recipes_url(max_missing: "0")

    assert_equal [ "Plain Pasta" ], card_titles
    assert_equal [ "0" ], selected_max_missing
  end

  test "index falls back to the default for an invalid max_missing" do
    create_recipe_missing(3, "Three Missing")

    get recipes_url(max_missing: "abc")

    assert_response :success
    assert_not_includes card_titles, @recipe.title # 1 missing (cheese)
    assert_not_includes card_titles, "Three Missing"
    assert_equal [ "0" ], selected_max_missing
  end

  test "pagination links keep the current filters" do
    21.times do |i|
      recipe = Recipe.create!(title: "Quick #{i}", prep_time: 10)
      RecipeIngredient.create!(recipe: recipe, ingredient: @pasta, original_text: "pasta")
    end

    get recipes_url(max_missing: "any", max_prep_time: "30")

    next_link = css_select(".pagination a").find { |link| link.text.strip == I18n.t("recipes.index.next_page") }
    query = Rack::Utils.parse_query(URI.parse(next_link["href"]).query)
    assert_equal({ "max_missing" => "any", "max_prep_time" => "30", "page" => "2" }, query)
  end

  # Result count and pagination

  def create_cookable_recipes(count)
    count.times do |i|
      recipe = Recipe.create!(title: "Cookable #{i}")
      RecipeIngredient.create!(recipe: recipe, ingredient: @pasta, original_text: "pasta")
    end
  end

  def next_page_link
    css_select(".pagination a").find { |link| link.text.strip == I18n.t("recipes.index.next_page") }
  end

  test "index shows the singular result count" do
    create_cookable_recipes(1)

    get recipes_url

    assert_select ".recipes-results-count", text: "1 recipe matches your criteria"
  end

  test "index shows the total result count on every page" do
    create_cookable_recipes(21)

    get recipes_url
    assert_select ".recipes-results-count", text: "21 recipes match your criteria"

    get recipes_url(page: 2)
    assert_select ".recipes-results-count", text: "21 recipes match your criteria"
  end

  test "index result count follows max_missing" do
    create_cookable_recipes(2)

    get recipes_url
    assert_select ".recipes-results-count", text: "2 recipes match your criteria"

    get recipes_url(max_missing: "any")
    assert_select ".recipes-results-count", text: "3 recipes match your criteria" # + @recipe, missing cheese
  end

  test "index shows no result count when nothing matches" do
    get recipes_url # the only recipe is missing cheese

    assert_select ".recipes-results-count", count: 0
    assert_select ".empty-state"
  end

  test "no next link when the total equals one page" do
    create_cookable_recipes(20)

    get recipes_url

    assert_equal 20, card_titles.size
    assert_nil next_page_link
  end

  test "next link when the total exceeds one page" do
    create_cookable_recipes(21)

    get recipes_url

    assert_not_nil next_page_link
  end

  test "no next link on the last page" do
    create_cookable_recipes(21)

    get recipes_url(page: 2)

    assert_equal 1, card_titles.size
    assert_nil next_page_link
  end

  test "filter form does not carry the current page" do
    get recipes_url(page: 2, max_missing: "any")

    assert_select "form.recipes-filters input[name=page]", count: 0
  end

  test "should get show" do
    get recipe_url(@recipe)
    assert_response :success
  end

  test "show loads pantry items with a single query" do
    assert_queries_match(/FROM "pantry_items"/, count: 1) do
      get recipe_url(@recipe)
    end
    assert_response :success
  end

  test "show should display recipe details" do
    get recipe_url(@recipe)
    assert_response :success
    assert_select ".recipe-show-title", text: @recipe.title
    assert_select ".recipe-show-ingredients"
    assert_select ".recipe-show-ingredients-list"
  end

  test "show should display missing ingredients" do
    get recipe_url(@recipe)
    assert_response :success
    # Cheese is missing from pantry
    assert_select ".recipe-show-ingredient-item--missing"
  end

  test "show should display available ingredients" do
    get recipe_url(@recipe)
    assert_response :success
    # Pasta and eggs are in pantry
    assert_select ".recipe-show-ingredient-item--available"
  end

  test "should cook recipe and decrement pantry items" do
    pasta_item = @user.pantry_items.find_by(ingredient: @pasta)
    eggs_item = @user.pantry_items.find_by(ingredient: @eggs)

    initial_pasta_quantity = pasta_item.quantity
    initial_eggs_quantity = eggs_item.quantity

    post cook_recipe_url(@recipe)

    assert_redirected_to pantry_items_url
    assert_equal I18n.t("recipes.cook.success"), flash[:notice]

    pasta_item.reload
    eggs_item.reload

    # Pasta: 500g - 200g = 300g
    assert_equal 300.0, pasta_item.quantity
    # Eggs: 6 - 2 = 4
    assert_equal 4.0, eggs_item.quantity
  end

  test "cook should remove pantry item when quantity reaches zero" do
    # Reduce pasta to less than required
    pasta_item = @user.pantry_items.find_by(ingredient: @pasta)
    pasta_item.update!(quantity: 100.0)

    post cook_recipe_url(@recipe)

    assert_redirected_to pantry_items_url

    # Pantry item should be deleted when quantity reaches zero
    pasta_item = PantryItem.find_by(user: @user, ingredient: @pasta)
    assert_nil pasta_item
  end

  test "cook should ignore ingredients not in pantry" do
    # Cheese is not in pantry, should be ignored
    cheese_count_before = PantryItem.where(user: @user, ingredient: @cheese).count

    post cook_recipe_url(@recipe)

    assert_redirected_to pantry_items_url
    cheese_count_after = PantryItem.where(user: @user, ingredient: @cheese).count

    assert_equal cheese_count_before, cheese_count_after
  end

  test "cook should work with PATCH method" do
    patch cook_recipe_url(@recipe)

    assert_redirected_to pantry_items_url
  end
end
