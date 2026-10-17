# ruff: noqa: E501
"""Curated self-awareness challenges.

Content lives in code so it ships with the API version and stays reviewable in PRs.
Models (Johari Window, values clarity, emotional intelligence, awareness wheel) are
embodied as actions and prompts rather than explained as theory.
"""

from dataclasses import dataclass, field


@dataclass(frozen=True)
class ChallengeStep:
    title: str
    instruction: str
    prompt: str
    kind: str = "text"  # "text" | "rating"
    min_chars: int = 6


@dataclass(frozen=True)
class Challenge:
    key: str
    title: str
    subtitle: str
    model: str  # johari | values | emotional_intelligence | awareness_wheel
    dimension: str  # openness | clarity | emotion | relation
    icon: str
    duration_minutes: int
    span_days: int
    intro: str
    completion_rule: str
    steps: tuple[ChallengeStep, ...] = field(default_factory=tuple)
    reward_experience: int = 20


DIMENSIONS: dict[str, str] = {
    "openness": "开放与反馈",
    "clarity": "价值与自我清晰",
    "emotion": "情绪觉察",
    "relation": "关系中的自己",
}

MODELS: dict[str, str] = {
    "johari": "乔哈里视窗",
    "values": "价值观澄清",
    "emotional_intelligence": "情绪智力",
    "awareness_wheel": "觉察之轮",
}

CHALLENGES: tuple[Challenge, ...] = (
    Challenge(
        key="johari_blind_spot",
        title="盲区来信",
        subtitle="请两位信任的人，说一个你没注意到的自己",
        model="johari",
        dimension="openness",
        icon="eye.trianglebadge.exclamationmark",
        duration_minutes=15,
        span_days=3,
        intro="别人眼里的你，常常藏着你看不到的答案。这次只问，不解释。",
        completion_rule="完成 4 步记录即可完成；不需要对方同意你的看法。",
        steps=(
            ChallengeStep(
                "选两个人",
                "挑两位真正了解你、也愿意说实话的人。",
                "你选了谁？为什么是他们？",
            ),
            ChallengeStep(
                "发出一个问题",
                "原样发出：“你觉得我身上有什么优点或习惯，是我自己可能没意识到的？”",
                "他们怎么说？尽量原话记录。",
                min_chars=10,
            ),
            ChallengeStep(
                "先别反驳",
                "读回答时注意第一反应：想解释、惊讶、还是被看见？",
                "听到时你的第一反应是什么？",
            ),
            ChallengeStep(
                "意外程度",
                "这些反馈和你对自己的认识差距有多大？",
                "1 = 完全知道，5 = 非常意外",
                kind="rating",
                min_chars=0,
            ),
        ),
    ),
    Challenge(
        key="johari_open_window",
        title="打开一扇窗",
        subtitle="向一个人分享一个 TA 还不知道的你",
        model="johari",
        dimension="openness",
        icon="window.casement",
        duration_minutes=10,
        span_days=2,
        intro="被理解，从愿意被看见开始。挑一件小事就够了。",
        completion_rule="完成分享并写下感受即可完成。",
        steps=(
            ChallengeStep(
                "挑一件小事",
                "一个偏好、一段经历、一个小担心——不必沉重。",
                "你准备分享什么？",
            ),
            ChallengeStep(
                "说出来",
                "找个轻松的时刻，用“其实我……”开头。",
                "对方有什么反应？",
            ),
            ChallengeStep(
                "回看自己",
                "分享前后，你和这个人的距离有变化吗？",
                "这次让你发现了自己的什么？",
                min_chars=10,
            ),
        ),
    ),
    Challenge(
        key="values_compass",
        title="价值指南针",
        subtitle="找到真正驱动你做选择的 3 个词",
        model="values",
        dimension="clarity",
        icon="safari",
        duration_minutes=12,
        span_days=1,
        intro="不用想“应该”重视什么，只看你实际为什么付出时间。",
        completion_rule="写下前三价值，并用一个真实选择检验一次。",
        steps=(
            ChallengeStep(
                "快速圈选",
                "从这些词里凭直觉选 5 个：自由、安全、成长、真诚、被认可、家人、创造、责任、平静、影响力、友谊、公平。",
                "你选了哪 5 个？",
            ),
            ChallengeStep(
                "只留三个",
                "如果只能留 3 个，你会划掉谁？过程中的犹豫也值得记下来。",
                "最后的 3 个是？划掉时最难舍的是哪个？",
            ),
            ChallengeStep(
                "用选择检验",
                "回想最近一次花了很多时间或情绪的决定。",
                "那次选择体现了哪一个价值？还是和它们冲突了？",
                min_chars=10,
            ),
            ChallengeStep(
                "一致程度",
                "你现在的日常，和这 3 个价值有多一致？",
                "1 = 很不一致，5 = 非常一致",
                kind="rating",
                min_chars=0,
            ),
        ),
    ),
    Challenge(
        key="self_concept_ten",
        title="十个“我是”",
        subtitle="用十句话描摹此刻的自己",
        model="values",
        dimension="clarity",
        icon="person.text.rectangle",
        duration_minutes=8,
        span_days=1,
        intro="写得越快越真。不必漂亮，只要像你。",
        completion_rule="写满十句并标出最稳定的一句。",
        steps=(
            ChallengeStep(
                "快写十句",
                "用“我是……”开头，连续写十句，不停笔。",
                "你的十句话：",
                min_chars=20,
            ),
            ChallengeStep(
                "找出底色",
                "哪一句无论在谁面前都成立？哪一句只在某些人面前成立？",
                "最稳定的一句是？最依赖场合的一句是？",
            ),
            ChallengeStep(
                "清晰程度",
                "写完后，你对“我是谁”的感觉有多清楚？",
                "1 = 很模糊，5 = 很清楚",
                kind="rating",
                min_chars=0,
            ),
        ),
    ),
    Challenge(
        key="emotion_naming",
        title="情绪命名三天",
        subtitle="每天一次，给情绪一个更准确的名字",
        model="emotional_intelligence",
        dimension="emotion",
        icon="heart.text.square",
        duration_minutes=3,
        span_days=3,
        intro="“烦”可能是失望、委屈或疲惫。名字越准，情绪越好照顾。",
        completion_rule="三天各打卡一次即可完成（可在同一天补记）。",
        steps=(
            ChallengeStep(
                "第一天",
                "此刻的情绪是什么？试着避开“好/不好/烦”，换个更准的词。",
                "情绪词 + 让它出现的那件事：",
            ),
            ChallengeStep(
                "第二天",
                "这次再加上身体：它在哪里？胸口、肩膀、胃？",
                "情绪词 + 身体感受：",
            ),
            ChallengeStep(
                "第三天",
                "这份情绪在提醒你需要什么？",
                "情绪词 + 它背后的需要：",
            ),
            ChallengeStep(
                "命名的把握",
                "三天下来，叫出情绪名字变容易了吗？",
                "1 = 还很难，5 = 很自然",
                kind="rating",
                min_chars=0,
            ),
        ),
    ),
    Challenge(
        key="six_second_pause",
        title="暂停六秒",
        subtitle="在下一次被触发时，先停六秒再回应",
        model="emotional_intelligence",
        dimension="emotion",
        icon="pause.circle",
        duration_minutes=5,
        span_days=3,
        intro="情绪升起到冲口而出之间，有一个可以选择的小缝隙。",
        completion_rule="记录一次真实的暂停经历即可完成。",
        steps=(
            ChallengeStep(
                "那个瞬间",
                "最近一次想立刻反击、解释或逃开的时刻。",
                "发生了什么？对方说了或做了什么？",
                min_chars=10,
            ),
            ChallengeStep(
                "六秒里",
                "停下时，你注意到了哪些念头或身体信号？",
                "那六秒里你注意到了什么？",
            ),
            ChallengeStep(
                "换一种回应",
                "暂停之后，你最终怎么回应？和平时有什么不同？",
                "你的回应是：",
            ),
        ),
    ),
    Challenge(
        key="awareness_wheel",
        title="觉察之轮",
        subtitle="把一次关系里的卡点拆成五块",
        model="awareness_wheel",
        dimension="relation",
        icon="circle.hexagongrid",
        duration_minutes=10,
        span_days=1,
        intro="同一件事，分清看到的、想到的、感到的、想要的和要做的，就不容易吵乱。",
        completion_rule="完成五个面向的记录即可完成。",
        steps=(
            ChallengeStep("看到/听到", "只写事实，像摄像机一样。", "发生了什么？"),
            ChallengeStep("我想的是", "你对这件事的解读。", "你当时怎么理解它？"),
            ChallengeStep("我感到", "一个或几个情绪词。", "你的感受是？"),
            ChallengeStep("我想要", "为自己、为对方、为这段关系。", "你真正想要的是？"),
            ChallengeStep("我会做", "一个小而具体的下一步。", "你接下来会怎么做？"),
        ),
    ),
    Challenge(
        key="relation_mirror",
        title="关系里的我",
        subtitle="在三段关系里，看看不同的自己",
        model="johari",
        dimension="relation",
        icon="person.2.wave.2",
        duration_minutes=12,
        span_days=1,
        intro="每段关系都是一面镜子。把镜子放在一起，会看到更完整的你。",
        completion_rule="写下三段关系里的自己，并找出一个共同点。",
        steps=(
            ChallengeStep(
                "三个人",
                "从关系图谱里挑三个很不一样的人：家人、朋友、同事都可以。",
                "他们是谁？",
            ),
            ChallengeStep(
                "三个我",
                "和每个人在一起时，你是什么样子？各用一个形容词。",
                "和 A 时我…；和 B 时我…；和 C 时我…",
                min_chars=10,
            ),
            ChallengeStep(
                "不变的那部分",
                "这三种样子里，有什么始终没变？",
                "始终如一的我是：",
            ),
            ChallengeStep(
                "自在程度",
                "整体来说，你在关系里做自己有多自在？",
                "1 = 常常拘束，5 = 很自在",
                kind="rating",
                min_chars=0,
            ),
        ),
    ),
    Challenge(
        key="how_i_want_to_be_seen",
        title="希望被如何看待",
        subtitle="写下日常里的自己，以及你希望被看成什么样",
        model="values",
        dimension="clarity",
        icon="person.crop.rectangle",
        duration_minutes=8,
        span_days=1,
        intro="名字和称号不算。只写你自己的句子。",
        completion_rule="两句都写下即可完成。没有稳定的「我是」，报告那一格仍留空。",
        steps=(
            ChallengeStep(
                "日常里的我",
                "工作和日常里，你怎么向别人描述自己？",
                "你平时怎么说自己？",
                min_chars=8,
            ),
            ChallengeStep(
                "希望被看成",
                "你希望别人把你看成什么样？用一句你的话。",
                "我希望被看成：",
                min_chars=8,
            ),
        ),
    ),
    Challenge(
        key="energy_and_reply_pace",
        title="精力与回复快慢",
        subtitle="时间实际去了哪，以及对谁回得最快、最慢",
        model="awareness_wheel",
        dimension="relation",
        icon="clock.arrow.circlepath",
        duration_minutes=10,
        span_days=1,
        intro="旁边的名单只是记账频率，不是回复速度。回复快慢要你自己说。",
        completion_rule="三步都写下即可完成。不到两件带日期的记录，对照先留空。",
        steps=(
            ChallengeStep(
                "时间去了哪",
                "任务上，时间实际花在哪些人和事上？",
                "时间去了哪：",
                min_chars=8,
            ),
            ChallengeStep(
                "最快和最久",
                "对谁回得最快，对谁拖得最久？",
                "回得最快的是谁，拖得最久的是谁？",
                min_chars=8,
            ),
            ChallengeStep(
                "和「我是」对照",
                "这和第 1 轮那句「我是」一致吗？不一致也照实写。",
                "和那句「我是」一致，还是不一致？",
                min_chars=6,
            ),
        ),
    ),
    Challenge(
        key="role_stance",
        title="角色里的端着与放松",
        subtitle="在已有的人里标出角色，并各配一句原话",
        model="johari",
        dimension="relation",
        icon="person.3.sequence",
        duration_minutes=10,
        span_days=1,
        intro="上级、同级、下级只写在这里。图谱不新增这个分类。",
        completion_rule="写完角色和两句原话即可完成。某一类没有你的原话，就不下结论。",
        steps=(
            ChallengeStep(
                "三种角色",
                "在已有的人里，谁更像上级、同级、下级？写出名字。",
                "上级、同级、下级分别是谁？",
                min_chars=6,
            ),
            ChallengeStep(
                "最端着",
                "哪里最端着？配一句你自己说过的话。",
                "最端着的地方，和那句原话：",
                min_chars=8,
            ),
            ChallengeStep(
                "最松",
                "哪里最松？再配一句你自己说过的话。",
                "最松的地方，和那句原话：",
                min_chars=8,
            ),
        ),
    ),
)

CHALLENGES_BY_KEY: dict[str, Challenge] = {item.key: item for item in CHALLENGES}
