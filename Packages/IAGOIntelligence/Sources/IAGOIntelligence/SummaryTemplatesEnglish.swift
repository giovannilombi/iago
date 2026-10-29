import Foundation

extension SummaryLibrary {
    static let englishNextSteps = S(
        "Next steps", "What will be done after the meeting and who does it.", columns: ["Who", "What", "By"])

    /// The library in English (ADR-0077): same ids, order and sections as `all`, for an app in English.
    public static let englishLibrary: [SummaryTemplate] = [
        .init(
            id: "standard", name: "Standard meeting",
            description: "For general meetings: outcomes, decisions and tasks.", basedOn: "Meetily",
            sections: [
                S("Decisions", "The decisions made during the meeting."),
                S("Tasks", "The tasks assigned, with who does them and by when.", columns: ["Who", "What", "By"]),
                S("Highlights", "The main themes, topics and important observations."),
            ]),
        .init(
            id: "oneOnOne", name: "1:1", description: "One-on-one meetings with a team member.",
            basedOn: "Hyprnote",
            sections: [
                S("Updates", "What has happened since last time."),
                S("Wins and challenges", "Achievements to recognize and obstacles encountered."),
                S("Goals and progress", "The current goals and where they stand."),
                S("Feedback", "Feedback given and received, in both directions."),
                S("Commitments", "What each person commits to do.", columns: ["Who", "What", "By"]),
            ]),
        .init(
            id: "kickoff", name: "Kickoff",
            description: "Start of a project or an engagement with a client: goals and alignment.",
            basedOn: "Hyprnote",
            sections: [
                S("Overview", "Scope, goals and deliverables of the project.", .paragraph),
                S("Success criteria", "How it will be clear that the project has succeeded."),
                S(
                    "People and roles", "Who takes part and with what role or responsibility.",
                    columns: ["Person", "Role"]),
                S("Timeline and milestones", "The main dates and milestones.", columns: ["Milestone", "Date"]),
                S("Risks and dependencies", "Risks, constraints and things the project depends on."),
                S("How we keep in touch", "Meeting frequency and way of communicating."),
                englishNextSteps,
            ]),
        .init(
            id: "projectSync", name: "Project status update",
            description: "Regular meetings on the project status: milestones, risks, decisions.", basedOn: "Meetily",
            sections: [
                S("Progress", "What has been done since the last update.", .paragraph),
                S(
                    "Milestones and status", "The milestones with their status and expected date.",
                    columns: ["Milestone", "Status", "Forecast"]),
                S(
                    "Risks and mitigations", "The main risks, their impact, what is being done and who handles it.",
                    columns: ["Risk", "Impact", "Mitigation", "Who"]),
                S("Decisions", "The decisions made and the reason.", columns: ["Decision", "Reason"]),
                S("Tasks", "The tasks, with who does them and by when.", columns: ["Who", "What", "By"]),
                S("Documents mentioned", "Documents, files or materials mentioned during the meeting."),
            ]),
        .init(
            id: "brainstorming", name: "Workshop / brainstorming",
            description: "Creative and ideation sessions.", basedOn: "Hyprnote",
            sections: [
                S("Session goal", "Which problem or opportunity is being explored.", .paragraph),
                S("Ideas raised", "All the ideas proposed, grouped by theme."),
                S("Most promising ideas", "The ideas worth exploring further."),
                S("Criteria to evaluate them", "How it was decided to evaluate the ideas."),
                englishNextSteps,
            ]),
        .init(
            id: "designReview", name: "Review / demo",
            description: "Presentation of a piece of work (design, prototype, solution) and collection of feedback.",
            basedOn: "Hyprnote",
            sections: [
                S("What was presented", "The work shown and the proposed solution.", .paragraph),
                S("Alternatives considered", "Other options evaluated and why they were rejected."),
                S("Feedback", "The comments received, point by point.", columns: ["Point", "Feedback", "Who"]),
                S("Requested changes", "What needs to be changed."),
                S("Approved and to revisit", "What is approved and what remains open."),
                englishNextSteps,
            ]),
        .init(
            id: "clientSales", name: "Client / Sales",
            description: "Sales meetings with clients or prospects.",
            basedOn: "Meetily, Hyprnote",
            sections: [
                S("Client context", "Who the client is and their situation.", .paragraph),
                S("Current situation and problems", "How they work today and which problems they want to solve."),
                S("Goals and success criteria", "What they want to achieve and how they will measure the result."),
                S(
                    "Agreed deliverables", "What has been agreed to deliver.",
                    columns: ["Deliverable", "Who", "By"]),
                S("Budget, timing and terms", "Prices, timing, contractual or payment terms mentioned."),
                S("Objections and concerns", "The client's concerns or objections."),
                S("Competitors mentioned", "Other suppliers or solutions mentioned."),
                englishNextSteps,
            ]),
        .init(
            id: "customerDiscovery", name: "Customer discovery",
            description: "Interviews with customers or users to understand needs and problems.", basedOn: "Hyprnote",
            sections: [
                S("Context", "Who the interviewee is and their context.", .paragraph),
                S("How they do it today", "How they solve the problem today."),
                S("Problems", "Difficulties and frustrations described."),
                S("Needs and goals", "What they would like to achieve."),
                S("Reactions to the proposal", "How they reacted to the proposed solutions, if any were presented."),
                S("What we learned", "The main findings of the interview."),
            ]),
        .init(
            id: "sprintPlanning", name: "Sprint planning",
            description: "Planning of a sprint and its goals.", basedOn: "Hyprnote",
            sections: [
                S("Sprint goal", "The main goal of the sprint.", .paragraph),
                S("Work committed", "Stories and tasks of the sprint.", columns: ["Work", "Who"]),
                S("Availability", "Team availability and capacity."),
                S("Dependencies and risks", "External dependencies and risks."),
                S("Definition of \"done\"", "The criteria for considering the work finished."),
            ]),
        .init(
            id: "dailyStandup", name: "Daily standup", description: "Short daily team update.",
            basedOn: "Meetily, Hyprnote",
            sections: [
                S("Done yesterday", "What each person completed.", columns: ["Who", "Done"]),
                S("Plan for today", "What each person is working on today.", columns: ["Who", "Today"]),
                S("Blockers", "Obstacles and who can help.", columns: ["Who", "Blocker"]),
                S("Announcements", "Announcements or information for everyone."),
            ]),
        .init(
            id: "retrospective", name: "Retrospective",
            description: "End of a sprint, phase or project: what worked and what to change.",
            basedOn: "Meetily, Hyprnote",
            sections: [
                S("What went well", "Successes and things to keep doing."),
                S("What didn't go well", "Problems and things to stop doing."),
                S(
                    "What to start doing", "New practices or experiments proposed.",
                    columns: ["Idea", "Proposed by"]),
                S("What we learned", "The main lessons."),
                S("Actions", "The concrete actions, with who does them.", columns: ["Who", "Action", "By"]),
            ]),
        .init(
            id: "boardMeeting", name: "Board meeting", description: "Board and company governance meetings.",
            basedOn: "Hyprnote",
            sections: [
                S("Performance", "Updates on results and operations.", .paragraph),
                S("Strategic initiatives", "Where the strategic priorities stand."),
                S("Finances", "Budget, cash and financial health."),
                S("Resolutions", "The decisions and resolutions adopted."),
                S("Risks and compliance", "Risks and compliance obligations."),
                englishNextSteps,
            ]),
        .init(
            id: "executiveBriefing", name: "Executive briefing",
            description: "Strategic leadership discussions.", basedOn: "Hyprnote",
            sections: [
                S("Strategic picture", "Context and goals.", .paragraph),
                S("Key figures", "Indicators and trends mentioned."),
                S("Decisions", "Strategic decisions and their reasons."),
                S("Resources", "Budget and people allocated."),
                S("Risks and opportunities", "Strategic risks and growth opportunities."),
                S("Actions", "The actions decided, with who follows them up.", columns: ["Who", "Action"]),
            ]),
        .init(
            id: "investorPitch", name: "Investor pitch", description: "Presentations to investors.",
            basedOn: "Hyprnote",
            sections: [
                S("Context", "Who the investor is and the purpose of the meeting.", .paragraph),
                S("What was presented", "The main points of the presentation."),
                S("Questions", "The investor's questions and doubts."),
                S("Feedback", "Reactions and comments."),
                S("Interest", "Level of interest and next steps indicated."),
                S("Things to send", "Information requested and actions.", columns: ["What", "By"]),
            ]),
        .init(
            id: "performanceReview", name: "Performance review",
            description: "Evaluations and growth conversations.", basedOn: "Hyprnote",
            sections: [
                S("Period", "The period under review, in brief.", .paragraph),
                S("Results", "The main results and contributions."),
                S("Strengths", "Skills and behaviors to maintain."),
                S("Growth areas", "Where to improve."),
                S("Career goals", "Aspirations and career path."),
                S("Plan", "Development goals and next steps.", columns: ["Goal", "By"]),
            ]),
        .init(
            id: "incidentPostmortem", name: "Incident postmortem",
            description: "Blameless analysis of an incident or outage.", basedOn: "Hyprnote",
            sections: [
                S("What happened", "The incident and when it occurred.", .paragraph),
                S("Timeline", "The sequence of events.", columns: ["When", "Event"]),
                S("Cause", "What caused the incident."),
                S("Impact", "Effects on users and operations."),
                S("Resolution", "How it was resolved."),
                S("Lessons", "What was learned."),
                S("Preventive actions", "What is being done to prevent it.", columns: ["Who", "Action", "By"]),
            ]),
        .init(
            id: "roadmapReview", name: "Roadmap review",
            description: "Product priorities and roadmap.", basedOn: "Hyprnote",
            sections: [
                S("Current status", "Where the ongoing initiatives stand.", .paragraph),
                S("Upcoming features", "Priorities and timing for the next period."),
                S("Customer feedback", "What users and customers say."),
                S("Metrics", "Indicators and how they are measured."),
                S("Decisions", "Decisions and trade-offs."),
            ]),
        .init(
            id: "lectureNotes", name: "Training", description: "Courses, lectures and webinars.", basedOn: "Hyprnote",
            sections: [
                S("Topic", "Course, subject and speaker.", .string),
                S("Key concepts", "The main ideas explained."),
                S("Definitions", "Terms to remember."),
                S("Examples", "Examples and practical applications."),
                S("Open questions", "Questions that remain open."),
            ]),
    ]
}
