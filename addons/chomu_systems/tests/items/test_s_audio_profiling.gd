extends RefCounted
const Impl := preload("res://addons/chomu_systems/sheet/audio_profiling.gd")

func run(t: Node) -> void:
	var prof: ChomuAudioProfiling = Impl.new()
	prof._init(12345, 44100.0)

	# F-61 register / unregister channels
	t.check("F-61 register new channel", prof.register_channel("music", 0.8), "music registered")
	t.check("F-61 register duplicate fails", not prof.register_channel("music", 0.5), "duplicate rejected")
	t.check("F-61 volume clamped", prof.get_channel_volume("music") == 0.8, "volume set")
	t.check("F-61 unknown volume zero", prof.get_channel_volume("missing") == 0.0, "missing returns 0")
	t.check("F-61 set volume", prof.set_channel_volume("music", 0.5) and prof.get_channel_volume("music") == 0.5, "volume updated")
	t.check("F-61 set volume unknown fails", not prof.set_channel_volume("missing", 1.0), "set on missing fails")
	t.check("F-61 unregister", prof.unregister_channel("music") and not prof.unregister_channel("music"), "unregister works")

	# F-61 profiling block updates peak/RMS
	prof.register_channel("sfx", 1.0)
	var samples: PackedFloat32Array = PackedFloat32Array([1.0, -1.0, 0.5, -0.5])
	var res = prof.profile_block("sfx", samples)
	t.check("F-61 peak is 1.0", res.peak == 1.0, "peak detected")
	t.check("F-61 rms > 0", res.rms > 0.0, "rms computed")
	t.check("F-61 frame count", res.frame_count == 2, "stereo frames counted")
	t.check("F-61 unknown channel empty", prof.profile_block("nope", samples).frame_count == 4, "unknown returns raw count")

	# F-61 playback timing
	prof.advance_time(1.0)
	prof.start_playback("sfx")
	t.check("F-61 is playing snapshot", prof.get_snapshot()["sfx"]["is_playing"] == true, "started")
	prof.advance_time(2.0)
	prof.stop_playback("sfx")
	t.check("F-61 play time accumulated", prof.get_snapshot()["sfx"]["total_play_time"] > 0.0, "time tracked")
	t.check("F-61 play count", prof.get_snapshot()["sfx"]["play_count"] == 1, "count incremented")

	# F-61 save/load roundtrip
	prof.register_channel("voice", 0.7)
	prof.start_playback("voice")
	prof.advance_time(0.5)
	var state: Dictionary = prof.save_state()
	var prof2: ChomuAudioProfiling = Impl.new()
	prof2.load_state(state)
	t.check("F-61 load channels", prof2.get_channels().size() == 2, "channels restored")
	t.check("F-61 load volume", prof2.get_channel_volume("voice") == 0.7, "volume restored")
	t.check("F-61 load is_playing", prof2.get_snapshot()["voice"]["is_playing"] == true, "playing state restored")
	t.check("F-61 load time", prof2.get_time() == prof.get_time(), "time restored")
