//
//  FriendsView.swift
//  BeerStats
//
//  Zeigt Suche, eingehende Anfragen und die bestehende Freundesliste.
//  Bewusst mit BeerStatsCard statt Standard-List umgesetzt, damit sich
//  das Design konsistent zum Rest der App anfühlt statt Standard-iOS-
//  Listen-Chrome zu übernehmen.
//

import SwiftUI

struct FriendsView: View {

    @StateObject private var viewModel: FriendsViewModel

    init(friendRepository: FriendRepositoryProtocol, currentUserId: String) {
        _viewModel = StateObject(
            wrappedValue: FriendsViewModel(friendRepository: friendRepository, currentUserId: currentUserId)
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                searchSection

                if !viewModel.incomingRequests.isEmpty {
                    section(title: "Anfragen") {
                        ForEach(viewModel.incomingRequests) { friendship in
                            incomingRequestRow(friendship)
                        }
                    }
                }

                section(title: "Freunde") {
                    if viewModel.acceptedFriends.isEmpty {
                        Text("Noch keine Freunde hinzugefügt.")
                            .font(BeerStatsFont.body)
                            .foregroundStyle(BeerStatsColor.textSecondary)
                    } else {
                        ForEach(viewModel.acceptedFriends) { friendship in
                            friendRow(friendship)
                        }
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(BeerStatsFont.caption)
                        .foregroundStyle(BeerStatsColor.error)
                }
            }
            .padding(20)
        }
        .background(BeerStatsColor.backgroundPrimary.ignoresSafeArea())
        .navigationTitle("Freunde")
    }

    // MARK: - Sections

    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Freunde finden")
                .font(BeerStatsFont.title)
                .foregroundStyle(BeerStatsColor.textPrimary)

            HStack(spacing: 8) {
                BeerStatsTextField(
                    placeholder: "Nutzername suchen",
                    text: $viewModel.searchQuery,
                    autocapitalization: .never
                )
                Button {
                    Task { await viewModel.search() }
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.headline)
                        .foregroundStyle(BeerStatsColor.textOnAccent)
                        .frame(width: 52, height: 52)
                        .background(BeerStatsColor.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(PressableButtonStyle())
            }

            if viewModel.isSearching {
                CupFillLoadingView(size: 40)
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(viewModel.searchResults) { user in
                    searchResultRow(user)
                }
            }
        }
    }

    @ViewBuilder
    private func section<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(BeerStatsFont.title)
                .foregroundStyle(BeerStatsColor.textPrimary)
            content()
        }
    }

    // MARK: - Rows

    private func searchResultRow(_ user: User) -> some View {
        BeerStatsCard {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.displayName)
                        .font(BeerStatsFont.headline)
                        .foregroundStyle(BeerStatsColor.textPrimary)
                    Text("@\(user.username)")
                        .font(BeerStatsFont.caption)
                        .foregroundStyle(BeerStatsColor.textSecondary)
                }
                Spacer()
                Button("Hinzufügen") {
                    Task { await viewModel.sendRequest(to: user) }
                }
                .font(BeerStatsFont.caption)
                .foregroundStyle(BeerStatsColor.textOnAccent)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(BeerStatsColor.accent, in: Capsule())
                .buttonStyle(PressableButtonStyle())
            }
        }
    }

    private func incomingRequestRow(_ friendship: Friendship) -> some View {
        BeerStatsCard {
            HStack {
                Text(viewModel.displayName(for: friendship))
                    .font(BeerStatsFont.headline)
                    .foregroundStyle(BeerStatsColor.textPrimary)
                Spacer()
                Button {
                    Task { await viewModel.respond(to: friendship, accept: false) }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(BeerStatsColor.error)
                }
                .buttonStyle(PressableButtonStyle())

                Button {
                    Task { await viewModel.respond(to: friendship, accept: true) }
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(BeerStatsColor.success)
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
    }

    private func friendRow(_ friendship: Friendship) -> some View {
        BeerStatsCard {
            HStack {
                Image(systemName: "person.crop.circle.fill")
                    .font(.title2)
                    .foregroundStyle(BeerStatsColor.textSecondary)
                Text(viewModel.displayName(for: friendship))
                    .font(BeerStatsFont.headline)
                    .foregroundStyle(BeerStatsColor.textPrimary)
                Spacer()
                Menu {
                    Button(role: .destructive) {
                        Task { await viewModel.removeFriend(friendship) }
                    } label: {
                        Label("Entfernen", systemImage: "person.badge.minus")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(BeerStatsColor.textSecondary)
                        .frame(width: 32, height: 32)
                }
            }
        }
    }
}
