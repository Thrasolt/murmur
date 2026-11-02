import Testing
@testable import MurmurApp

@MainActor
struct InsertionFocusTests {
    @Test func keepsEachDictationsOwnField() async {
        let browser = TestFocusAccess()
        // Repeated dictations on one page must not reuse the first or second field.
        for field in 1...5 {
            browser.focusedElement = field
            let destination = InsertionFocus(access: browser)
            browser.focusedElement = nil // An overlay or menu temporarily owns focus.
            #expect(await destination.restore())
            #expect(browser.focusedElement == field)
            #expect(destination.isReady)
        }
        #expect(browser.activationCount == 0)
        #expect(browser.requestedFields == [1, 2, 3, 4, 5])
    }

    @Test func preservesCaretByLeavingFocusedBrowserAlone() async {
        let browser = TestFocusAccess()
        browser.focusedElement = 3
        let destination = InsertionFocus(access: browser)
        #expect(await destination.restore())
        #expect(browser.activationCount == 0)
        #expect(browser.requestedFields.isEmpty)
    }

    @Test func restoresOriginalFieldAfterAppActivation() async {
        let browser = TestFocusAccess()
        browser.focusedElement = 3
        let destination = InsertionFocus(access: browser)
        browser.isApplicationActive = false
        browser.focusedElement = 1
        #expect(await destination.restore())
        #expect(browser.activationCount == 1)
        #expect(browser.focusedElement == 3)
    }

    @Test func refusesToPasteWhenOriginalFieldHasDisappeared() async {
        let browser = TestFocusAccess()
        browser.focusedElement = 3
        let destination = InsertionFocus(access: browser)
        browser.focusedElement = 4
        browser.canFocus = false
        #expect(await destination.restore() == false)
        #expect(destination.isReady == false)
        #expect(browser.focusedElement == 4)
    }

    @Test func checksActualFocusInsteadOfTrustingSetAttributeSuccess() async {
        let browser = TestFocusAccess()
        browser.focusedElement = 3
        let destination = InsertionFocus(access: browser)
        browser.focusedElement = 4
        browser.ignoresFocusRequest = true
        #expect(await destination.restore() == false)
        #expect(destination.isReady == false)
    }

    @Test func noticesFocusChangesBeforePaste() async {
        let browser = TestFocusAccess()
        let destination = InsertionFocus(access: browser)
        #expect(await destination.restore())
        browser.focusedElement = 4
        #expect(destination.isReady == false)
        browser.focusedElement = 1
        browser.isApplicationActive = false
        #expect(destination.isReady == false)
    }

    @Test func preservesFallbackForEditorsWithoutAccessibilityField() async {
        let browser = TestFocusAccess()
        browser.focusedElement = nil
        let destination = InsertionFocus(access: browser)
        #expect(await destination.restore())
        #expect(browser.requestedFields.isEmpty)
    }
}

@MainActor
private final class TestFocusAccess: InsertionFocusAccess {
    var isApplicationActive = true
    var focusedElement: Int? = 1
    var activationCount = 0
    var requestedFields: [Int] = []
    var canFocus = true
    var ignoresFocusRequest = false

    func activateApplication() {
        activationCount += 1
        isApplicationActive = true
    }

    func focus(_ element: Int) -> Bool {
        requestedFields.append(element)
        guard canFocus else { return false }
        if !ignoresFocusRequest { focusedElement = element }
        return true
    }
}
