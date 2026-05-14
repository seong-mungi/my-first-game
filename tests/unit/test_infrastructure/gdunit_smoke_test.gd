extends GdUnitTestSuite


func test_gdunit_pipeline_discovers_and_runs_example_suite() -> void:
	assert_bool(true).is_true()


func test_project_physics_tick_contract_matches_adr_0003() -> void:
	assert_int(ProjectSettings.get_setting("physics/common/physics_ticks_per_second")).is_equal(60)
