package eu.kanade.tachiyomi.ui.reader.novel

data class NovelRichContentParseResult(
    val blocks: List<NovelRichContentBlock>,
    val unsupportedFeaturesDetected: Boolean,
)

enum class NovelRichBlockTextAlign {
    LEFT,
    CENTER,
    JUSTIFY,
    RIGHT,
}

sealed interface NovelRichContentBlock {
    data class Paragraph(
        val segments: List<NovelRichTextSegment>,
        val textAlign: NovelRichBlockTextAlign? = null,
        val firstLineIndentEm: Float? = null,
    ) : NovelRichContentBlock

    data class Heading(
        val level: Int,
        val segments: List<NovelRichTextSegment>,
        val textAlign: NovelRichBlockTextAlign? = null,
    ) : NovelRichContentBlock

    data class BlockQuote(
        val segments: List<NovelRichTextSegment>,
        val textAlign: NovelRichBlockTextAlign? = null,
    ) : NovelRichContentBlock

    data object HorizontalRule : NovelRichContentBlock

    data class Image(
        val url: String,
        val alt: String? = null,
    ) : NovelRichContentBlock
}

data class NovelRichTextSegment(
    val text: String,
    val style: NovelRichTextStyle = NovelRichTextStyle(),
    val linkUrl: String? = null,
)

data class NovelRichTextStyle(
    val bold: Boolean = false,
    val italic: Boolean = false,
    val underline: Boolean = false,
    val strikeThrough: Boolean = false,
    val colorCss: String? = null,
    val backgroundColorCss: String? = null,
)
