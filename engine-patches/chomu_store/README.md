# CHoMU editor plugins (embedded GDScript)

`chomu_store.gd` (CHoMU Store + Looks tab), `chomu_graphics.gd` (CHoMU Graphics / Special Grade presets) and
`chomu_looks.gd` (Looks engine) are embedded into the editor binary by `gen_headers.py`
(-> `editor/chomu/chomu_store_data.h`), written to `<editor data dir>/chomu_store/` at startup and loaded as editor plugins.

They live outside `res://addons/`, so GDScript warnings that default to *error* (e.g. INFERENCE_ON_VARIANT) are not
excluded: every `:=` must infer a concrete type.

v1.4.1: fixed `chomu_graphics.gd:440` (`var sp := {...}.get(preset, {})` inferred Variant -> parse error, Graphics plugin
did not load); now `var sp: Dictionary = ...`. STORE_VERSION "1.4".
