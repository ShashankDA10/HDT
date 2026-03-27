"""MedTwin AI engine — powered by Groq (Llama 3.3 70B)."""

import asyncio
import json
import logging

from groq import Groq

from app.core.config import settings
from app.schemas.schemas import AppContextData

logger = logging.getLogger("medtwin")

SYSTEM_PROMPT = (
    "You are MedTwin AI — a highly knowledgeable, evidence-based personal health coach. "
    "You have access to the user's Digital Twin health profile, medical conditions, "
    "allergies, current medications, recent medical reports, and doctor appointments. "
    "Your recommendations must be deeply personalized, conflict-aware, safe, and specific. "
    "CRITICAL: Never recommend foods, drugs, or supplements the user is allergic to. "
    "Always tailor advice to existing medical conditions (e.g. avoid high-intensity cardio for heart disease, "
    "low-carb diet guidance for diabetes, avoid NSAIDs for certain conditions). "
    "Never give generic advice. Always ground recommendations in the provided data.\n\n"
    "Set 'suggest_appointment' to true if ANY of these apply:\n"
    "- Critical biomarker values (high BP, high LDL, high HbA1c, low eGFR)\n"
    "- The user's question involves symptoms, pain, or a new diagnosis\n"
    "- A report shows abnormal findings requiring follow-up\n"
    "- It has been more than 6 months since any approved appointment\n\n"
    'Respond ONLY in this exact JSON format (no markdown, no extra text):\n'
    "{\n"
    '  "key_issues": ["...", "..."],\n'
    '  "root_causes": ["...", "..."],\n'
    '  "action_plan": {\n'
    '    "diet": ["...", "..."],\n'
    '    "training": ["...", "..."],\n'
    '    "lifestyle": ["...", "..."]\n'
    "  },\n"
    '  "otc_suggestions": [\n'
    '    { "name": "...", "purpose": "...", "dosage": "...", "notes": "..." }\n'
    "  ],\n"
    '  "expected_timeline": "...",\n'
    '  "warnings": ["...", "..."],\n'
    '  "suggest_appointment": false\n'
    "}\n"
    "For otc_suggestions: recommend 2-4 safe, evidence-backed OTC supplements or medicines "
    "relevant to the user's issues (e.g. Magnesium Glycinate for sleep, Omega-3 for lipids, "
    "Vitamin D for deficiency, Melatonin for sleep onset, Ashwagandha for stress). "
    "Include exact dosage and timing. NEVER suggest anything contraindicated by their conditions or allergies. "
    "Each action_plan array must have 3-6 items. Be specific and actionable."
)

# ── Context builder ───────────────────────────────────────────────────────────

_FIELD_LABELS: dict[str, str] = {
    "age": "Age",
    "gender": "Gender",
    "height_cm": "Height (cm)",
    "weight_kg": "Weight (kg)",
    "body_fat_pct": "Body fat (%)",
    "waist_cm": "Waist (cm)",
    "resting_heart_rate": "Resting HR (bpm)",
    "bp_systolic": "BP systolic (mmHg)",
    "bp_diastolic": "BP diastolic (mmHg)",
    "spo2_pct": "SpO2 (%)",
    "body_temp_c": "Body temp (°C)",
    "fasting_glucose": "Fasting glucose (mg/dL)",
    "hba1c": "HbA1c (%)",
    "fasting_insulin": "Fasting insulin (µIU/mL)",
    "total_cholesterol": "Total cholesterol (mg/dL)",
    "ldl": "LDL (mg/dL)",
    "hdl": "HDL (mg/dL)",
    "triglycerides": "Triglycerides (mg/dL)",
    "alt": "ALT (U/L)",
    "ast": "AST (U/L)",
    "bilirubin": "Bilirubin (mg/dL)",
    "creatinine": "Creatinine (mg/dL)",
    "bun": "BUN (mg/dL)",
    "egfr": "eGFR (mL/min/1.73m²)",
    "testosterone": "Testosterone (ng/dL)",
    "estrogen": "Estrogen (pg/mL)",
    "tsh": "TSH (mIU/L)",
    "cortisol": "Cortisol (µg/dL)",
    "daily_steps": "Daily steps",
    "workout_frequency_per_week": "Workouts/week",
    "workout_type": "Workout type",
    "sleep_duration_hrs": "Sleep duration (hrs)",
    "sleep_quality": "Sleep quality (1-10)",
    "stress_level": "Stress level (1-10)",
    "water_intake_liters": "Water intake (L/day)",
    "smoking_status": "Smoking",
    "alcohol_units_per_week": "Alcohol (units/week)",
    "daily_calories": "Daily calories (kcal)",
    "protein_g": "Protein (g/day)",
    "fiber_g": "Fiber (g/day)",
    "fat_g": "Fat (g/day)",
    "sugar_g": "Sugar (g/day)",
}

_LIST_LABELS: dict[str, str] = {
    "conditions": "Medical conditions",
    "medications": "Medications",
    "family_history": "Family history",
    "allergies": "Allergies",
    "lifestyle_goals": "Goals",
}


def build_profile_context(profile: dict, app_context: AppContextData | None) -> str:
    lines: list[str] = []

    for key, label in _FIELD_LABELS.items():
        value = profile.get(key)
        if value is not None and value != "":
            lines.append(f"{label}: {value}")

    for key, label in _LIST_LABELS.items():
        items: list = profile.get(key) or []
        if items:
            lines.append(f"{label}: {', '.join(str(i) for i in items)}")

    if not lines:
        lines.append("No Digital Twin biomarker data provided.")

    # ── App context ───────────────────────────────────────────────────────────
    if app_context:
        if app_context.conditions:
            lines.append("\n--- Medical Conditions ---")
            for c in app_context.conditions:
                lines.append(f"  • {c}")

        if app_context.allergies:
            lines.append("\n--- Allergies ---")
            for a in app_context.allergies:
                lines.append(f"  • {a}")

        if app_context.medications:
            lines.append("\n--- Current Medications ---")
            for m in app_context.medications:
                parts = [m.name]
                if m.dosage:
                    parts.append(m.dosage)
                if m.frequency:
                    parts.append(m.frequency)
                lines.append(f"  • {' | '.join(parts)}")

        if app_context.recent_reports:
            lines.append("\n--- Recent Medical Reports ---")
            for r in app_context.recent_reports:
                desc = r.report_type or r.category
                if r.date:
                    desc += f" ({r.date})"
                if r.doctor_name:
                    desc += f" by Dr. {r.doctor_name}"
                lines.append(f"  • {desc}")
                if r.diagnosis:
                    lines.append(f"    Diagnosis: {r.diagnosis}")
                if r.clinical_notes:
                    lines.append(f"    Notes: {r.clinical_notes}")

        if app_context.appointments:
            lines.append("\n--- Doctor Appointments ---")
            for a in app_context.appointments:
                status = a.status.upper() if a.status else ""
                lines.append(
                    f"  • Dr. {a.doctor_name} on {a.date} at {a.time} [{status}]"
                )

    return "\n".join(lines)


# ── Groq call ─────────────────────────────────────────────────────────────────

_client: Groq | None = None


def _get_client() -> Groq:
    global _client
    if _client is None:
        _client = Groq(api_key=settings.GROQ_API_KEY)
    return _client


def _call_groq_sync(prompt: str) -> str:
    client = _get_client()
    response = client.chat.completions.create(
        model=settings.GROQ_MODEL,
        messages=[
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": prompt},
        ],
        temperature=0.3,
        max_tokens=1500,
    )
    return response.choices[0].message.content


async def call_gemini(
    profile: dict,
    question: str,
    app_context: AppContextData | None = None,
) -> dict:
    """Entry point kept as call_gemini for router compatibility."""
    context = build_profile_context(profile, app_context)
    prompt = (
        f"User's Digital Twin health profile:\n{context}\n\n"
        f"User question: {question}"
    )
    raw = await asyncio.to_thread(_call_groq_sync, prompt)
    return _parse_response(raw)


# ── Response parser ───────────────────────────────────────────────────────────

def _parse_response(text: str) -> dict:
    cleaned = text.strip()
    if cleaned.startswith("```"):
        lines = cleaned.splitlines()
        inner = lines[1:-1] if lines[-1].strip() == "```" else lines[1:]
        cleaned = "\n".join(inner)

    try:
        data = json.loads(cleaned)
    except json.JSONDecodeError as exc:
        logger.warning("Groq response could not be parsed as JSON: %s", exc)
        data = {
            "key_issues": ["Unable to parse AI response."],
            "root_causes": [],
            "action_plan": {"diet": [], "training": [], "lifestyle": []},
            "expected_timeline": "N/A",
            "warnings": [],
            "suggest_appointment": False,
        }

    data.setdefault("key_issues", [])
    data.setdefault("root_causes", [])
    data.setdefault("action_plan", {"diet": [], "training": [], "lifestyle": []})
    data.setdefault("otc_suggestions", [])
    data.setdefault("expected_timeline", "")
    data.setdefault("warnings", [])
    data.setdefault("suggest_appointment", False)

    return data
