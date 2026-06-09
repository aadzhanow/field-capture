//
//  ItemCard.swift
//

import SwiftUI

struct ItemCard: View {
    let item: ItemListItem
    let fileStorage: FileStorage

    var body: some View {
        HStack(spacing: 12) {
            AsyncImageView(
                relativePaths: item.representativeImagePaths,
                fileStorage: fileStorage,
                targetPixelSize: 200
            )
            .frame(width: 64, height: 64)
            .clipShape(.rect(cornerRadius: 10))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                    .lineLimit(1)
                
                Text("^[\(item.photoCount) photo](inflect: true) · \(item.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                StatusBadge.forItemListItem(item)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}
