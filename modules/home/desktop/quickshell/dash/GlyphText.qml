// A single glyph centered by its INK, not by the line box: the font's ascent and descent put a
// chevron or an icon a pixel or two off the row's middle. The shift is whole pixels, so it stays sharp.
import QtQuick
import "root:/"

Text {
    id: g

    font.family: Theme.uiFont
    width: Math.ceil(ink.advanceWidth)
    transform: Translate {
        x: Math.round(g.width / 2 - ink.tightBoundingRect.x - ink.tightBoundingRect.width / 2)
        y: Math.round(g.height / 2 - g.baselineOffset - ink.tightBoundingRect.y - ink.tightBoundingRect.height / 2)
    }

    TextMetrics {
        id: ink
        font: g.font
        text: g.text
    }
}
