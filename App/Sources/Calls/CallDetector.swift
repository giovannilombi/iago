import AppKit
import Foundation
import IAGOCapture
import IAGOCore
import IAGOStore
import Observation
import UserNotifications
import os

/// Puts the call sources together (ADR-0051): Teams' local API, call apps using the microphone, the Mac's Calendar.
/// When a call starts and IAGO is not recording it asks (or records, as the user chose), with the meeting title as
/// tentative title; while recording it follows Teams' mute; at the end of a call it offers to stop. Never stops a
/// recording by itself.
@MainActor
@Observable
final class CallDetector: NSObject, UNUserNotificationCenterDelegate {
    enum Behaviour: String, CaseIterable { case ask, record, nothing }

    let teams: TeamsLocalAPI
    /// Teams' mute through macOS Accessibility, where the local API is blocked (user's choice in Settings).
    let teamsAX: TeamsAccessibility
    let calendar: MeetingCalendar
    /// IAGO's own panels for the proposals (always visible buttons, persistent, stacked).
    let prompts = CallPrompts()
    private let recorder: RecordingController
    private let archive: Archive
    private let logger = Logger(subsystem: "com.giovannilombi.iago", category: "calls")

    /// Starts a recording as the menu bar does (permission, voice notes); true if it started.
    var startRecording: (() async -> Bool)?
    var stopRecording: (() async -> Void)?
    /// A click on the morning notification (ADR-0074): opens «Inbox».
    var openInbox: (() -> Void)?

    /// A call is going on: its app, tentative title and, when IAGO is not sure, the meetings it may be.
    private(set) var call: (app: String, title: String, alternatives: [String])?
    /// The proposal waiting for an answer, also shown in the menu bar.
    private(set) var pendingProposal: String?
    /// What the detector sees now and what it last did, for Settings (diagnosis without logs of content).
    private(set) var liveStatus = ""
    private(set) var lastEvent: String?
    /// Notifications allowed for IAGO by macOS.
    private(set) var notificationsAllowed: Bool?
    @ObservationIgnored private var micSince: Date?
    @ObservationIgnored private var callEndedAt: Date?
    @ObservationIgnored private var dismissedCall = false
    @ObservationIgnored private var startedByDetector = false
    @ObservationIgnored private var askedEnd = false
    @ObservationIgnored private var promptedMeetings: Set<String> = []
    @ObservationIgnored private var lastMuted: Bool?
    @ObservationIgnored private var titledItem: ItemID?
    /// The title the user chose from a proposal, for the recording it starts.
    @ObservationIgnored private var acceptedTitle: String?
    @ObservationIgnored private var callStartedAt = Date()
    @ObservationIgnored private var loop: Task<Void, Never>?

    static let behaviourKey = "calls.behaviour"
    static let category = "iago.call"

    init(archive: Archive, recorder: RecordingController) {
        self.archive = archive
        self.recorder = recorder
        teams = TeamsLocalAPI(archive: archive)
        teamsAX = TeamsAccessibility(archive: archive)
        calendar = MeetingCalendar(archive: archive)
        super.init()
    }

    var behaviour: Behaviour {
        get { (try? archive.setting(Self.behaviourKey)).flatMap { $0 }.flatMap(Behaviour.init(rawValue:)) ?? .ask }
        set { try? archive.setSetting(Self.behaviourKey, newValue.rawValue) }
    }

    func start() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        let record = UNNotificationAction(identifier: "record", title: String(localized: "Registra"), options: [])
        let stop = UNNotificationAction(identifier: "stop", title: String(localized: "Ferma"), options: [])
        let later = UNNotificationAction(identifier: "later", title: String(localized: "Non ora"), options: [])
        center.setNotificationCategories([
            UNNotificationCategory(identifier: Self.category, actions: [record, later], intentIdentifiers: []),
            UNNotificationCategory(identifier: Self.category + ".stop", actions: [stop, later], intentIdentifiers: []),
        ])
        teams.start()
        guard loop == nil else { return }
        loop = Task { [weak self] in
            while !Task.isCancelled {
                await self?.tick()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    // MARK: Watching

    private func tick() async {
        let snapshot = await recorder.snapshot()
        let recording = snapshot.state != .idle
        let apps = CallActivity.current()
        teamsAX.poll(teamsUsesMic: apps.contains { $0.name == "Teams" })
        micSince = apps.isEmpty ? nil : (micSince ?? Date())
        let micCall = micSince.map { Date().timeIntervalSince($0) >= 5 } ?? false
        let teamsInMeeting = teams.isInMeeting || teamsAX.buttonFound
        let inCall = teamsInMeeting || micCall
        let app = teamsInMeeting ? "Teams" : apps.first?.name
        if let since = micSince, let name = apps.first?.name {
            liveStatus = String(localized: "\(name) usa il microfono da \(Int(Date().timeIntervalSince(since))) s")
        } else if teamsInMeeting {
            liveStatus =
                teamsAX.isMuted == true || teams.isMuted
                ? String(localized: "Teams: in riunione, microfono spento") : String(localized: "Teams: in riunione")
        } else {
            liveStatus = String(localized: "Nessuna app di call usa il microfono")
        }

        if inCall {
            callEndedAt = nil
            if call == nil {
                let name = app ?? "Teams"
                callStartedAt = Date()
                let (title, alternatives) = resolveTitle(app: name)
                call = (name, title, alternatives)
                let time = Date().formatted(date: .omitted, time: .shortened)
                lastEvent =
                    recording
                    ? String(localized: "Call \(name) rilevata alle \(time), mentre stavi già registrando")
                    : String(localized: "Call \(name) rilevata alle \(time)")
                logger.notice("Call detected: \(app ?? "Teams", privacy: .public), recording: \(recording)")
                dismissedCall = false
                askedEnd = false
                if !recording { await callStarted() }
            }
        } else if call != nil {
            callEndedAt = callEndedAt ?? Date()
            if let ended = callEndedAt, Date().timeIntervalSince(ended) >= 30 {
                // Any recording going on when the call ends: started from a proposal or by hand.
                if recording, !askedEnd {
                    askedEnd = true
                    prompts.show(
                        .init(
                            id: "ended", title: String(localized: "La call è finita"),
                            message: String(localized: "Fermo la registrazione di «\(call?.title ?? "")»?"),
                            primary: String(localized: "Ferma"), onPrimary: { [weak self] in self?.stop() },
                            onIgnore: {}))
                }
                call = nil
                pendingProposal = nil
                acceptedTitle = nil
                startedByDetector = false
            }
        }

        // The meeting title goes on the recording, however it was started, once per recording: the one the user
        // chose, or the meeting going on now (the call may have changed since it was detected).
        if recording, let current = call, let itemID = snapshot.itemID, titledItem != itemID {
            titledItem = itemID
            if let chosen = acceptedTitle {
                acceptedTitle = nil
                await recorder.setSuggestedTitle(chosen)
            } else {
                let (title, alternatives) = resolveTitle(app: current.app)
                call = (current.app, title, alternatives)
                await recorder.setSuggestedTitle(title)
                if !alternatives.isEmpty { askWhichMeeting(app: current.app, alternatives: alternatives) }
            }
        }
        // ADR-0051: muted in Teams (local API, or Accessibility where the API is blocked) → silence on the mic track.
        let mutedInTeams = (teams.isInMeeting && teams.isMuted) || teamsAX.isMuted == true
        let muted = recording && mutedInTeams
        if muted != lastMuted {
            lastMuted = muted
            await recorder.setMicMuted(muted)
        }
        await calendarStarts(recording: recording)
    }

    /// The meeting a call is (`MeetingMatcher`): the title, and the choices when IAGO is not sure, last one
    /// "another call" with the generic title.
    private func resolveTitle(app: String) -> (String, [String]) {
        let generic = String(
            localized: "Call \(app) del \(callStartedAt.formatted(date: .abbreviated, time: .shortened))")
        let match = MeetingMatcher.match(
            calendar.candidates(), callStart: callStartedAt, windowTitles: teamsAX.windowTitles())
        guard let meeting = match.meeting else { return (generic, []) }
        if match.isSure { return (meeting.title, []) }
        var titles: [String] = []
        for title in match.alternatives.map(\.title) where !titles.contains(title) { titles.append(title) }
        return (meeting.title, titles + [generic])
    }

    /// "Quale riunione stai registrando?": the recording has the best guess as title until the user chooses.
    private func askWhichMeeting(app: String, alternatives: [String]) {
        prompts.show(
            .init(
                id: "which", title: String(localized: "Quale riunione stai registrando?"),
                message: String(localized: "C'è più di una riunione in corso nel Calendario. Scegli il titolo:"),
                primary: "", onPrimary: {}, onIgnore: {}, choices: alternatives,
                onChoice: { [weak self] title in
                    guard let self else { return }
                    if let current = call { call = (current.app, title, []) }
                    Task { await self.recorder.setSuggestedTitle(title) }
                }))
    }

    private func callStarted() async {
        guard let call else { return }
        switch behaviour {
        case .nothing: return
        case .record:
            acceptedTitle = call.title
            if await startRecording?() == true {
                startedByDetector = true
                await recorder.setSuggestedTitle(call.title)
                if !call.alternatives.isEmpty { askWhichMeeting(app: call.app, alternatives: call.alternatives) }
                prompts.show(
                    .init(
                        id: "started", title: String(localized: "Registrazione avviata"),
                        message: String(localized: "«\(call.title)»: IAGO registra la call."),
                        primary: String(localized: "Ferma"), onPrimary: { [weak self] in self?.stop() },
                        onIgnore: {}))
            }
        case .ask:
            pendingProposal = call.title
            if call.alternatives.isEmpty {
                prompts.show(
                    .init(
                        id: "call", title: String(localized: "Sei in una call \(call.app)"),
                        message: String(localized: "Avvio la registrazione di «\(call.title)»?"),
                        primary: String(localized: "Registra"),
                        onPrimary: { [weak self] in self?.acceptProposal(title: call.title) },
                        onIgnore: { [weak self] in self?.dismissProposal() }))
            } else {
                // Not sure which meeting: one button per meeting, each starts the recording with its title.
                prompts.show(
                    .init(
                        id: "call", title: String(localized: "Sei in una call \(call.app)"),
                        message: String(localized: "Avvio la registrazione? Scegli la riunione:"),
                        primary: "", onPrimary: {}, onIgnore: { [weak self] in self?.dismissProposal() },
                        choices: call.alternatives,
                        onChoice: { [weak self] title in self?.acceptProposal(title: title) }))
            }
        }
    }

    /// "Sta per iniziare «…»" at the start time of each calendar meeting with a call link, before joining it:
    /// overlapping meetings get one panel each, so the user picks the one to record.
    private func calendarStarts(recording: Bool) async {
        guard !recording, behaviour != .nothing else { return }
        for meeting in calendar.starting() where promptedMeetings.insert(meeting.id).inserted {
            pendingProposal = meeting.title
            let title = meeting.title
            prompts.show(
                .init(
                    id: meeting.id, title: String(localized: "Sta per iniziare «\(title)»"),
                    message: String(
                        localized:
                            "\(meeting.start.formatted(date: .omitted, time: .shortened))–\(meeting.end.formatted(date: .omitted, time: .shortened)). Avvio la registrazione?"
                    ),
                    primary: String(localized: "Registra"),
                    onPrimary: { [weak self] in self?.acceptProposal(title: title) },
                    onIgnore: { [weak self] in self?.dismissProposal() }))
        }
    }

    // MARK: Answers

    /// "Registra" from a panel or the menu bar; the meeting title goes on the recording.
    func acceptProposal(title: String? = nil) {
        let title = title ?? pendingProposal ?? call?.title
        pendingProposal = nil
        acceptedTitle = title
        prompts.closeAll()
        Task {
            if await startRecording?() == true {
                startedByDetector = true
                if let title { await recorder.setSuggestedTitle(title) }
            }
        }
    }

    func dismissProposal() {
        pendingProposal = nil
        dismissedCall = true
    }

    private func stop() {
        Task { await stopRecording?() }
    }

    /// "Invia una notifica di prova": also makes macOS ask for the permission the first time.
    /// "Mostra un esempio": what a proposal to record looks like, without recording anything.
    func showExamplePrompt() {
        prompts.show(
            .init(
                id: "example", title: String(localized: "Sta per iniziare «Riunione di esempio»"),
                message: String(localized: "15:00–15:30. Avvio la registrazione?"),
                primary: String(localized: "Registra"),
                onPrimary: {}, onIgnore: {}))
    }

    func testNotification() {
        post(String(localized: "Notifica di prova"), String(localized: "Le notifiche di IAGO funzionano."), stop: false)
    }

    private func post(_ title: String, _ body: String, stop: Bool) {
        Task {
            let center = UNUserNotificationCenter.current()
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
            let settings = await center.notificationSettings()
            notificationsAllowed = settings.authorizationStatus == .authorized && settings.alertSetting == .enabled
            if notificationsAllowed == false { logger.notice("Call proposal not shown: notifications are off") }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.categoryIdentifier = stop ? Self.category + ".stop" : Self.category
            try? await center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse
    ) async {
        let action = response.actionIdentifier
        let category = response.notification.request.content.categoryIdentifier
        await MainActor.run {
            switch action {
            case "record": acceptProposal()
            case "stop": Task { await stopRecording?() }
            case "later": dismissProposal()
            case UNNotificationDefaultActionIdentifier where category == Self.category: acceptProposal()
            case UNNotificationDefaultActionIdentifier where category == WorkReminder.category: openInbox?()
            default: break
            }
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
