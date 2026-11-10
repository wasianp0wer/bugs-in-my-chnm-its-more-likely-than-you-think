extends GutTest


func test_bundled_credits_match_repo_root_credits() -> void:
	var bundled := FileAccess.get_file_as_string("res://CREDITS.md")
	var root_path := ProjectSettings.globalize_path("res://") + "/../CREDITS.md"
	var root := FileAccess.get_file_as_string(root_path)
	assert_ne(bundled, "", "bundled CREDITS.md should not be empty")
	assert_eq(bundled, root, "res://CREDITS.md and repo-root CREDITS.md must be identical")
