extends AudioStreamPlayer
@onready var audio_stream_player: AudioStreamPlayer = $"."

func _process(delta: float):
	if audio_stream_player.playing == false:
		audio_stream_player.play()
