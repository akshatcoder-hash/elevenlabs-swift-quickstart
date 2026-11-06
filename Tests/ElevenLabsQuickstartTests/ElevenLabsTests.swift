import Foundation
@testable import ElevenLabsQuickstart
import Testing

/// Answers every request with a canned response so tests never hit the network.
final class StubProtocol: URLProtocol {
    nonisolated(unsafe) static var lastRequest: URLRequest?
    nonisolated(unsafe) static var lastBody: Data?
    nonisolated(unsafe) static var reply: (status: Int, body: Data) = (200, Data())

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lastRequest = request
        Self.lastBody = request.httpBody ?? request.httpBodyStream.map(Self.read)
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.reply.status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.reply.body)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}

    static func read(_ stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let n = stream.read(&buffer, maxLength: buffer.count)
            if n <= 0 { break }
            data.append(buffer, count: n)
        }
        return data
    }
}

@Suite(.serialized) struct ElevenLabsTests {
    let client: ElevenLabs

    init() {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubProtocol.self]
        client = ElevenLabs(apiKey: "test-key", session: URLSession(configuration: config))
    }

    @Test func speakSendsKeyAndModelAndDecodesWords() async throws {
        let audio = Data("fake mp3".utf8).base64EncodedString()
        StubProtocol.reply = (200, Data("""
        {"audio_base64":"\(audio)","alignment":{"characters":["H","i"," ","y","o"],
         "character_start_times_seconds":[0.0,0.1,0.2,0.3,0.4],"character_end_times_seconds":[0.1,0.2,0.3,0.4,0.5]}}
        """.utf8))

        let speech = try await client.speak("Hi yo")

        let request = try #require(StubProtocol.lastRequest)
        #expect(request.value(forHTTPHeaderField: "xi-api-key") == "test-key")
        #expect(request.url?.path == "/v1/text-to-speech/JBFqnCBsd6RMkjVDRZzb/with-timestamps")
        let body = try JSONDecoder().decode([String: String].self, from: #require(StubProtocol.lastBody))
        #expect(body == ["text": "Hi yo", "model_id": "eleven_flash_v2_5"])
        #expect(speech.audio == Data("fake mp3".utf8))
        #expect(speech.words == [.init(text: "Hi", start: 0.0), .init(text: "yo", start: 0.3)])
    }

    @Test func transcribeSendsScribeModelAndReturnsText() async throws {
        StubProtocol.reply = (200, Data(#"{"text":"hello world"}"#.utf8))
        let file = FileManager.default.temporaryDirectory.appending(path: "clip.wav")
        try Data("wav".utf8).write(to: file)

        let text = try await client.transcribe(file)

        #expect(text == "hello world")
        let body = String(decoding: try #require(StubProtocol.lastBody), as: UTF8.self)
        #expect(body.contains("name=\"model_id\"\r\n\r\nscribe_v2"))
        #expect(body.contains("filename=\"clip.wav\""))
        #expect(body.contains("\r\n\r\nwav\r\n"))
        #expect(StubProtocol.lastRequest?.url?.path == "/v1/speech-to-text")
        #expect(StubProtocol.lastRequest?.value(forHTTPHeaderField: "xi-api-key") == "test-key")
    }

    @Test func invalidBase64AudioFails() async {
        StubProtocol.reply = (200, Data(#"{"audio_base64":"not base64!"}"#.utf8))
        await #expect(throws: ElevenLabs.Failure.self) { try await client.speak("hi") }
    }

    @Test func errorsCarryStatusAndBody() async {
        StubProtocol.reply = (401, Data(#"{"detail":"invalid api key"}"#.utf8))
        do {
            _ = try await client.speak("hi")
            Issue.record("expected an error")
        } catch let ElevenLabs.Failure.http(status, body) {
            #expect(status == 401)
            #expect(body.contains("invalid api key"))
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }
}
