import Testing
import Input
import Contracts

@Test func gridDoesNotWrapAcrossRows() {
    var focus = GridFocus(index: 2)
    focus.move(.right, count: 7, columns: 3)
    #expect(focus.index == 2)
    focus.move(.down, count: 7, columns: 3)
    #expect(focus.index == 5)
    focus.move(.down, count: 7, columns: 3)
    #expect(focus.index == 5)
    focus.move(.left, count: 7, columns: 3)
    #expect(focus.index == 4)
    focus.move(.up, count: 7, columns: 3)
    #expect(focus.index == 1)
}
@Test func focusClampsAfterCatalogShrinks() {
    var focus = GridFocus(index: 8)
    focus.move(.down, count: 2, columns: 3)
    #expect(focus.index == 1)
    focus.move(.left, count: 0, columns: 3)
    #expect(focus.index == 0)
}
