# ElevenLabs in Swift, without an agent framework

ElevenLabs has an official Swift SDK, but it's built for ElevenAgents, where ElevenLabs runs the whole conversation. Sometimes you just want your app to talk and listen, and keep your own model in charge. That's two HTTP calls. This repo is those two calls in one file you can copy: [`ElevenLabs.swift`](Sources/ElevenLabsQuickstart/ElevenLabs.swift).

These are the same two calls I use in a Mac agent I'm building. This is an unofficial guide, not an ElevenLabs project.

If you have a server, [Speech Engine](https://elevenlabs.io/docs/eleven-api/guides/cookbooks/speech-engine) is the official way to put ElevenLabs around your own LLM. This repo is for the other case, a personal tool where your model or agent already runs on your Mac and there's no server in the middle. It's unofficial and not affiliated with ElevenLabs.

## Try it

```sh
export ELEVENLABS_API_KEY=...        # elevenlabs.io → Developers → API keys
swift run eleven say "Hello from Swift"
swift run eleven listen recording.m4a
swift run eleven echo recording.m4a  # transcribe, then say it back
```

`say` prints each word as it's spoken, using the timings ElevenLabs sends back.

## The two calls

### Text to speech

```swift
let client = ElevenLabs(apiKey: key)
let speech = try await client.speak("Hello from Swift")
let player = try AVAudioPlayer(data: speech.audio)
player.play()
```

Under the hood that's a POST to `/v1/text-to-speech/{voice_id}/with-timestamps` with `{"text", "model_id"}`. A few things that tripped me up:

- **The auth header is `xi-api-key`, not `Authorization: Bearer`.** If you're coming from OpenAI, this is the one you'll get wrong.
- **Use `/with-timestamps` if you'll ever want captions.** You get the audio as base64 plus a start time for every character, which is enough for live captions or highlighting.
- **Ask for a complete MP3** (`output_format=mp3_44100_128`), and `AVAudioPlayer` plays it as-is. You only need streaming if you want speech to start before the whole reply has been generated.
- **Pick the model.** `eleven_flash_v2_5` is one of ElevenLabs' low-latency models and the default here.

### Speech to text

```swift
let text = try await client.transcribe(URL(fileURLWithPath: "recording.m4a"))
```

That's a multipart POST to `/v1/speech-to-text` with `model_id=scribe_v2` and the file. You get JSON back with a `text` field.

## In a real app

- **Don't ship your key in the binary.** For your own tools, store it in Keychain. For an app other people use, put a small server in front that holds the key.
- **Errors come back as JSON with the status code.** `ElevenLabs.Failure.http` keeps both, so a 401 tells you what's actually wrong.
- **Requests run one turn at a time:** record, transcribe, think, speak. To cut the pause, stream the TTS. That's the next thing I'd add.

## Tests

```sh
bash scripts/test.sh
```

The tests stub `URLSession` and check the exact request shape (URL, header, body), plus word parsing and error handling. They don't call the API.
