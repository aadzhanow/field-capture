//
//  ItemListSection.swift
//

import Foundation

struct ItemListSection: Identifiable, Equatable {
    let id: String
    let title: String
    let items: [ItemListItem]
}

extension ItemListSection {
    static func group(_ items: [ItemListItem]) -> [ItemListSection] {
        let calendar = Calendar.current
        let byDay = Dictionary(grouping: items) { calendar.startOfDay(for: $0.createdAt) }
        return byDay.keys.sorted(by: >).map { day in
            ItemListSection(
                id: String(day.timeIntervalSince1970),
                title: title(for: day, calendar: calendar),
                items: (byDay[day] ?? []).sorted { $0.createdAt > $1.createdAt }
            )
        }
    }

    private static func title(for day: Date, calendar: Calendar) -> String {
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.month(.wide).day().year())
    }
}
