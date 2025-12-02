module UnitConverter
  extend ActiveSupport::Concern

  # Unit groups for compatibility checking
  WEIGHT_UNITS = %w[g kg mg oz lb].freeze
  VOLUME_UNITS = %w[ml l cl dl cup tbsp tsp].freeze
  OTHER_UNITS = %w[pcs].freeze

  # Conversion factors to base units (g for weight, ml for volume)
  # All conversions go through base units
  CONVERSION_FACTORS = {
    # Weight units (base: g)
    "g" => 1.0,
    "kg" => 1000.0,
    "mg" => 0.001,
    "oz" => 28.3495, # 1 oz ≈ 28.3495 g
    "lb" => 453.592, # 1 lb ≈ 453.592 g
    # Volume units (base: ml)
    "ml" => 1.0,
    "l" => 1000.0,
    "cl" => 10.0,
    "dl" => 100.0,
    "cup" => 236.588, # 1 cup ≈ 236.588 ml
    "tbsp" => 14.7868, # 1 tbsp ≈ 14.7868 ml
    "tsp" => 4.92892 # 1 tsp ≈ 4.92892 ml
  }.freeze

  # Converts a quantity from one unit to another
  # Returns nil if units are incompatible or nil
  def convert_quantity(quantity, from_unit, to_unit)
    return nil if quantity.nil? || from_unit.nil? || to_unit.nil?
    return quantity if from_unit == to_unit

    return nil unless units_compatible?(from_unit, to_unit)

    # Convert to base unit first, then to target unit
    base_quantity = convert_to_base(quantity, from_unit)
    return nil unless base_quantity

    convert_from_base(base_quantity, to_unit)
  end

  # Converts a quantity to base unit (g for weight, ml for volume)
  # If base_unit is provided, converts to that specific base unit (for compatibility checking)
  # Returns nil if unit is not convertible
  def convert_to_base(quantity, unit, base_unit = nil)
    return nil if quantity.nil? || unit.nil?

    factor = CONVERSION_FACTORS[unit]
    return nil unless factor

    # Determine base unit from unit group if not provided
    base = base_unit || determine_base_unit(unit)
    return nil unless base

    # If base_unit was provided, check compatibility
    if base_unit && !units_compatible?(unit, base_unit)
      return nil
    end

    base_factor = CONVERSION_FACTORS[base]
    return nil unless base_factor

    # Convert: quantity * (factor / base_factor)
    quantity * (factor / base_factor)
  end

  # Converts a quantity from base unit to target unit
  def convert_from_base(base_quantity, to_unit)
    return nil if base_quantity.nil? || to_unit.nil?

    base = determine_base_unit(to_unit)
    return nil unless base

    base_factor = CONVERSION_FACTORS[base]
    to_factor = CONVERSION_FACTORS[to_unit]
    return nil unless base_factor && to_factor

    # Convert: base_quantity * (base_factor / to_factor)
    base_quantity * (base_factor / to_factor)
  end

  # Checks if two units are compatible (same group)
  def units_compatible?(unit1, unit2)
    return true if unit1 == unit2
    return false if unit1.nil? || unit2.nil?

    group1 = unit_group(unit1)
    group2 = unit_group(unit2)

    group1 == group2 && group1 != :other
  end

  private

  def unit_group(unit)
    return :weight if WEIGHT_UNITS.include?(unit)
    return :volume if VOLUME_UNITS.include?(unit)
    return :other if OTHER_UNITS.include?(unit)

    nil
  end

  def determine_base_unit(unit)
    return "g" if WEIGHT_UNITS.include?(unit)
    return "ml" if VOLUME_UNITS.include?(unit)

    nil
  end
end
