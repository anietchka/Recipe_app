require "test_helper"

class UnitConverterTest < ActiveSupport::TestCase
  # Test class to include the concern
  class TestClass
    include UnitConverter
  end

  setup do
    @converter = TestClass.new
  end

  test "convert_to_base converts kg to g" do
    assert_equal 1000.0, @converter.convert_to_base(1.0, "kg", "g")
    assert_equal 2000.0, @converter.convert_to_base(2.0, "kg", "g")
  end

  test "convert_to_base converts mg to g" do
    assert_equal 1.0, @converter.convert_to_base(1000.0, "mg", "g")
    assert_equal 0.5, @converter.convert_to_base(500.0, "mg", "g")
  end

  test "convert_to_base converts l to ml" do
    assert_equal 1000.0, @converter.convert_to_base(1.0, "l", "ml")
    assert_equal 500.0, @converter.convert_to_base(0.5, "l", "ml")
  end

  test "convert_to_base converts cl to ml" do
    assert_equal 10.0, @converter.convert_to_base(1.0, "cl", "ml")
    assert_equal 50.0, @converter.convert_to_base(5.0, "cl", "ml")
  end

  test "convert_to_base converts dl to ml" do
    assert_equal 100.0, @converter.convert_to_base(1.0, "dl", "ml")
  end

  test "convert_to_base converts cup to ml" do
    # 1 cup ≈ 236.6 ml
    result = @converter.convert_to_base(1.0, "cup", "ml")
    assert_in_delta 236.6, result, 0.1
  end

  test "convert_to_base converts tbsp to ml" do
    # 1 tbsp ≈ 14.8 ml
    result = @converter.convert_to_base(1.0, "tbsp", "ml")
    assert_in_delta 14.8, result, 0.1
  end

  test "convert_to_base converts tsp to ml" do
    # 1 tsp ≈ 4.9 ml
    result = @converter.convert_to_base(1.0, "tsp", "ml")
    assert_in_delta 4.9, result, 0.1
  end

  test "convert_to_base converts oz to g" do
    # 1 oz ≈ 28.35 g
    result = @converter.convert_to_base(1.0, "oz", "g")
    assert_in_delta 28.35, result, 0.1
  end

  test "convert_to_base converts lb to g" do
    # 1 lb ≈ 453.6 g
    result = @converter.convert_to_base(1.0, "lb", "g")
    assert_in_delta 453.6, result, 0.1
  end

  test "convert_to_base returns nil for incompatible units" do
    assert_nil @converter.convert_to_base(1.0, "g", "ml")
    assert_nil @converter.convert_to_base(1.0, "kg", "l")
    assert_nil @converter.convert_to_base(1.0, "pcs", "g")
  end

  test "convert_to_base returns nil for pcs unit" do
    assert_nil @converter.convert_to_base(1.0, "pcs", "g")
    assert_nil @converter.convert_to_base(1.0, "pcs", "ml")
  end

  test "convert_to_base handles nil unit" do
    assert_nil @converter.convert_to_base(1.0, nil, "g")
    # When base_unit is nil, it auto-determines, so this should work
    assert_equal 1.0, @converter.convert_to_base(1.0, "g", nil)
  end

  test "convert_quantity converts between compatible units" do
    # 1 kg = 1000 g
    assert_equal 1000.0, @converter.convert_quantity(1.0, "kg", "g")
    # 1000 g = 1 kg
    assert_equal 1.0, @converter.convert_quantity(1000.0, "g", "kg")
    # 500 mg = 0.5 g
    assert_equal 0.5, @converter.convert_quantity(500.0, "mg", "g")
  end

  test "convert_quantity returns nil for incompatible units" do
    assert_nil @converter.convert_quantity(1.0, "g", "ml")
    assert_nil @converter.convert_quantity(1.0, "kg", "l")
  end

  test "units_compatible? returns true for same unit" do
    assert @converter.units_compatible?("g", "g")
    assert @converter.units_compatible?("kg", "kg")
    assert @converter.units_compatible?(nil, nil)
  end

  test "units_compatible? returns true for compatible units" do
    assert @converter.units_compatible?("g", "kg")
    assert @converter.units_compatible?("kg", "g")
    assert @converter.units_compatible?("ml", "l")
    assert @converter.units_compatible?("l", "ml")
  end

  test "units_compatible? returns false for incompatible units" do
    assert_not @converter.units_compatible?("g", "ml")
    assert_not @converter.units_compatible?("kg", "l")
    assert_not @converter.units_compatible?("pcs", "g")
  end

  test "units_compatible? returns false when one unit is nil" do
    assert_not @converter.units_compatible?("g", nil)
    assert_not @converter.units_compatible?(nil, "g")
  end
end
