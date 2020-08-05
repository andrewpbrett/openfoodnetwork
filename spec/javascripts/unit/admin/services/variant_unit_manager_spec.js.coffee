describe "VariantUnitManager", ->
  VariantUnitManager = null

  beforeEach ->
    module "admin.products"

  beforeEach inject (_VariantUnitManager_) ->
    VariantUnitManager = _VariantUnitManager_

  describe "getScale", ->
    it "returns the largest scale for which value/scale is greater than 1", ->
      expect(VariantUnitManager.getScale(1.2,"weight")).toEqual 1.0
      expect(VariantUnitManager.getScale(1000,"weight")).toEqual 1000.0
      expect(VariantUnitManager.getScale(0.0012,"volume")).toEqual 0.001
      expect(VariantUnitManager.getScale(1001,"volume")).toEqual 1000.0

    it "returns the smallest unit available when value is smaller", ->
      expect(VariantUnitManager.getScale(0.4,"weight")).toEqual 1
      expect(VariantUnitManager.getScale(0.0004,"volume")).toEqual 0.001

  describe "getUnitName", ->
    it "returns the unit name based on the scale and unit type (weight/volume) provided", ->
      expect(VariantUnitManager.getUnitName(1, "weight")).toEqual "g"
      expect(VariantUnitManager.getUnitName(1000, "weight")).toEqual "kg"
      expect(VariantUnitManager.getUnitName(1000000, "weight")).toEqual "T"
      expect(VariantUnitManager.getUnitName(0.001, "volume")).toEqual "mL"
      expect(VariantUnitManager.getUnitName(1, "volume")).toEqual "L"
      expect(VariantUnitManager.getUnitName(1000, "volume")).toEqual "kL"

  describe "unitScales", ->
    it "returns a set of scales for unit type weight", ->
      expect(VariantUnitManager.unitScales('weight')).toEqual [1, 28.34952, 453.6, 1000, 1000000]

    it "returns a set of scales for unit type volume", ->
      expect(VariantUnitManager.unitScales('volume')).toEqual [0.001, 1, 1000]

  describe "variantUnitOptions", ->
    it "returns an array of options", ->
      expect(VariantUnitManager.variantUnitOptions()).toEqual [
        ["Weight (g)", "weight_1"],
        ["Weight (kg)", "weight_1000"],
        ["Weight (T)", "weight_1000000"],
        ["Weight (oz)", "weight_28.34952"],
        ["Weight (lb)", "weight_453.6"],
        ["Volume (mL)", "volume_0.001"],
        ["Volume (L)", "volume_1"],
        ["Volume (kL)", "volume_1000"],
        ["Items", "items"]
      ]
