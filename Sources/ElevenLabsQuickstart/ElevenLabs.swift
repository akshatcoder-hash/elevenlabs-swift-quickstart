import Foundation

/// The two ElevenLabs calls a voice app needs: speech to text (Scribe) and text to speech.
/// Plain URLSession, no dependencies. Bring your own agent or LLM in between.
public struct ElevenLabs: Sendable {
    public let apiKey: String
    let session: URLSession
    let baseURL = URL(string: "https://api.elevenlabs.io")!

    public init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    // MARK: Text to speech

    public struct Word: Sendable, Equatable {
        public let text: String
        public let start: Double  // seconds into the audio
    }

    public struct Speech: Sendable {
        public let audio: Data  // MP3, plays with AVAudioPlayer
        public let words: [Word]
    }

    /// Speak `text`. The with-timestamps endpoint returns the audio plus when each character is spoken,
    /// which is what you need for live captions.
    public func speak(_ text: String,
                      voiceID: String = "JBFqnCBsd6RMkjVDRZzb",  // George
                      model: String = "eleven_flash_v2_5") async throws -> Speech {
        var url = baseURL.appending(path: "v1/text-to-speech/\(voiceID)/with-timestamps")
        url.append(queryItems: [URLQueryItem(name: "output_format", value: "mp3_44100_128")])

        let body = try JSONEncoder().encode(["text": text, "model_id": model])
        let response: SpeechResponse = try await post(url, contentType: "application/json", body: body)
        guard let audio = Data(base64Encoded: response.audio_base64) else { throw Failure.badAudio }
        return Speech(audio: audio, words: Self.words(from: response.alignment))
    }

    // MARK: Speech to text

    /// Transcribe an audio file (wav, mp3, m4a...) with Scribe v2.
    public func transcribe(_ file: URL, model: String = "scribe_v2") async throws -> String {
        let boundary = UUID().uuidString
        var body = Data()
        body.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"model_id\"\r\n\r\n\(model)\r\n")
        body.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"\(file.lastPathComponent)\"\r\n")
        body.append("Content-Type: application/octet-stream\r\n\r\n")
        body.append(try Data(contentsOf: file))
        body.append("\r\n--\(boundary)--\r\n")

        let response: TranscriptResponse = try await post(baseURL.appending(path: "v1/speech-to-text"),
                                                          contentType: "multipart/form-data; boundary=\(boundary)",
                                                          body: body)
        return response.text
    }

    // MARK: Plumbing

    public enum Failure: Error, CustomStringConvertible {
        case http(status: Int, body: String)
        case badAudio

        public var description: String {
            switch self {
            case .http(let status, let body): "ElevenLabs returned \(status): \(body)"
            case .badAudio: "ElevenLabs returned audio that isn't valid base64"
            }
        }
    }

    struct SpeechResponse: Decodable {
        let audio_base64: String
        let alignment: Alignment?
    }

    struct Alignment: Decodable {
        let characters: [String]
        let character_start_times_seconds: [Double]
    }

    struct TranscriptResponse: Decodable {
        let text: String
    }

    func post<T: Decodable>(_ url: URL, contentType: String, body: Data) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            throw Failure.http(status: status, body: String(decoding: data, as: UTF8.self))
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    /// Group per-character timings into words.
    static func words(from alignment: Alignment?) -> [Word] {
        guard let alignment else { return [] }
        var words: [Word] = []
        var current = ""
        var start = 0.0
        for (char, time) in zip(alignment.characters, alignment.character_start_times_seconds) {
            if char.allSatisfy(\.isWhitespace) {
                if !current.isEmpty { words.append(Word(text: current, start: start)) }
                current = ""
            } else {
                if current.isEmpty { start = time }
                current += char
            }
        }
        if !current.isEmpty { words.append(Word(text: current, start: start)) }
        return words
    }
}

extension Data {
    mutating func append(_ string: String) { append(Data(string.utf8)) }
}
