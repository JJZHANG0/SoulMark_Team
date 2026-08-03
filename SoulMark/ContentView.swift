//
//  ContentView.swift
//  SoulMark
//

import SwiftUI

enum AppSection {
    case home
    case relationshipGraph
    case scenarioSimulation
    case journal
    case profile

    var title: String {
        let isEnglish = UserDefaults.standard.string(forKey: "soulMarkLanguage") == "en"
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
    @State private var selectedSection: AppSection = .home
    @State private var selectedFilter: RelationshipFilter = .all
    @State private var selectedCustomCategory: RelationshipCategory?
    @State private var selectedPerson: RelationshipPerson?
    @State private var people = RelationshipSampleData.people
    @State private var customCategories: [RelationshipCategory] = []
    @State private var isAddingPerson = false
    @State private var isAddingRelationship = false
    @State private var pendingDeletedCategory: RelationshipCategory?
    @State private var deletedCategories: Set<RelationshipCategory> = []
    @State private var graphLayoutRevision = UUID()
    @State private var scenarioFocusedPersonID: RelationshipPerson.ID?
    @AppStorage("soulMarkLanguage") private var language = "zh"
    @AppStorage("soulMarkAppearanceMode") private var appearanceMode = "auto"

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

    var body: some View {
        ZStack(alignment: .bottom) {
            currentPage

            AppTabBar(selectedSection: $selectedSection)
        }
        .ignoresSafeArea(edges: .bottom)
        .preferredColorScheme(isSoulNightMode() ? .dark : .light)
    }

    @ViewBuilder
    private var currentPage: some View {
        switch selectedSection {
        case .home:
            IntegratedHomePage(
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
                focusedPersonID: scenarioFocusedPersonID
            )
        case .journal:
            ConversationReviewPage()
        case .profile:
            IntegratedProfilePage()
        }
    }

    private var relationshipGraphPage: some View {
        ZStack(alignment: .bottom) {
            RelationshipBackground()

            VStack(spacing: 0) {
                RelationshipHeader(
                    onBackHome: {
                        selectedSection = .home
                    },
                    onAddPerson: {
                        isAddingPerson = true
                    },
                    onOpenScenario: {
                        selectedSection = .scenarioSimulation
                    }
                )

                RelationshipMapView(
                    people: visiblePeople,
                    selectedPerson: selectedPerson,
                    onMovePerson: { id, position in
                        people.updatePosition(for: id, to: position)
                        if selectedPerson?.id == id {
                            selectedPerson = people.first { $0.id == id }
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
                    },
                    onSelect: { person in
                        withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
                            selectedPerson = person
                        }
                    }
                )
                .id(graphLayoutRevision)
                .padding(.top, 8)
                .padding(.bottom, 154)
            }

            RelationshipFilterBar(
                selectedFilter: $selectedFilter,
                selectedCustomCategory: $selectedCustomCategory,
                filters: availableFilters,
                customCategories: customCategories,
                onAddRelationship: {
                    isAddingRelationship = true
                },
                onDeleteRelationship: { category in
                    pendingDeletedCategory = category
                }
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 106)
            .onChange(of: selectedFilter) { _, _ in
                selectedPerson = nil
            }
            .onChange(of: selectedCustomCategory) { _, _ in
                selectedPerson = nil
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
                },
                onDeletePerson: {
                    people.deletePerson(person.id)
                    selectedPerson = nil
                },
                onStartScenario: {
                    scenarioFocusedPersonID = person.id
                    selectedPerson = nil
                    selectedSection = .scenarioSimulation
                }
            )
            .presentationDetents([.height(450), .medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isAddingPerson) {
            AddPersonSheet(availableCategories: availableCategories) { name, note, category in
                people.addPerson(name: name, note: note, category: category)
            }
            .presentationDetents([.height(430), .medium])
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
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
