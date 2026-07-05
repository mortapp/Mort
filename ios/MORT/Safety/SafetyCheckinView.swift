//
//  SafetyCheckInView.swift
//  MORT
//
//  Teen safety check-in + trusted circle / guardian link.
//

import SwiftUI

struct SafetyCheckInView: View {
    @Environment(\.services) private var services
    @Environment(SessionStore.self) private var session

    @State private var note = ""
    @State private var contacts: [TrustedContact] = []
    @State private var guardians: [GuardianLink] = []
    @State private var lastStatus: CheckInStatus?
    @State private var sending = false
    @State private var showAddContact = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: MortSpacing.md) {
                    MortSafetyBanner(staticMessage: "Check in so your trusted circle knows you're safe. If you ever feel unsafe, tap Needs help.")

                    checkInCard
                    trustedCircleCard
                    guardianCard
                }
                .padding(MortSpacing.md)
                .padding(.bottom, MortSpacing.xl)
            }
            .mortScreen()
            .safeAreaInset(edge: .top) {
                MortTopBar(title: "Safety", subtitle: "Check in and stay connected")
                    .background(MortColor.background)
            }
            .task { await load() }
            .sheet(isPresented: $showAddContact) {
                AddTrustedContactView { await load() }
            }
        }
    }

    private var checkInCard: some View {
        MortCard {
            VStack(alignment: .leading, spacing: MortSpacing.sm) {
                Text("Check in").font(MortFont.headline()).foregroundStyle(MortColor.primaryText)
                if let lastStatus {
                    MortBadge(text: "Last: \(lastStatus.label)", color: color(for: lastStatus), systemImage: "clock.fill")
                }
                MortTextField(title: "Note (optional)", text: $note, placeholder: "e.g. Arrived at the job safely", autocapitalization: .sentences)

                HStack(spacing: MortSpacing.sm) {
                    statusButton(.safe, "checkmark.circle.fill", MortColor.success)
                    statusButton(.enRoute, "figure.walk", MortColor.warning)
                    statusButton(.needsHelp, "exclamationmark.triangle.fill", MortColor.danger)
                }
            }
        }
    }

    private func statusButton(_ status: CheckInStatus, _ icon: String, _ color: Color) -> some View {
        Button {
            Task { await checkIn(status) }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 18, weight: .semibold))
                Text(status.label).font(MortFont.tiny())
            }
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, MortSpacing.sm)
            .background(color.opacity(0.12))
            .clipShape(.rect(cornerRadius: MortRadius.sm))
        }
        .buttonStyle(.plain)
        .disabled(sending)
    }

    private var trustedCircleCard: some View {
        MortCard {
            VStack(alignment: .leading, spacing: MortSpacing.sm) {
                HStack {
                    Text("Trusted circle").font(MortFont.headline()).foregroundStyle(MortColor.primaryText)
                    Spacer()
                    Button { showAddContact = true } label: {
                        Image(systemName: "plus.circle.fill").foregroundStyle(MortColor.roseGold)
                    }
                }
                if contacts.isEmpty {
                    Text("Add people you trust, like a parent or coach.")
                        .font(MortFont.caption()).foregroundStyle(MortColor.secondaryText)
                } else {
                    ForEach(contacts) { contact in
                        HStack(spacing: MortSpacing.sm) {
                            MortAvatar(name: contact.name, size: 36)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(contact.name).font(MortFont.callout()).foregroundStyle(MortColor.primaryText)
                                Text(contact.relationship).font(MortFont.caption()).foregroundStyle(MortColor.secondaryText)
                            }
                            Spacer()
                        }
                    }
                }
            }
        }
    }

    private var guardianCard: some View {
        MortCard {
            VStack(alignment: .leading, spacing: MortSpacing.sm) {
                Text("Guardian link").font(MortFont.headline()).foregroundStyle(MortColor.primaryText)
                if guardians.isEmpty {
                    Text("No guardian linked yet.").font(MortFont.caption()).foregroundStyle(MortColor.secondaryText)
                } else {
                    ForEach(guardians) { link in
                        HStack(spacing: MortSpacing.sm) {
                            Image(systemName: "shield.lefthalf.filled").foregroundStyle(MortColor.success)
                            Text("Linked to \(link.guardianName)").font(MortFont.callout()).foregroundStyle(MortColor.silver)
                            Spacer()
                        }
                    }
                }
            }
        }
    }

    private func color(for status: CheckInStatus) -> Color {
        switch status {
        case .safe: return MortColor.success
        case .enRoute: return MortColor.warning
        case .needsHelp: return MortColor.danger
        case .unknown: return MortColor.darkSilver
        }
    }

    private func load() async {
        guard let me = session.profile else { return }
        contacts = (try? await services.safety.trustedContacts(for: me.id)) ?? []
        guardians = (try? await services.safety.guardianLinks(forTeen: me.id)) ?? []
    }

    private func checkIn(_ status: CheckInStatus) async {
        guard let me = session.profile else { return }
        sending = true
        let ping = SafetyPing(teenId: me.id, teenName: me.displayName, status: status, note: note)
        try? await services.safety.checkIn(ping)
        lastStatus = status
        note = ""
        sending = false
    }
}

struct AddTrustedContactView: View {
    @Environment(\.services) private var services
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss

    var onAdded: () async -> Void

    @State private var name = ""
    @State private var relationship = ""
    @State private var saving = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: MortSpacing.md) {
                    MortTextField(title: "Name", text: $name, placeholder: "e.g. Mom", autocapitalization: .words)
                    MortTextField(title: "Relationship", text: $relationship, placeholder: "e.g. Parent, Coach", autocapitalization: .words)
                    MortButton(title: "Add to trusted circle", isLoading: saving, isDisabled: name.trimmingCharacters(in: .whitespaces).isEmpty) {
                        Task { await add() }
                    }
                }
                .padding(MortSpacing.md)
            }
            .background(MortColor.background.ignoresSafeArea())
            .navigationTitle("Add contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(MortColor.roseGold)
                }
            }
        }
    }

    private func add() async {
        guard let me = session.profile else { return }
        saving = true
        let contact = TrustedContact(name: name, relationship: relationship.isEmpty ? "Trusted contact" : relationship)
        try? await services.safety.addTrustedContact(contact, for: me.id)
        await onAdded()
        saving = false
        dismiss()
    }
}

