package common

Entity :: struct {
	id:         string,
	state:      i32,
	behaviours: [dynamic]i64,
	initiated:  bool,
	destroyed:  bool,
}
