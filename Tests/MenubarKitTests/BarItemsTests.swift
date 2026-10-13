import AppKit
import Testing
@testable import MenubarKit

/// The parts of `BarItems` that need no real menu bar and no defaults file: the rules for the saved positions,
/// the images, and the type of a click.
@MainActor @Suite struct BarItemsTests {
    // S33
    @Test func theFirstStartWritesTheTwoPositions() {
        #expect(BarItems.positionsToWrite(savedArrow: nil, savedDivider: nil) == (420, 430))
    }

    // S34: the drags of the user stay. `nil` means "write nothing".
    @Test func aLaterStartWritesNoPosition() {
        #expect(BarItems.positionsToWrite(savedArrow: 612.5, savedDivider: 951) == (nil, nil))
        #expect(BarItems.positionsToWrite(savedArrow: 420, savedDivider: 430) == (nil, nil))
    }

    // S17 at the start: a larger position is further left. A divider that is not on the left would push the arrow off the screen.
    @Test func aSavedDividerOnTheRightOfTheArrowGetsANewPosition() {
        #expect(BarItems.positionsToWrite(savedArrow: 430, savedDivider: 420) == (nil, 440))
        #expect(BarItems.positionsToWrite(savedArrow: 430, savedDivider: 430) == (nil, 440))
    }

    @Test func aMissingPositionIsWrittenNextToTheOther() {
        #expect(BarItems.positionsToWrite(savedArrow: 600, savedDivider: nil) == (nil, 610))
        #expect(BarItems.positionsToWrite(savedArrow: nil, savedDivider: 300) == (420, 430))
        #expect(BarItems.positionsToWrite(savedArrow: nil, savedDivider: 900) == (420, nil))
    }

    // S17 while the app runs: the new divider goes directly on the left of the arrow.
    @Test func theRepairPutsTheDividerOnTheLeftOfTheArrow() {
        #expect(BarItems.repairedDividerPosition(savedArrow: 515) == 525)
        // With no saved position, macOS puts a new icon at the far left. That is on the left of the arrow.
        #expect(BarItems.repairedDividerPosition(savedArrow: nil) == nil)
    }

    // S1, S2, S21: the arrow points left while the icons are hidden. The images are template images.
    @Test func theArrowImagesTellTheState() throws {
        let hidden = try #require(BarItems.arrowImage(pointsLeft: true, hasDot: false))
        let hiddenWithDot = try #require(BarItems.arrowImage(pointsLeft: true, hasDot: true))
        let shown = try #require(BarItems.arrowImage(pointsLeft: false, hasDot: false))
        let images: [NSImage] = [hidden, hiddenWithDot, shown]
        for image in images {
            #expect(image.isTemplate)
            #expect(image.size.width > 0 && image.size.height <= 22)
        }
        let descriptions = images.map { $0.accessibilityDescription ?? "" }
        #expect(!descriptions.contains(""))
        #expect(Set(descriptions).count == 3)
        // The dot needs room on the right of the arrow.
        #expect(hiddenWithDot.size.width > hidden.size.width)

        // The direction: the pixels are those of the system symbol.
        func pixels(_ symbol: String) -> Data? {
            NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?.tiffRepresentation
        }
        #expect(pixels("chevron.left") != pixels("chevron.right"))
        #expect(hidden.tiffRepresentation == pixels("chevron.left"))
        #expect(shown.tiffRepresentation == pixels("chevron.right"))
    }

    // S3
    @Test func aRightClickAndAControlClickAreSecondary() {
        #expect(BarItems.isSecondaryClick(type: .rightMouseUp, modifiers: []))
        #expect(BarItems.isSecondaryClick(type: .leftMouseUp, modifiers: .control))
        #expect(!BarItems.isSecondaryClick(type: .leftMouseUp, modifiers: []))
        #expect(!BarItems.isSecondaryClick(type: .leftMouseUp, modifiers: .command))
    }
}
