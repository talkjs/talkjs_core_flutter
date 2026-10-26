import Flutter
import Foundation
import talkjs_core_swift

final class TestHostApiImpl: TestHostApi {
  // Test endpoints
  func testContentSerialization(contentJson: String) throws -> String {
    let content = try decodeContentBlocks(Data(contentJson.utf8))

    let expected: [any ContentBlock] = try [
      TextBlock(children: [
        "> Ok, so this is pretty cool\n> This is all a ",
        Markup(type: "bold", children: ["blockquote"]),
        " block!\n> How cool is that, just use ",
        CodeSpan(text: ">"),
        ".\n\n> This is a ",
        Markup(type: "italic", children: ["separate"]),
        " blockquote tho\n\n",
        CodeSpan(text: "~ok~"),
        " ",
        Markup(type: "bold", children: [
          Markup(type: "italic", children: [
            Markup(type: "strikethrough", children: ["test"]),
          ]),
        ]),
        " ok, ",
        Markup(type: "bold", children: ["_nice"]),
        "_?  ",
        Link(url: "https://talkjs.com", children: [
          "test nice ", Markup(type: "bold", children: ["tool"]),
        ]),
        "\n\nSo here's the example:\n",
        CodeSpan(text: "elixir\n{:ok, _} = GenServer.call(__MODULE__, \"*nice*\")\n"),
        "\n\nAnd quadruple backticks to escape triple backticks w/o language:\n",
        CodeSpan(text: "`\n"),
        "elixir\n{:ok, ",
        Markup(type: "italic", children: [
          "} = ",
          AutoLink(url: "http://GenServer.call", text: "GenServer.call"),
          "(",
        ]),
        "_MODULE__, \"*nice*\")\n",
        CodeSpan(text: "\n"),
        "`\n\nEmoji and weird unicode 👪🏼 :arslan: :'( (note the weird apostrophe here)\n\n> EOF blockquote",
      ]),
      VideoBlock(
        url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
        size: 100,
        filename: "test_video",
        fileToken: "token",
        width: 640,
        height: 480,
        duration: 212.0,
      ),
    ]
    if content != expected {
      throw PigeonError(
        code: "assertion-error",
        message: "Content mismatch.\nExpected: \(expected)\nActual: \(content)",
        details: "",
      )
    }

    return String(data: try encodeContentBlocks(content), encoding: .utf8)!
  }
}
