from app.ai.review import CHALLENGE_KEEP_RULES, build_challenge_keep_prompt
from app.services.challenge_catalog import CHALLENGES, CHALLENGES_BY_KEY

FROZEN_STEPS = {
    "johari_blind_spot": ("选两个人", "发出一个问题", "先别反驳", "意外程度"),
    "johari_open_window": ("挑一件小事", "说出来", "回看自己"),
    "values_compass": ("快速圈选", "只留三个", "用选择检验", "一致程度"),
    "self_concept_ten": ("快写十句", "找出底色", "清晰程度"),
    "emotion_naming": ("第一天", "第二天", "第三天", "命名的把握"),
    "six_second_pause": ("那个瞬间", "六秒里", "换一种回应"),
    "awareness_wheel": ("看到/听到", "我想的是", "我感到", "我想要", "我会做"),
    "relation_mirror": ("三个人", "三个我", "不变的那部分", "自在程度"),
}


def test_catalog_is_curated_and_consistent():
    assert len(CHALLENGES) == len(FROZEN_STEPS) + 3
    assert len(CHALLENGES_BY_KEY) == len(CHALLENGES)
    models = {c.model for c in CHALLENGES}
    assert {"johari", "values", "emotional_intelligence", "awareness_wheel"} <= models
    for key, titles in FROZEN_STEPS.items():
        challenge = CHALLENGES_BY_KEY[key]
        assert tuple(step.title for step in challenge.steps) == titles
    for key in ("how_i_want_to_be_seen", "energy_and_reply_pace", "role_stance"):
        assert key in CHALLENGES_BY_KEY
    for challenge in CHALLENGES:
        assert challenge.steps and challenge.duration_minutes > 0
        assert all(step.kind in {"text", "rating"} for step in challenge.steps)


async def test_challenges_require_auth(client):
    assert (await client.get("/api/v1/challenges")).status_code == 401
    assert (await client.get("/api/v1/users/me/self-awareness-report")).status_code == 401


async def test_list_and_detail(client, auth_headers):
    listing = await client.get("/api/v1/challenges", headers=auth_headers)
    assert listing.status_code == 200
    body = listing.json()
    assert len(body["challenges"]) == len(CHALLENGES)
    assert body["active_count"] == 0
    assert all(item["status"] == "not_started" for item in body["challenges"])
    detail = await client.get("/api/v1/challenges/values_compass", headers=auth_headers)
    assert detail.status_code == 200
    assert detail.json()["steps"][0]["response"] is None
    missing = await client.get("/api/v1/challenges/nope", headers=auth_headers)
    assert missing.status_code == 404


async def test_full_challenge_flow_awards_once(client, auth_headers):
    key = "values_compass"
    base = f"/api/v1/challenges/{key}"
    not_started = await client.put(f"{base}/steps/0", headers=auth_headers, json={"response": "x"})
    assert not_started.status_code == 409
    started = await client.post(f"{base}/start", headers=auth_headers)
    assert started.status_code == 200
    assert started.json()["status"] == "active"

    locked = await client.put(
        f"{base}/steps/2", headers=auth_headers, json={"response": "跳过前面的步骤看看"}
    )
    assert locked.status_code == 409
    short = await client.put(f"{base}/steps/0", headers=auth_headers, json={"response": "短"})
    assert short.status_code == 422

    answers = [
        "自由、成长、真诚、家人、创造",
        "成长、真诚、家人；最难舍的是自由",
        "换工作时我选择了成长，放弃了稳定",
    ]
    for index, text in enumerate(answers):
        result = await client.put(
            f"{base}/steps/{index}", headers=auth_headers, json={"response": text}
        )
        assert result.status_code == 200, result.text
        assert result.json()["challenge"]["completed_steps"] == index + 1
    no_rating = await client.put(f"{base}/steps/3", headers=auth_headers, json={})
    assert no_rating.status_code == 422
    done = await client.put(f"{base}/steps/3", headers=auth_headers, json={"rating": 4})
    assert done.status_code == 200
    payload = done.json()
    assert payload["challenge"]["status"] == "completed"
    assert payload["awarded_experience"] == 20
    assert payload["growth"]["balance"] == 20

    again = await client.post(f"{base}/complete", headers=auth_headers)
    assert again.status_code == 200
    assert again.json()["awarded_experience"] == 0

    restarted = await client.post(f"{base}/start", headers=auth_headers)
    assert restarted.json()["completed_steps"] == 0
    assert restarted.json()["completion_count"] == 1

    listing = (await client.get("/api/v1/challenges", headers=auth_headers)).json()
    assert listing["completed_count"] == 1
    assert listing["active_count"] == 1

    export = (await client.get("/api/v1/users/me/export", headers=auth_headers)).json()
    assert export["challenges"][0]["challenge_key"] == key


async def test_report_empty_page_is_blank_until_confirmed(client, auth_headers):
    empty = await client.get("/api/v1/users/me/self-awareness-report", headers=auth_headers)
    assert empty.status_code == 200
    body = empty.json()
    assert "overall_score" not in body
    assert "dimensions" not in body
    assert body["evidence_covered"] == 0
    assert body["evidence_total"] == 8
    assert len(body["cells"]) == 8
    assert all(cell["text"] == "" and cell["covered"] is False for cell in body["cells"])
    assert body["weekly_step_done"] is False
    assert body["bookkeeping"]["contacts_count"] == 0

    base = "/api/v1/challenges/six_second_pause"
    await client.post(f"{base}/start", headers=auth_headers)
    for index in range(3):
        await client.put(
            f"{base}/steps/{index}",
            headers=auth_headers,
            json={"response": "同事在会上打断我，我停下来深呼吸后再回应"},
        )
    report = (
        await client.get("/api/v1/users/me/self-awareness-report", headers=auth_headers)
    ).json()
    assert report["evidence_covered"] == 0
    assert all(not cell["covered"] for cell in report["cells"])
    assert any("同事在会上打断我" in item["quote"] for item in report["draft"])
    assert all(item["quote"] != "表达清晰" for item in report["draft"])


def test_challenge_keep_prompt_uses_only_their_words():
    prompt = build_challenge_keep_prompt("打开一扇窗", [("挑一件小事", "我准备说我怕迟到")])
    assert CHALLENGE_KEEP_RULES in prompt
    assert "Use only their words." in prompt
    assert "one short draft sentence they might keep" in prompt
    assert "one sharper question" in prompt
    assert "No score, no diagnosis, no praise, no comfort." in prompt
    assert "我准备说我怕迟到" in prompt


async def _answer(client, headers, key, answers, continue_anyway=None, rating=None):
    base = f"/api/v1/challenges/{key}"
    started = await client.post(f"{base}/start", headers=headers)
    assert started.status_code == 200, started.text
    last = None
    flags = continue_anyway or [False] * len(answers)
    for index, text in enumerate(answers):
        last = await client.put(
            f"{base}/steps/{index}",
            headers=headers,
            json={"response": text, "continue_anyway": flags[index]},
        )
        assert last.status_code == 200, last.text
    if rating is not None:
        last = await client.put(
            f"{base}/steps/{len(answers)}",
            headers=headers,
            json={"rating": rating},
        )
        assert last.status_code == 200, last.text
    return last


async def test_completion_asks_once_and_confirm_parks_the_sentence(
    client, auth_headers, monkeypatch
):
    calls = []

    async def fake(title, answers, settings):
        calls.append((title, answers))
        return "我怕迟到", "你怕的是迟到，还是被看见迟到？"

    monkeypatch.setattr("app.services.challenges.draft_challenge_keep", fake)
    answers = [
        "我准备分享的是我怕迟到",
        "对方笑了笑，说原来你也这样",
        "这次让我发现我怕被看见迟到",
    ]
    done = await _answer(client, auth_headers, "johari_open_window", answers)
    body = done.json()
    assert body["challenge"]["status"] == "completed"
    assert body["keep"]["sentence"] == "我怕迟到"
    assert body["keep"]["question"] == "你怕的是迟到，还是被看见迟到？"
    assert body["keep"]["detail"] == "挑一件小事"
    assert calls == [
        (
            "打开一扇窗",
            [
                ("挑一件小事", answers[0]),
                ("说出来", answers[1]),
                ("回看自己", answers[2]),
            ],
        )
    ]

    again = await client.post(
        "/api/v1/challenges/johari_open_window/complete", headers=auth_headers
    )
    assert again.status_code == 200
    assert again.json()["keep"] is None
    assert len(calls) == 1

    report = (
        await client.get("/api/v1/users/me/self-awareness-report", headers=auth_headers)
    ).json()
    assert report["evidence_covered"] == 0
    assert all(cell["text"] == "" and cell["covered"] is False for cell in report["cells"])
    assert all(item["quote"] != "我怕迟到" for item in report["draft"])

    reflection_id = body["keep"]["reflection_id"]
    rejected = await client.post(
        "/api/v1/challenges/johari_open_window/keep",
        headers=auth_headers,
        json={"reflection_id": reflection_id, "sentence": "这是模型新写的一句"},
    )
    assert rejected.status_code == 422

    kept = await client.post(
        "/api/v1/challenges/johari_open_window/keep",
        headers=auth_headers,
        json={"reflection_id": reflection_id, "sentence": "我怕迟到"},
    )
    assert kept.status_code == 200
    parked = kept.json()
    assert parked["slot"] == "pool"
    assert parked["source_type"] == "challenge_reflection"
    assert parked["quote"] == "我怕迟到"
    assert parked["confirmed"] is False

    report = (
        await client.get("/api/v1/users/me/self-awareness-report", headers=auth_headers)
    ).json()
    assert report["evidence_covered"] == 0
    assert all(cell["text"] == "" and cell["covered"] is False for cell in report["cells"])
    marked = [item for item in report["draft"] if item["quote"] == "我怕迟到"]
    assert len(marked) == 1
    assert marked[0]["slot"] == "marked"
    assert marked[0]["source_type"] == "challenge_reflection"

    detail = (
        await client.get("/api/v1/challenges/johari_open_window", headers=auth_headers)
    ).json()
    assert [step["response"] for step in detail["steps"]] == answers


async def test_distress_and_invented_sentences_do_not_call_or_store(
    client, auth_headers, monkeypatch
):
    calls = []

    async def fake(title, answers, settings):
        calls.append(answers)
        return "这是模型新写的一句", "你真正怕的是什么？"

    monkeypatch.setattr("app.services.challenges.draft_challenge_keep", fake)
    distressed = await _answer(
        client,
        auth_headers,
        "johari_open_window",
        [
            "我准备分享的是我怕迟到",
            "对方只是点了点头",
            "我写下不想活了，先停在这里",
        ],
        continue_anyway=[False, False, True],
    )
    assert distressed.status_code == 200
    assert distressed.json()["challenge"]["status"] == "completed"
    assert distressed.json()["keep"] is None
    assert calls == []
    saved = (
        await client.get("/api/v1/challenges/johari_open_window", headers=auth_headers)
    ).json()
    assert saved["steps"][2]["response"] == "我写下不想活了，先停在这里"

    invented_answers = [
        "三个朋友，三个同事，还有家里的人",
        "在朋友面前我话多，在同事面前我话少",
        "不变的是我会先看对方脸色",
    ]
    invented = await _answer(
        client,
        auth_headers,
        "relation_mirror",
        invented_answers,
        rating=4,
    )
    assert invented.json()["keep"] is None
    assert calls == [list(zip(
        ("三个人", "三个我", "不变的那部分"),
        invented_answers,
        strict=True,
    ))]
    report = (
        await client.get("/api/v1/users/me/self-awareness-report", headers=auth_headers)
    ).json()
    assert report["evidence_covered"] == 0
    assert all(cell["text"] == "" and cell["covered"] is False for cell in report["cells"])
    mirror = (
        await client.get("/api/v1/challenges/relation_mirror", headers=auth_headers)
    ).json()
    assert [step["response"] for step in mirror["steps"][:3]] == invented_answers
    assert mirror["steps"][3]["rating"] == 4
