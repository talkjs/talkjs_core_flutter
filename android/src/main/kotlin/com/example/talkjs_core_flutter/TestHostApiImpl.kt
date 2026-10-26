package com.example.talkjs_core_flutter

import com.talkjs.core.AutoLink
import com.talkjs.core.CodeSpan
import com.talkjs.core.ContentBlock
import com.talkjs.core.Link
import com.talkjs.core.Markup
import com.talkjs.core.TextBlock
import com.talkjs.core.VideoBlock
import com.talkjs.core.jsonFormat

internal class TestHostApiImpl : TestHostApi {
    // Test endpoints
    override fun testContentSerialization(contentJson: String): String {
        val content = jsonFormat.decodeFromString<List<ContentBlock>>(contentJson)

        val expected = listOf(
            TextBlock(
                type = "text",
                children = listOf(
                    "> Ok, so this is pretty cool\n> This is all a ",
                    Markup(type = "bold", children = listOf("blockquote")),
                    " block!\n> How cool is that, just use ",
                    CodeSpan(type = "codeSpan", text = ">"),
                    ".\n\n> This is a ",
                    Markup(type = "italic", children = listOf("separate")),
                    " blockquote tho\n\n",
                    CodeSpan(type = "codeSpan", text = "~ok~"),
                    " ",
                    Markup(
                        type = "bold",
                        children = listOf(
                            Markup(
                                type = "italic",
                                children = listOf(
                                    Markup(type = "strikethrough", children = listOf("test")),
                                ),
                            ),
                        ),
                    ),
                    " ok, ",
                    Markup(type = "bold", children = listOf("_nice")),
                    "_?  ",
                    Link(
                        type = "link",
                        url = "https://talkjs.com",
                        children = listOf(
                            "test nice ", Markup(type = "bold", children = listOf("tool"))
                        ),
                    ),
                    "\n\nSo here's the example:\n",
                    CodeSpan(
                        type = "codeSpan",
                        text = "elixir\n{:ok, _} = GenServer.call(__MODULE__, \"*nice*\")\n",
                    ),
                    "\n\nAnd quadruple backticks to escape triple backticks w/o language:\n",
                    CodeSpan(type = "codeSpan", text = "`\n"),
                    "elixir\n{:ok, ",
                    Markup(
                        type = "italic",
                        children = listOf(
                            "} = ",
                            AutoLink(
                                type = "autoLink",
                                url = "http://GenServer.call",
                                text = "GenServer.call",
                            ),
                            "(",
                        ),
                    ),
                    "_MODULE__, \"*nice*\")\n",
                    CodeSpan(type = "codeSpan", text = "\n"),
                    "`\n\nEmoji and weird unicode 👪🏼 :arslan: :'( (note the weird apostrophe here)\n\n> EOF blockquote",
                ),
            ),
            VideoBlock(
                type = "file",
                subtype = "video",
                fileToken = "token",
                url = "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
                size = 100,
                filename = "test_video",
                width = 640,
                height = 480,
                duration = 212.0,
            ),
        )
        if (content != expected) {
            throw FlutterError(
                "assertion-error", "Content mismatch.\nExpected: $expected\nActual: $content", ""
            )
        }

        return jsonFormat.encodeToString(content)
    }
}
