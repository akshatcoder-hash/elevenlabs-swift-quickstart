import AVFoundation
import ElevenLabsQuickstart
import Foundation

// eleven say "text"        speak it, printing each word as it's said
// eleven listen file.m4a   transcribe a recording
// eleven echo file.m4a     transcribe it, then say it back

guard let key = ProcessInfo.processInfo.environment["ELEVENLABS_API_KEY"], !key.isEmpty else {
    print("Set ELEVENLABS_API_KEY first.")
    exit(1)
}
let client = ElevenLabs(apiKey: key)
let args = Array(CommandLine.arguments.dropFirst())

func say(_ text: String) async throws {
    let speech = try await client.speak(text)
    let player = try AVAudioPlayer(data: speech.audio)
    player.play()
    let started = Date()
    for word in speech.words {
        let wait = word.start - Date().timeIntervalSince(started)
        if wait > 0 { try await Task.sleep(for: .seconds(wait)) }
        print(word.text, terminator: " ")
        fflush(stdout)
    }
    let rest = player.duration - Date().timeIntervalSince(started)
    if rest > 0 { try await Task.sleep(for: .seconds(rest)) }
    print()
}

do {
    switch (args.first, args.dropFirst().joined(separator: " ")) {
    case ("say", let text) where !text.isEmpty:
        try await say(text)
    case ("listen", let path) where !path.isEmpty:
        print(try await client.transcribe(URL(fileURLWithPath: path)))
    case ("echo", let path) where !path.isEmpty:
        let heard = try await client.transcribe(URL(fileURLWithPath: path))
        print("heard: \(heard)")
        try await say(heard)
    default:
        print("usage: eleven say \"text\" | eleven listen <file> | eleven echo <file>")
        exit(1)
    }
} catch {
    print("error: \(error)")
    exit(1)
}
