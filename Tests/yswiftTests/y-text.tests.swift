import XCTest
import Promise
@testable import yswift

final class YTextTests: XCTestCase {
    
    func testDeltaBug() throws {
        let initialDelta = [
            YEventDelta(insert: "\n", attributes: Ref(value: [
                "block-id": "block-28eea923-9cbb-4b6f-a950-cf7fd82bc087"
            ])),
            YEventDelta(insert: "\n\n\n", attributes: Ref(value: [
                "table-col": [
                    "width": "150"
                ]
            ])),
            YEventDelta(insert: "\n", attributes: Ref(value: [
                "block-id": "block-9144be72-e528-4f91-b0b2-82d20408e9ea",
                "table-cell-line": [
                    "rowspan": "1",
                    "colspan": "1",
                    "row": "row-6kv2ls",
                    "cell": "cell-apba4k"
                ],
                "row": "row-6kv2ls",
                "cell": "cell-apba4k",
                "rowspan": "1",
                "colspan": "1"
            ])),
            YEventDelta(insert: "\n", attributes: Ref(value: [
                "block-id": "block-639adacb-1516-43ed-b272-937c55669a1c",
                "table-cell-line": [
                    "rowspan": "1",
                    "colspan": "1",
                    "row": "row-6kv2ls",
                    "cell": "cell-a8qf0r"
                ],
                "row": "row-6kv2ls",
                "cell": "cell-a8qf0r",
                "rowspan": "1",
                "colspan": "1"
            ])),
            YEventDelta(insert: "\n", attributes: Ref(value: [
                "block-id": "block-6302ca4a-73a3-4c25-8c1e-b542f048f1c6",
                "table-cell-line": [
                    "rowspan": "1",
                    "colspan": "1",
                    "row": "row-6kv2ls",
                    "cell": "cell-oi9ikb"
                ],
                "row": "row-6kv2ls",
                "cell": "cell-oi9ikb",
                "rowspan": "1",
                "colspan": "1"
            ])),
            YEventDelta(insert: "\n", attributes: Ref(value: [
                "block-id": "block-ceeddd05-330e-4f86-8017-4a3a060c4627",
                "table-cell-line": [
                    "rowspan": "1",
                    "colspan": "1",
                    "row": "row-d1sv2g",
                    "cell": "cell-dt6ks2"
                ],
                "row": "row-d1sv2g",
                "cell": "cell-dt6ks2",
                "rowspan": "1",
                "colspan": "1"
            ])),
            YEventDelta(insert: "\n", attributes: Ref(value: [
                "block-id": "block-37b19322-cb57-4e6f-8fad-0d1401cae53f",
                "table-cell-line": [
                    "rowspan": "1",
                    "colspan": "1",
                    "row": "row-d1sv2g",
                    "cell": "cell-qah2ay"
                ],
                "row": "row-d1sv2g",
                "cell": "cell-qah2ay",
                "rowspan": "1",
                "colspan": "1"
            ])),
            YEventDelta(insert: "\n", attributes: Ref(value: [
                "block-id": "block-468a69b5-9332-450b-9107-381d593de249",
                "table-cell-line": [
                    "rowspan": "1",
                    "colspan": "1",
                    "row": "row-d1sv2g",
                    "cell": "cell-fpcz5a"
                ],
                "row": "row-d1sv2g",
                "cell": "cell-fpcz5a",
                "rowspan": "1",
                "colspan": "1"
            ])),
            YEventDelta(insert: "\n", attributes: Ref(value: [
                "block-id": "block-26b1d252-9b2e-4808-9b29-04e76696aa3c",
                "table-cell-line": [
                    "rowspan": "1",
                    "colspan": "1",
                    "row": "row-pflz90",
                    "cell": "cell-zrhylp"
                ],
                "row": "row-pflz90",
                "cell": "cell-zrhylp",
                "rowspan": "1",
                "colspan": "1"
            ])),
            YEventDelta(insert: "\n", attributes: Ref(value: [
                "block-id": "block-6af97ba7-8cf9-497a-9365-7075b938837b",
                "table-cell-line": [
                    "rowspan": "1",
                    "colspan": "1",
                    "row": "row-pflz90",
                    "cell": "cell-s1q9nt"
                ],
                "row": "row-pflz90",
                "cell": "cell-s1q9nt",
                "rowspan": "1",
                "colspan": "1"
            ])),
            YEventDelta(insert: "\n", attributes: Ref(value: [
                "block-id": "block-107e273e-86bc-44fd-b0d7-41ab55aca484",
                "table-cell-line": [
                    "rowspan": "1",
                    "colspan": "1",
                    "row": "row-pflz90",
                    "cell": "cell-20b0j9"
                ],
                "row": "row-pflz90",
                "cell": "cell-20b0j9",
                "rowspan": "1",
                "colspan": "1"
            ])),
            YEventDelta(insert: "\n", attributes: Ref(value: [
                "block-id": "block-38161f9c-6f6d-44c5-b086-54cc6490f1e3"
            ])),
            YEventDelta(insert: "Content after table"),
            YEventDelta(insert: "\n", attributes: Ref(value: [
                "block-id": "block-15630542-ef45-412d-9415-88f0052238ce"
            ]))
        ]
        let ydoc1 = Doc()
        let ytext = try ydoc1.getText()
        try ytext.applyDelta(initialDelta)
        let addingDash = [
            YEventDelta(retain: 12),
            YEventDelta(insert: "-")
        ]
        try ytext.applyDelta(addingDash)
        let addingSpace = [
            YEventDelta(retain: 13),
            YEventDelta(insert: " ")
        ]
        try ytext.applyDelta(addingSpace)
        
        let addingList = [
            YEventDelta(retain: 12),
            YEventDelta(delete: 2),
            YEventDelta(retain: 1, attributes: Ref(value: [
                "table-cell-line": nil,
                "list": [
                    "rowspan": "1",
                    "colspan": "1",
                    "row": "row-pflz90",
                    "cell": "cell-20b0j9",
                    "list": "bullet"
                ]
            ]))
        ]
        try ytext.applyDelta(addingList)
        let result = try ytext.toDelta()
        let expectedResult = [
            YEventDelta(insert: "\n", attributes: Ref(value: [
                "block-id": "block-28eea923-9cbb-4b6f-a950-cf7fd82bc087"
            ])),
            YEventDelta(insert: "\n\n\n", attributes: Ref(value: [
                "table-col": [
                    "width": "150"
                ]
            ])),
            YEventDelta(insert: "\n", attributes: Ref(value: [
                "block-id": "block-9144be72-e528-4f91-b0b2-82d20408e9ea",
                "table-cell-line": [
                    "rowspan": "1",
                    "colspan": "1",
                    "row": "row-6kv2ls",
                    "cell": "cell-apba4k"
                ],
                "row": "row-6kv2ls",
                "cell": "cell-apba4k",
                "rowspan": "1",
                "colspan": "1"
            ])),
            YEventDelta(insert: "\n", attributes: Ref(value: [
                "block-id": "block-639adacb-1516-43ed-b272-937c55669a1c",
                "table-cell-line": [
                    "rowspan": "1",
                    "colspan": "1",
                    "row": "row-6kv2ls",
                    "cell": "cell-a8qf0r"
                ],
                "row": "row-6kv2ls",
                "cell": "cell-a8qf0r",
                "rowspan": "1",
                "colspan": "1"
            ])),
            YEventDelta(insert: "\n", attributes: Ref(value: [
                "block-id": "block-6302ca4a-73a3-4c25-8c1e-b542f048f1c6",
                "table-cell-line": [
                    "rowspan": "1",
                    "colspan": "1",
                    "row": "row-6kv2ls",
                    "cell": "cell-oi9ikb"
                ],
                "row": "row-6kv2ls",
                "cell": "cell-oi9ikb",
                "rowspan": "1",
                "colspan": "1"
            ])),
            YEventDelta(insert: "\n", attributes: Ref(value: [
                "block-id": "block-ceeddd05-330e-4f86-8017-4a3a060c4627",
                "table-cell-line": [
                    "rowspan": "1",
                    "colspan": "1",
                    "row": "row-d1sv2g",
                    "cell": "cell-dt6ks2"
                ],
                "row": "row-d1sv2g",
                "cell": "cell-dt6ks2",
                "rowspan": "1",
                "colspan": "1"
            ])),
            YEventDelta(insert: "\n", attributes: Ref(value: [
                "block-id": "block-37b19322-cb57-4e6f-8fad-0d1401cae53f",
                "table-cell-line": [
                    "rowspan": "1",
                    "colspan": "1",
                    "row": "row-d1sv2g",
                    "cell": "cell-qah2ay"
                ],
                "row": "row-d1sv2g",
                "cell": "cell-qah2ay",
                "rowspan": "1",
                "colspan": "1"
            ])),
            YEventDelta(insert: "\n", attributes: Ref(value: [
                "block-id": "block-468a69b5-9332-450b-9107-381d593de249",
                "table-cell-line": [
                    "rowspan": "1",
                    "colspan": "1",
                    "row": "row-d1sv2g",
                    "cell": "cell-fpcz5a"
                ],
                "row": "row-d1sv2g",
                "cell": "cell-fpcz5a",
                "rowspan": "1",
                "colspan": "1"
            ])),
            YEventDelta(insert: "\n", attributes: Ref(value: [
                "block-id": "block-26b1d252-9b2e-4808-9b29-04e76696aa3c",
                "table-cell-line": [
                    "rowspan": "1",
                    "colspan": "1",
                    "row": "row-pflz90",
                    "cell": "cell-zrhylp"
                ],
                "row": "row-pflz90",
                "cell": "cell-zrhylp",
                "rowspan": "1",
                "colspan": "1"
            ])),
            YEventDelta(insert: "\n", attributes: Ref(value: [
                "block-id": "block-6af97ba7-8cf9-497a-9365-7075b938837b",
                "table-cell-line": [
                    "rowspan": "1",
                    "colspan": "1",
                    "row": "row-pflz90",
                    "cell": "cell-s1q9nt"
                ],
                "row": "row-pflz90",
                "cell": "cell-s1q9nt",
                "rowspan": "1",
                "colspan": "1"
            ])),
            YEventDelta(insert: "\n", attributes: Ref(value: [
                "list": [
                    "rowspan": "1",
                    "colspan": "1",
                    "row": "row-pflz90",
                    "cell": "cell-20b0j9",
                    "list": "bullet"
                ],
                "block-id": "block-107e273e-86bc-44fd-b0d7-41ab55aca484",
                "row": "row-pflz90",
                "cell": "cell-20b0j9",
                "rowspan": "1",
                "colspan": "1"
            ])),
            YEventDelta(insert: "\n", attributes: Ref(value: [
                "block-id": "block-38161f9c-6f6d-44c5-b086-54cc6490f1e3"
            ])),
            YEventDelta(insert: "Content after table"),
            YEventDelta(insert: "\n", attributes: Ref(value: [
                "block-id": "block-15630542-ef45-412d-9415-88f0052238ce"
            ]))
        ]
        XCTAssertEqual(result, expectedResult)
    }
    
    func testDeltaAfterConcurrentFormatting() throws {
        let test = try YTest<Any>(docs: 2)
        let text0 = test.text[0], text1 = test.text[1], connector = test.connector
        
        try text0.insert(0, text: "abcde")
        
        try connector.flushAllMessages()
        
        try text0.format(0, length: 3, attributes: Ref(value: ["bold": true]))
        try text1.format(2, length: 2, attributes: Ref(value: ["bold": true]))
        
        var deltas: [[YEventDelta]] = []
        
        text1.observe{ event, _ in
            if (try event.delta().count > 0) {
                try deltas.append(event.delta())
            }
        }
        
        try connector.flushAllMessages()
        
        XCTAssertEqual(deltas, [[
            YEventDelta(retain: 3, attributes: ["bold": true]),
            YEventDelta(retain: 2, attributes: ["bold": nil])
        ]])
    }
    
    func testBasicInsertAndDelete() throws {
        let test = try YTest<Any>(docs: 2)
        let text0 = test.text[0], docs = test.docs
        
        var delta: [YEventDelta]?
        text0.observe{ event, _ in delta = try event.delta() }
        
        try text0.delete(0, length: 0)
        
        XCTAssert(true, "Does not throw when deleting zero elements with position 0")
        
        try text0.insert(0, text: "abc")
        
        XCTAssert(text0.toString() == "abc", "Basic insert works")
        XCTAssertEqual(delta, [YEventDelta(insert: "abc")])
        
        try text0.delete(0, length: 1)
        
        XCTAssert(text0.toString() == "bc", "Basic delete works (position 0)")
        XCTAssertEqual(delta, [YEventDelta(delete: 1)])
        
        try text0.delete(1, length: 1)
        
        XCTAssert(text0.toString() == "b", "Basic delete works (position 1)")
        
        XCTAssertEqual(delta, [YEventDelta(retain: 1), YEventDelta(delete: 1)])
        
        try docs[0].transact{_ in
            try text0.insert(0, text: "1")
            try text0.delete(0, length: 1)
        }
        
        XCTAssertEqual(delta, [])
        try YAssertEqualDocs(docs)
    }
    
    func testBasicFormat() throws {
        let test = try YTest<Any>(docs: 2)
        let text0 = test.text[0], docs = test.docs
        
        var delta: [YEventDelta]?
        text0.observe{ event, _ in delta = try event.delta() }
        
        try text0.insert(0, text: "abc", attributes: Ref(value: ["bold": true]))
        
        XCTAssertEqual(text0.toString(), "abc")
        XCTAssertEqual(try text0.toDelta(), [YEventDelta(insert: "abc", attributes: ["bold": true])])
        XCTAssertEqual(delta, [YEventDelta(insert: "abc", attributes: ["bold": true] )])

        try text0.delete(0, length: 1)

        XCTAssertEqual(text0.toString(), "bc")
        XCTAssertEqual(try text0.toDelta(), [YEventDelta(insert: "bc", attributes: Ref(value: ["bold": true]))])
        XCTAssertEqual(delta, [YEventDelta(delete: 1)])

        try text0.delete(1, length: 1)

        XCTAssertEqual(text0.toString(), "b", "Basic delete works (position 1)")
        XCTAssertEqual(try text0.toDelta(), [YEventDelta(insert: "b", attributes: Ref(value: ["bold": true]))])
        XCTAssertEqual(delta, [YEventDelta(retain: 1), YEventDelta(delete: 1)])
        
        try text0.insert(0, text: "z", attributes: Ref(value: ["bold": true]))
        
        XCTAssertEqual(text0.toString(), "zb")
        XCTAssertEqual(try text0.toDelta(), [YEventDelta(insert: "zb", attributes: Ref(value: ["bold": true]))])
        XCTAssertEqual(delta, [YEventDelta(insert: "z", attributes: ["bold": true])])
        
        let contentString = try XCTUnwrap(text0._start?.right?.asItemRight?.asItemRight?.asItemContentString)
        XCTAssertEqual(contentString.string, "b", "Does not insert duplicate attribute marker")
        
        try text0.insert(0, text: "y")
        XCTAssertEqual(text0.toString(), "yzb")
        XCTAssertEqual(try text0.toDelta(), [YEventDelta(insert: "y"), YEventDelta(insert: "zb", attributes: ["bold": true])])
        XCTAssertEqual(delta, [YEventDelta(insert: "y")])
        
        try text0.format(0, length: 2, attributes: Ref(value: ["bold": nil]))
        
        XCTAssertEqual(text0.toString(), "yzb")
        XCTAssertEqual(try text0.toDelta(), [YEventDelta(insert: "yz"), YEventDelta(insert: "b", attributes: ["bold": true])])
        XCTAssertEqual(delta, [YEventDelta(retain: 1), YEventDelta(retain: 1, attributes: ["bold": nil] )])
                                             
        try YAssertEqualDocs(docs)
    }
    
    func testMultilineFormat() throws {
        let ydoc = Doc()
        let testText = try ydoc.getText("test")
        try testText.insert(0, text: "Test\nMulti-line\nFormatting")
        try testText.applyDelta([
            YEventDelta(retain: 4, attributes: ["bold": true]),
            YEventDelta(retain: 1),
            YEventDelta(retain: 10, attributes: ["bold": true]),
            YEventDelta(retain: 1),
            YEventDelta(retain: 10, attributes: ["bold": true])
        ])
        
        try XCTAssertEqual(testText.toDelta(), [
            YEventDelta(insert: "Test", attributes: ["bold": true]),
            YEventDelta(insert: "\n"),
            YEventDelta(insert: "Multi-line", attributes: ["bold": true]),
            YEventDelta(insert: "\n"),
            YEventDelta(insert: "Formatting", attributes: ["bold": true])
        ])
    }

    func testNotMergeEmptyLinesFormat() throws {
        let ydoc = Doc()
        let testText = try ydoc.getText("test")
        try testText.applyDelta([
            YEventDelta(insert: "Text"),
            YEventDelta(insert: "\n", attributes: ["title": true]),
            YEventDelta(insert: "\nText"),
            YEventDelta(insert: "\n", attributes: ["title": true]),
        ])
        
        try XCTAssertEqual(testText.toDelta(), [
            YEventDelta(insert: "Text"),
            YEventDelta(insert: "\n", attributes: ["title": true]),
            YEventDelta(insert: "\nText"),
            YEventDelta(insert: "\n", attributes: ["title": true]),
        ])
    }

    func testPreserveAttributesThroughDelete() throws {
        let ydoc = Doc()
        let testText = try ydoc.getText("test")
        
        try testText.applyDelta([
            YEventDelta(insert: "Text"),
            YEventDelta(insert: "\n", attributes: ["title": true]),
            YEventDelta(insert: "\n"),
        ])
        
        try testText.applyDelta([
            YEventDelta(retain: 4),
            YEventDelta(delete: 1),
            YEventDelta(retain: 1, attributes: ["title": true]),
        ])
        
        try XCTAssertEqual(testText.toDelta(), [
            YEventDelta(insert: "Text"),
            YEventDelta(insert: "\n", attributes: ["title": true]),
        ])
    }
    
    func testGetDeltaWithEmbeds() throws {
        let test = try YTest<Any>(docs: 1)
        let text0 = test.text[0]
        
        try text0.applyDelta([
            YEventDelta(insert: ["linebreak": "s"])
        ])
        
        try XCTAssertEqual(text0.toDelta(), [
            YEventDelta(insert: ["linebreak": "s"])
        ])
    }

    func testTypesAsEmbed() throws {
        let test = try YTest<Any>(docs: 2)
        let text0 = test.text[0], text1 = test.text[1], connector = test.connector
        
        try text0.applyDelta([
            YEventDelta(insert: ["key": "val"])
        ])
        
        XCTAssertEqualJSON(try text0.toDelta()[0].insert, ["key": "val"])
        
        var firedEvent = false
        text1.observe{ event, _ in
            let d = try event.delta()
            
            XCTAssertEqual(d.count, 1)
            XCTAssertEqualJSON(d.map{ $0.insert }, [["key": "val"]])
            
            firedEvent = true
        }
        try connector.flushAllMessages()
        let delta = try text1.toDelta()
        
        XCTAssertEqual(delta.count, 1)
        XCTAssertEqualJSON(delta[0].insert, ["key": "val"])
        XCTAssert(firedEvent, "fired the event observer containing a Type-Embed")
    }

    func testSnapshot() throws {
        let test = try YTest<Any>(docs: 1)
        let text0 = test.text[0], doc0 = test.docs[0]
        
        doc0.gc = false;
        try text0.applyDelta([
            YEventDelta(insert: "abcd"),
        ])
        let snapshot1 = Snapshot(doc: doc0)
        try text0.applyDelta([
            YEventDelta(retain: 1),
            YEventDelta(insert: "x"),
            YEventDelta(delete: 1),
        ])
        let snapshot2 = Snapshot(doc: doc0)
        try text0.applyDelta([
            YEventDelta(retain: 2),
            YEventDelta(delete: 3),
            YEventDelta(insert: "x"),
            YEventDelta(delete: 1),
        ])
        let state1 = try text0.toDelta(snapshot1)
        XCTAssertEqual(state1, [YEventDelta(insert: "abcd")])
        let state2 = try text0.toDelta(snapshot2)
        XCTAssertEqual(state2, [YEventDelta(insert: "axcd")])
        let state2Diff = try text0.toDelta(snapshot2, prevSnapshot: snapshot1)
        
        state2Diff.forEach{ v in
            if (v.attributes != nil && v.attributes!.value["ychange"] != nil) {
                // cannot do that in Swift
//                (v.attributes?.value["ychange"] as! [String: Any]).removeValue(forKey: "user")
            }
        }
        XCTAssertEqual(state2Diff, [
            YEventDelta(insert: "a" ),
            YEventDelta(insert: "x", attributes: ["ychange": ["type": "added"]]),
            YEventDelta(insert: "b", attributes: ["ychange": ["type": "removed"]]),
            YEventDelta(insert: "cd")
        ])
    }

    func testSnapshotDeleteAfter() throws {
        let test = try YTest<Any>(docs: 1)
        let text0 = test.text[0], doc0 = test.docs[0]
        
        doc0.gc = false
        try text0.applyDelta([
            YEventDelta(insert: "abcd"),
        ])
        let snapshot1 = Snapshot(doc: doc0)
        try text0.applyDelta([
            YEventDelta(retain: 4),
            YEventDelta(insert: "e"),
        ])
        let state1 = try text0.toDelta(snapshot1)
        XCTAssertEqual(state1, [YEventDelta(insert: "abcd")])
    }

    func testToJson() throws {
        let test = try YTest<Any>(docs: 1)
        let text0 = test.text[0]
        
        try text0.insert(0, text: "abc", attributes: Ref(value: ["bold": true]))
        
        XCTAssertEqualJSON(text0.toJSON(), "abc", "toJSON returns the unformatted text")
    }
    
    func testToDeltaEmbedAttributes() throws {
        let test = try YTest<Any>(docs: 1)
        let text0 = test.text[0]

        try text0.insert(0, text: "ab", attributes: Ref(value: ["bold": true]))
        try text0.insertEmbed(1, embed: ["image": "imageSrc.png"], attributes: Ref(value: ["width": 100]))
        let delta0 = try text0.toDelta()
        
        XCTAssertEqual(delta0, [
            YEventDelta(insert: "a", attributes: ["bold": true] ),
            YEventDelta(insert: ["image": "imageSrc.png"], attributes: ["width": 100]),
            YEventDelta(insert: "b", attributes: ["bold": true])
        ])
    }

    func testToDeltaEmbedNoAttributes() throws {
        let test = try YTest<Any>(docs: 1)
        let text0 = test.text[0]

        try text0.insert(0, text: "ab", attributes: Ref(value: ["bold": true]))
        try text0.insertEmbed(1, embed: ["image": "imageSrc.png"], attributes: nil)
        
        let delta0 = try text0.toDelta()
        XCTAssertEqual(delta0, [
            YEventDelta(insert: "a", attributes: ["bold": true]),
            YEventDelta(insert: ["image": "imageSrc.png"]),
            YEventDelta(insert: "b", attributes: ["bold": true])
        ], "toDelta does not set attributes key when no attributes are present")
    }


//    func testFormattingRemoved() throws {
//        let test = try YTest<Any>(docs: 1)
//        let text0 = test.text[0]
//
//        try text0.insert(0, text: "ab", attributes: Ref(value: ["bold": true]))
//        try text0.delete(0, length: 2)
//        print(text0.getChildren())
//        XCTAssertEqual(text0.getChildren().count, 1)
//    }


//    func testFormattingRemovedInMidText() throws {
//        let test = try YTest<Any>(docs: 1)
//        let text0 = test.text[0]
//
//        try text0.insert(0, "1234")
//        try text0.insert(2, "ab", ["bold": true])
//        try text0.delete(2, 2)
//        XCTAssert(text0.getChildren().length === 3)
//    }
//
//
//    func testFormattingDeltaUnnecessaryAttributeChange() throws {
//        let test = try YTest<Any>(docs: 2)
//        let connector = test.connector, text0 = test.text[0], text1 = test.text[1]
//
//        try text0.insert(0, "\n", {
//            PARAGRAPH_STYLES: "normal",
//            LIST_STYLES: "bullet"
//        })
//        try text0.insert(1, "abc", {
//            PARAGRAPH_STYLES: "normal"
//        })
//        try connector.flushAllMessages()
//        /**
//         * @type {Array<any>}
//         */
//        let deltas = [
//
//        ]
//        text0.observe(event => {
//            deltas.push(event.delta)
//        })
//        text1.observe(event => {
//            deltas.push(event.delta)
//        })
//        try text1.format(0, 1, ["LIST_STYLES": "number"])
//        try connector.flushAllMessages()
//        let filteredDeltas = deltas.filter(d => d.length > 0)
//        XCTAssert(filteredDeltas.length === 2)
//        XCTAssertEqual(filteredDeltas[0], [
//            YEventDelta(retain: 1, attributes: ["LIST_STYLES": "number"]),
//        ])
//        XCTAssertEqual(filteredDeltas[0], filteredDeltas[1])
//    }

}

extension Struct {
    var asItemRight: Struct? {
        return (self as? Item)?.right
    }
    var asItemContentString: StringContent? {
        return (self as? Item)?.content as? StringContent
    }
}
