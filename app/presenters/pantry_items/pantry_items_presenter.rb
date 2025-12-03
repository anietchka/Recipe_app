module PantryItems
  class PantryItemsPresenter
    include FractionConverter

    attr_reader :user, :pantry_item

    def initialize(user, pantry_item: nil)
      @user = user
      @pantry_item = pantry_item || PantryItem.new
    end

    def pantry_items
      @pantry_items ||= user.pantry_items.includes(:ingredient).order(created_at: :desc)
    end

    def common_fractions
      @common_fractions ||= FractionConverter::COMMON_FRACTIONS.values.sort
    end

    def empty?
      pantry_items.empty?
    end

    def any?
      pantry_items.any?
    end

    def count
      pantry_items.count
    end

    def each(&block)
      pantry_items.each(&block)
    end

    def text_header
      count == 1 ? I18n.t("pantry_items.index.pantry_header_text", count: count) : I18n.t("pantry_items.index.pantry_header_text_other", count: count)
    end

    def text_header_other
      t(".pantry_header_text_other", count: count)
    end
  end
end
