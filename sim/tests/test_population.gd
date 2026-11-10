extends GutTest

func test_population_bookkeeping() -> void:
	var p := Population.new()
	assert_eq(p.total(), 0)
	assert_eq(p.counts(), {})
	p.add("flea", 10)
	p.add("wasp", 3)
	p.add("flea", 5)
	assert_eq(p.counts(), {"flea": 15, "wasp": 3})
	assert_eq(p.total(), 18)
	p.add("deer", 0)
	assert_false(p.counts().has("deer"), "zero adds leave no entry")
	var snapshot := p.counts()
	snapshot["flea"] = 999
	assert_eq(p.counts()["flea"], 15, "counts() returns a copy")
	p.clear()
	assert_eq(p.counts(), {})
	assert_eq(p.total(), 0)
