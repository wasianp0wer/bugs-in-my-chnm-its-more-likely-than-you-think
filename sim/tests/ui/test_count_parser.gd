extends GutTest

func test_parse_valid():
	assert_eq(CountParser.parse("5000"), 5000)
	assert_eq(CountParser.parse("5,000"), 5000)
	assert_eq(CountParser.parse(" 42 "), 42)
	assert_eq(CountParser.parse("10k"), 10000)
	assert_eq(CountParser.parse("1.5k"), 1500)
	assert_eq(CountParser.parse("2m"), 2000000)
	assert_eq(CountParser.parse("10000000"), 10000000)

func test_parse_invalid():
	for s in ["", "0", "-5", "abc", "1e6", "5,00", "1.55k"]:
		assert_eq(CountParser.parse(s), -1, "'%s' should be invalid" % s)
