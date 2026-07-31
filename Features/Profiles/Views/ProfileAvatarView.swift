//
//  ProfileAvatarView.swift
//  BeerStats
//
//  Rundes Namensschild eines Mitspielers: Emoji auf der Profilfarbe.
//
//  Eigene Komponente, weil derselbe Avatar an vier Stellen auftaucht –
//  Profilliste, Profil-Detail, Spielerauswahl beim neuen Spiel und später
//  im Spielscreen. Eine Änderung an der Darstellung soll überall greifen.
//

import SwiftUI

struct ProfileAvatarView: View {

    let profile: PlayerProfile
    var size: CGFloat = 48

    var body: some View {
        ZStack {
            Circle()
                .fill(profile.color.color.opacity(0.22))
            Circle()
                .strokeBorder(profile.color.color, lineWidth: 2)
            Text(profile.emoji)
                .font(.system(size: size * 0.45))
        }
        .frame(width: size, height: size)
        .opacity(profile.isActive ? 1 : 0.45)
        .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: 16) {
        ProfileAvatarView(profile: PlayerProfile(name: "Nik", emoji: "🍺", color: .amber))
        ProfileAvatarView(profile: PlayerProfile(name: "Lena", emoji: "🔥", color: .red), size: 72)
        ProfileAvatarView(profile: PlayerProfile(name: "Tom", emoji: "🎯", color: .teal))
    }
    .padding(32)
    .background(BeerStatsColor.backgroundPrimary)
}
