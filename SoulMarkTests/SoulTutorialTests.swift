import Testing
@testable import SoulMark

struct SoulTutorialTests {
    @Test func tutorialPagesStayInRequiredProductOrder() {
        let pages = SoulTutorialPage.all

        #expect(pages.count == 4)
        #expect(pages.map(\.index) == [0, 1, 2, 3])
        #expect(pages.map(\.title.zh) == ["关系图谱", "情景模拟", "沟通复盘", "关系成长"])
        #expect(Set(pages.map(\.id)).count == 4)
    }

    @Test func scenarioTutorialExplainsSwitchingPeopleAndPrompts() {
        let scenario = SoulTutorialPage.all[1]

        #expect(scenario.body.zh.contains("切换对象"))
        #expect(scenario.body.zh.contains("情景／提示词"))
        #expect(scenario.body.en.localizedCaseInsensitiveContains("person"))
        #expect(scenario.body.en.localizedCaseInsensitiveContains("prompt"))
    }

    @Test func growthTutorialExplainsDecayTitlesAndAchievementBadges() {
        let growth = SoulTutorialPage.all[3]

        #expect(growth.body.zh.contains("经验"))
        #expect(growth.body.zh.contains("衰减"))
        #expect(growth.body.zh.contains("称号"))
        #expect(growth.body.zh.contains("成就徽章"))
    }

    @Test func finalTutorialButtonStartsTheApp() {
        let titles = SoulTutorialPage.all.map(\.buttonTitle.zh)

        #expect(titles == ["下一步", "下一步", "下一步", "开始使用"])
    }
}
