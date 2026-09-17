//
//  AuthEntryView.swift
//  MORT iOS V8 — Auth
//
//  The entry moment: the wordmark writes itself over the living atmosphere.
//  Authentication is backend-authoritative — nothing here invents a session.
//

import SwiftUI

struct AuthEntryView: View {
    @Environment(MortSession.self) private var session
    @Environment(MortSettingsStore.self) private var settings

    @State private var showSignIn = false
    @State private var showCreate = false

    var body: some View {
        ZStack {
            MortAtmosphere()

            VStack(spacing: 0) {
                Spacer(minLength: MortSpace.s10)

                VStack(spacing: MortSpace.s5) {
                    MortWordmark(animateIntro: !settings.wordmarkPlayed)
                        .frame(width: 236, height: 88)
                    Text("GET IN MOTION")
                        .font(.system(size: 11, weight: .medium))
                        .tracking(6)
                        .foregroundStyle(MortColor.textMuted)
                }

                Spacer(minLength: MortSpace.s8)

                VStack(alignment: .leading, spacing: MortSpace.s4) {
                    Text("Real work. Real pay.\nRight in your neighborhood.")
                        .mortH1()
                        .fixedSize(horizontal: false, vertical: true)
                    Text("MORT connects teens who want to work with neighbors who need help — with payment, safety and guardians built in from the start.")
                        .mortBody()
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .mortScreenPadding()

                Spacer(minLength: MortSpace.s6)

                VStack(spacing: MortSpace.s3) {
                    MortPrimaryButton(title: "Get started", symbol: "arrow.right") {
                        showCreate = true
                    }
                    MortGhostButton(title: "I already have an account") {
                        showSignIn = true
                    }
                }
                .mortScreenPadding()
                .padding(.bottom, MortSpace.s6)
            }

            MortAtmosphereForeground()
        }
        .onAppear { settings.wordmarkPlayed = true }
        .sheet(isPresented: $showSignIn) {
            NavigationStack { SignInView() }
        }
        .sheet(isPresented: $showCreate) {
            NavigationStack { CreateAccountView() }
        }
    }
}

#Preview {
    AuthEntryView()
        .environment(MortDependencies.preview(signedIn: false).session)
        .environment(MortSettingsStore())
        .environment(\.mort, MortDependencies.preview(signedIn: false))
}
