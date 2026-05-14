# GdUnit4 local smoke runner.
# Prefer tools/ci/run_gdunit4_local.sh because it can bootstrap GdUnit4 first.
extends SceneTree

const GDUNIT_CMD := "res://addons/gdUnit4/bin/GdUnitCmdTool.gd"
const REPORT_DIR := "res://reports"


func _init() -> void:
	if not FileAccess.file_exists(GDUNIT_CMD):
		push_error("GdUnit4 command tool not found at %s. Run tools/ci/run_gdunit4_local.sh to bootstrap the addon for local tests." % GDUNIT_CMD)
		quit(1)
		return

	var executable := OS.get_executable_path()
	var project_dir := ProjectSettings.globalize_path("res://")

	var import_args := PackedStringArray(["--headless", "--editor", "--quit", "--path", project_dir])
	var import_output: Array[String] = []
	var import_code := OS.execute(executable, import_args, import_output, true, false)
	for line: String in import_output:
		print(line)
	if import_code != 0:
		push_error("Godot import/class-cache refresh failed with exit code %d." % import_code)
		quit(import_code)
		return

	var test_paths := PackedStringArray(["res://tests/unit", "res://tests/integration"])
	var args := PackedStringArray([
		"--headless",
		"--path", project_dir,
		"-s",
		"-d",
		GDUNIT_CMD,
		"-rd", REPORT_DIR,
		"--ignoreHeadlessMode",
		"-c",
	])
	for path: String in test_paths:
		args.append("-a")
		args.append(path)

	var output: Array[String] = []
	var exit_code := OS.execute(executable, args, output, true, false)
	for line: String in output:
		print(line)
	quit(exit_code)
