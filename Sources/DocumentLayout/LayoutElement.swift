import CoreGraphics
import Foundation

/// 書類レイアウト解析で検出された要素。
public struct LayoutElement: Sendable, Equatable {
    /// 検出された書類要素の種類。
    public let category: Category

    /// 正規化バウンディングボックス（0.0〜1.0、原点: 左上）。
    public let boundingBox: CGRect

    /// 検出信頼度（0.0〜1.0）。
    public let confidence: Float

    public init(category: Category, boundingBox: CGRect, confidence: Float) {
        self.category = category
        self.boundingBox = boundingBox
        self.confidence = confidence
    }
}

// MARK: - Category

extension LayoutElement {
    /// DocLayNet モデルが検出する書類要素カテゴリ（11 クラス）。
    public enum Category: String, Sendable, CaseIterable {
        /// 図・表などに付属するキャプション（rawValue: `"Caption"`）。
        case caption = "Caption"
        /// ページ下部の脚注（rawValue: `"Footnote"`）。
        case footnote = "Footnote"
        /// 数式ブロック（rawValue: `"Formula"`）。
        case formula = "Formula"
        /// 箇条書きの各項目（rawValue: `"List-item"`）。
        case listItem = "List-item"
        /// ページフッター領域（rawValue: `"Page-footer"`）。
        case pageFooter = "Page-footer"
        /// ページヘッダー領域（rawValue: `"Page-header"`）。
        case pageHeader = "Page-header"
        /// 画像・図版（rawValue: `"Picture"`）。
        case picture = "Picture"
        /// 節見出し（rawValue: `"Section-header"`）。
        case sectionHeader = "Section-header"
        /// 表（rawValue: `"Table"`）。
        case table = "Table"
        /// 本文テキストブロック（rawValue: `"Text"`）。
        case text = "Text"
        /// 書類タイトル（rawValue: `"Title"`）。
        case title = "Title"

        /// 視覚要素（テキスト以外）かどうか。`picture`・`table`・`formula` が該当する。
        public var isVisual: Bool {
            switch self {
            case .picture, .table, .formula:
                true
            default:
                false
            }
        }
    }
}

// MARK: - LayoutResult

/// 単一画像に対する書類レイアウト解析結果。
public struct LayoutResult: Sendable {
    /// 垂直位置（上から下）でソート済みの検出済み要素。
    public let elements: [LayoutElement]

    public init(elements: [LayoutElement]) {
        self.elements = elements.sorted { $0.boundingBox.minY < $1.boundingBox.minY }
    }

    /// 指定カテゴリの要素を絞り込む。
    public func elements(ofCategory category: LayoutElement.Category) -> [LayoutElement] {
        elements.filter { $0.category == category }
    }

    /// 検出されたすべての図・画像要素。
    public var pictures: [LayoutElement] {
        elements(ofCategory: .picture)
    }

    /// 検出されたすべてのテーブル要素。
    public var tables: [LayoutElement] {
        elements(ofCategory: .table)
    }
}
