package common

Entity :: struct {
	id:         u64,
	state:      i32,
	behaviours: [dynamic]i64,
	initiated:  bool,
	destroyed:  bool,
}
