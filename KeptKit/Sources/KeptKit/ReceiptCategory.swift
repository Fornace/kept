import Foundation

public enum ReceiptCategory: String, Codable, Sendable, CaseIterable, Identifiable {
    case electronics
    case appliances
    case clothing
    case home
    case health
    case travel
    case food
    case other

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .electronics: "Electronics"
        case .appliances: "Appliances"
        case .clothing: "Clothing"
        case .home: "Home"
        case .health: "Health"
        case .travel: "Travel"
        case .food: "Food"
        case .other: "Other"
        }
    }

    public var symbol: String {
        switch self {
        case .electronics: "laptopcomputer"
        case .appliances: "washer"
        case .clothing: "tshirt"
        case .home: "sofa"
        case .health: "cross.case"
        case .travel: "airplane"
        case .food: "fork.knife"
        case .other: "shippingbox"
        }
    }

    /// Warranty length most stores in this category offer, in months.
    public var typicalWarranty: Int? {
        switch self {
        case .electronics: 24
        case .appliances: 24
        case .home: 24
        case .health: 12
        case .travel: 12
        case .clothing: nil
        case .food: nil
        case .other: 12
        }
    }

    /// Return window most stores in this category offer, in days.
    public var typicalReturnDays: Int? {
        switch self {
        case .clothing: 30
        case .electronics: 14
        case .appliances: 14
        case .home: 30
        case .health: 14
        case .travel: 14
        case .food: nil
        case .other: 14
        }
    }
}
