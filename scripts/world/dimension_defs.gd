extends RefCounted
class_name DimensionDefs

enum DimensionID {
	TWILIGHT = 0,
	REAL_WORLD = 1,
}

const DIM_NAME_KEY: Dictionary = {
	DimensionID.TWILIGHT: "DIM_TWILIGHT",
	DimensionID.REAL_WORLD: "DIM_REAL_WORLD",
}

const DIM_DESC_KEY: Dictionary = {
	DimensionID.TWILIGHT: "DIM_TWILIGHT_DESC",
	DimensionID.REAL_WORLD: "DIM_REAL_DESC",
}
