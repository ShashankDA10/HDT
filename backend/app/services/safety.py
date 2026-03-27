"""Rule-based biomarker safety checks.

Runs before every AI call and returns a list of warning strings.
Each warning is human-readable and included in the final response.
"""


def run_safety_checks(profile: dict) -> list[str]:
    flags: list[str] = []

    ldl = profile.get("ldl")
    if ldl is not None and ldl > 190:
        flags.append(
            "LDL critically elevated (>190 mg/dL). Doctor consultation required."
        )

    bp_sys = profile.get("bp_systolic")
    if bp_sys is not None:
        if bp_sys >= 180:
            flags.append(
                "Hypertensive crisis range. Seek medical attention immediately."
            )
        elif bp_sys >= 140:
            flags.append(
                "Stage 2 hypertension. Consult doctor before high-intensity exercise."
            )

    hba1c = profile.get("hba1c")
    if hba1c is not None and hba1c >= 6.5:
        flags.append("HbA1c in diabetic range. Medical supervision essential.")

    glucose = profile.get("fasting_glucose")
    if glucose is not None and glucose >= 126:
        flags.append(
            "Fasting glucose may indicate diabetes. Get diagnosed first."
        )

    calories = profile.get("daily_calories")
    if calories is not None and calories < 1000:
        flags.append(
            "Dangerously low calorie intake. Risk of metabolic damage."
        )

    egfr = profile.get("egfr")
    if egfr is not None and egfr < 30:
        flags.append(
            "Severe kidney disease. High protein diets are dangerous."
        )

    alt = profile.get("alt")
    if alt is not None and alt > 56:
        flags.append("Elevated liver enzyme. Avoid alcohol, see a doctor.")

    tsh = profile.get("tsh")
    if tsh is not None and (tsh < 0.4 or tsh > 4.5):
        flags.append("TSH outside normal range. Thyroid evaluation needed.")

    return flags
