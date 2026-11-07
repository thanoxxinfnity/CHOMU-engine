One file per feature: `test_f_XX.gd`, `extends RefCounted`, `func run(t: Node) -> void`.
Report with `t.check(name, cond, detail)`; `await t.physics_frames(n)` and `t.get_tree()` are available.
self_test.tscn runs them all after the core checks; item_runner.tscn runs one (`-- --item=test_f_XX.gd`).
