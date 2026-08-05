//
//  ContentView.swift
//  SoulMark
//

import SwiftUI

enum AppSection: Hashable, CaseIterable {
    case home
    case relationshipGraph
    case scenarioSimulation
    case journal
    case profile

    var title: String {
        let isEnglish = SoulPreferencesStore.shared.language == "en"
        return switch self {
        case .home: isEnglish ? "Home" : "首页"
        case .relationshipGraph: isEnglish ? "Map" : "图谱"
        case .scenarioSimulation: isEnglish ? "Practice" : "模拟"
        case .journal: isEnglish ? "Review" : "复盘"
        case .profile: isEnglish ? "Me" : "我的"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "square.grid.2x2.fill"
        case .relationshipGraph: "point.3.connected.trianglepath.dotted"
        case .scenarioSimulation: "waveform.and.mic"
        case .journal: "text.quote"
        case .profile: "person.crop.circle.fill"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var session: AppSession
    @State private var selectedSection: AppSection = .home
    @State private var selectedFilter: RelationshipFilter = .all
    @State private var selectedCustomCategory: RelationshipCategory?
    @State private var selectedPerson: RelationshipPerson?
    @State private var people: [RelationshipPerson] = []
    @State private var customCategories: [RelationshipCategory] = []
    @State private var isAddingPerson = false
    @State private var isAddingRelationship = false
    @State private var pendingDeletedCategory: RelationshipCategory?
    @State private var deletedCategories: Set<RelationshipCategory> = []
    @State private var graphLayoutRevision = UUID()
    @State private var scenarioFocusedPersonID: RelationshipPerson.ID?
    @State private var showingRelationshipCategories = false
    @State private var showingMembershipUpgrade = false
    @State private var practiceCount = 0
    @State private var reviewCount = 0
    @State private var relationshipErrorMessage: String?

    private var availableCategories: [RelationshipCategory] {
        RelationshipCategory.builtIns.filter { !deletedCategories.contains($0) } + customCategories
    }

    private var availableFilters: [RelationshipFilter] {
        RelationshipFilter.allCases.filter { filter in
            guard let category = filter.category else { return true }
            return !deletedCategories.contains(category)
        }
    }

    private var visiblePeople: [RelationshipPerson] {
        if let selectedCustomCategory {
            return selectedCustomCategory.filteredPeople(from: people)
        }
        return selectedFilter.filteredPeople(from: people)
    }

    private var achievementProgress: AchievementProgress {
        AchievementProgress(
            peopleCount: people.count,
            practiceCount: practiceCount,
            reviewCount: reviewCount,
            relationshipCategoryCount: Set(people.map(\.category)).count
        )
    }

    var body: some View {
        TabView(selection: $selectedSection) {
            ForEach(AppSection.allCases, id: \.self) { section in
                page(for: section)
                    .tag(section)
                    .tabItem {
                        Label(section.title, systemImage: section.systemImage)
                    }
            }
        }
        .tint(SoulTheme.accent)
        .preferredColorScheme(isSoulNightMode() ? .dark : .light)
        .task {
            if let syncedPeople = await session.loadContacts() {
                people = syncedPeople
            }
            if let stats = await session.loadStats() {
                practiceCount = stats.practicesCount
                reviewCount = stats.reviewsCount
            }
        }
    }

    @ViewBuilder
    private func page(for section: AppSection) -> some View {
        switch section {
        case .home:
            IntegratedHomePage(
                userID: session.user?.id,
                people: people,
                onOpenRelationshipGraph: {
                    selectedSection = .relationshipGraph
                },
                onOpenScenario: {
                    selectedSection = .scenarioSimulation
                },
                onOpenJournal: {
                    selectedSection = .journal
                }
            )
        case .relationshipGraph:
            relationshipGraphPage
        case .scenarioSimulation:
            ScenarioSimulationView(
                relationshipPeople: people,
                focusedPersonID: scenarioFocusedPersonID,
                onPracticeSubmitted: { duration, participant, mode, guidance, messages in
                    practiceCount += 1
                    Task {
                        await session.recordPractice(
                            duration: duration,
                            participant: participant,
                            mode: mode,
                            guidance: guidance,
                            messages: messages
                        )
                    }
                }
            )
        case .journal:
            ConversationReviewPage { count in
                reviewCount = count
            }
        case .profile:
            IntegratedProfilePage(achievementProgress: achievementProgress)
        }
    }

    private var relationshipGraphPage: some View {
        ZStack(alignment: .bottom) {
            RelationshipBackground()

            VStack(spacing: 0) {
                RelationshipHeader(
                    onAddPerson: {
                        requestAddPerson()
                    },
                    onOpenCategories: {
                        showingRelationshipCategories = true
                    }
                )

                RelationshipMapView(
                    people: visiblePeople,
                    ownerDisplayName: session.user?.displayName,
                    selectedPerson: selectedPerson,
                    onMovePerson: { id, position in
                        people.updatePosition(for: id, to: position)
                        if selectedPerson?.id == id {
                            selectedPerson = people.first { $0.id == id }
                        }
                        if let updated = people.first(where: { $0.id == id }) {
                            Task { await session.updateContact(updated) }
                        }
                    },
                    onOrganize: {
                        withAnimation(.spring(response: 0.48, dampingFraction: 0.86)) {
                            people.organizePositions()
                            graphLayoutRevision = UUID()
                            if let selectedPerson {
                                self.selectedPerson = people.first { $0.id == selectedPerson.id }
                            }
                        }
                        let organizedPeople = people
                        Task { await session.updateContacts(organizedPeople) }
                    },
                    onSelect: { person in
                        withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
                            selectedPerson = person
                        }
                    },
                    onAddPerson: requestAddPerson
                )
                .id(graphLayoutRevision)
                .padding(.top, 8)
                .padding(.bottom, 106)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .sheet(item: $selectedPerson) { person in
            RelationshipDetailSheet(
                person: person,
                availableCategories: availableCategories,
                onCategoryChange: { category in
                    people.updateRelationship(for: person.id, to: category)
                    selectedPerson = people.first { $0.id == person.id }
                    if let updated = selectedPerson {
                        Task { await session.updateContact(updated) }
                    }
                },
                onDeletePerson: {
                    people.deletePerson(person.id)
                    selectedPerson = nil
                    Task { await session.deleteContact(person.id) }
                },
                onStartScenario: {
                    scenarioFocusedPersonID = person.id
                    selectedPerson = nil
                    selectedSection = .scenarioSimulation
                },
                onAvatarChange: { imageData in
                    Task {
                        if let updated = await session.uploadContactAvatar(
                            contactID: person.id,
                            imageData: imageData
                        ) {
                            replacePerson(updated)
                        } else {
                            relationshipErrorMessage = localizedText(
                                "联系人仍然保留，但头像上传失败，请稍后重试。",
                                "The contact is safe, but the photo upload failed. Try again later."
                            )
                        }
                    }
                },
                onAvatarDelete: {
                    Task {
                        if let updated = await session.deleteContactAvatar(contactID: person.id) {
                            replacePerson(updated)
                        } else {
                            relationshipErrorMessage = localizedText(
                                "头像删除失败，请稍后重试。",
                                "The photo could not be removed. Try again later."
                            )
                        }
                    }
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isAddingPerson) {
            AddPersonSheet(availableCategories: availableCategories) { name, note, category, avatarData, informationFields in
                if case .custom = category, !customCategories.contains(category) {
                    customCategories.append(category)
                }
                people.addPerson(name: name, note: note, category: category, informationFields: informationFields)
                guard let localPerson = people.last else { return }
                Task {
                    if let remotePerson = await session.createContact(localPerson),
                       let index = people.firstIndex(where: { $0.id == localPerson.id }) {
                        people[index] = remotePerson
                        if let avatarData,
                           let avatarPerson = await session.uploadContactAvatar(
                            contactID: remotePerson.id,
                            imageData: avatarData
                           ) {
                            people[index] = avatarPerson
                        } else if avatarData != nil {
                            relationshipErrorMessage = localizedText(
                                "联系人已创建，但头像上传失败，可以稍后在资料中重试。",
                                "The contact was created, but the photo upload failed. You can retry in their profile."
                            )
                        }
                    }
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingMembershipUpgrade) {
            MembershipUpgradeSheet(currentPeopleCount: people.count)
                .presentationDetents([.height(430), .medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingRelationshipCategories) {
            RelationshipCategoriesSheet(
                selectedFilter: $selectedFilter,
                selectedCustomCategory: $selectedCustomCategory,
                filters: availableFilters,
                customCategories: customCategories,
                onAddRelationship: {
                    showingRelationshipCategories = false
                    isAddingRelationship = true
                },
                onDeleteRelationship: { category in
                    showingRelationshipCategories = false
                    pendingDeletedCategory = category
                }
            )
            .presentationDetents([.height(250), .medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isAddingRelationship) {
            AddRelationshipSheet { name in
                let category = RelationshipCategory.custom(name)
                if !customCategories.contains(category) {
                    customCategories.append(category)
                }
                selectedFilter = .all
                selectedCustomCategory = category
            }
            .presentationDetents([.height(260)])
            .presentationDragIndicator(.visible)
        }
        .confirmationDialog(
            localizedText("删除这个关系？", "Delete this relationship?"),
            isPresented: Binding(
                get: { pendingDeletedCategory != nil },
                set: { if !$0 { pendingDeletedCategory = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let pendingDeletedCategory {
                Button(localizedText("删除\(pendingDeletedCategory.displayTitle)", "Delete \(pendingDeletedCategory.displayTitle)"), role: .destructive) {
                    let removedIDs = people
                        .filter { $0.category == pendingDeletedCategory }
                        .map(\.id)
                    people.deleteRelationship(pendingDeletedCategory)
                    if customCategories.contains(pendingDeletedCategory) {
                        customCategories.removeAll { $0 == pendingDeletedCategory }
                    } else {
                        deletedCategories.insert(pendingDeletedCategory)
                    }
                    if selectedFilter.category == pendingDeletedCategory {
                        selectedFilter = .all
                    }
                    if selectedCustomCategory == pendingDeletedCategory {
                        selectedCustomCategory = nil
                        selectedFilter = .all
                    }
                    selectedPerson = nil
                    self.pendingDeletedCategory = nil
                    Task {
                        for id in removedIDs {
                            await session.deleteContact(id)
                        }
                    }
                }
            }

            Button(localizedText("取消", "Cancel"), role: .cancel) {
                pendingDeletedCategory = nil
            }
        } message: {
            if pendingDeletedCategory != nil {
                Text(localizedText("这个关系下的人会一起从关系图谱中移除。", "People under this relationship will also be removed from the map."))
            }
        }
        .alert(
            localizedText("头像没有保存", "Photo Not Saved"),
            isPresented: Binding(
                get: { relationshipErrorMessage != nil },
                set: { if !$0 { relationshipErrorMessage = nil } }
            )
        ) {
            Button(localizedText("知道了", "OK")) { relationshipErrorMessage = nil }
        } message: {
            Text(relationshipErrorMessage ?? "")
        }
    }

    private func requestAddPerson() {
        if FreeRelationshipPolicy.canAddPerson(currentCount: people.count) {
            isAddingPerson = true
        } else {
            showingMembershipUpgrade = true
        }
    }

    private func replacePerson(_ updated: RelationshipPerson) {
        guard let index = people.firstIndex(where: { $0.id == updated.id }) else { return }
        people[index] = updated
        selectedPerson = updated
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
