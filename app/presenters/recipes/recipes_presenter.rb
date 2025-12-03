module Recipes
  class RecipesPresenter
    attr_reader :recipes, :user, :page, :per_page

    def initialize(recipes, user, page: 1, per_page: 20)
      @recipes = recipes
      @user = user
      @page = page
      @per_page = per_page
    end

    def presenters
      @presenters ||= recipes.map { |recipe| RecipePresenter.new(recipe, user) }
    end

    def any?
      recipes.any?
    end

    def has_more?
      recipes.count == per_page
    end

    def empty?
      recipes.empty?
    end

    def each(&block)
      presenters.each(&block)
    end
  end
end
