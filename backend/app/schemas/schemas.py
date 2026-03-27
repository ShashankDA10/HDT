from __future__ import annotations

from typing import Optional
from pydantic import BaseModel


# ── Health Profile ────────────────────────────────────────────────────────────

class HealthProfileData(BaseModel):
    # Basic
    age: Optional[int] = None
    gender: Optional[str] = None
    height_cm: Optional[float] = None
    weight_kg: Optional[float] = None
    body_fat_pct: Optional[float] = None
    waist_cm: Optional[float] = None

    # Vitals
    resting_heart_rate: Optional[int] = None
    bp_systolic: Optional[int] = None
    bp_diastolic: Optional[int] = None
    spo2_pct: Optional[float] = None
    body_temp_c: Optional[float] = None

    # Metabolic
    fasting_glucose: Optional[float] = None
    hba1c: Optional[float] = None
    fasting_insulin: Optional[float] = None
    total_cholesterol: Optional[float] = None
    ldl: Optional[float] = None
    hdl: Optional[float] = None
    triglycerides: Optional[float] = None

    # Liver
    alt: Optional[float] = None
    ast: Optional[float] = None
    bilirubin: Optional[float] = None

    # Kidney
    creatinine: Optional[float] = None
    bun: Optional[float] = None
    egfr: Optional[float] = None

    # Hormonal
    testosterone: Optional[float] = None
    estrogen: Optional[float] = None
    tsh: Optional[float] = None
    cortisol: Optional[float] = None

    # Lifestyle
    daily_steps: Optional[int] = None
    workout_frequency_per_week: Optional[int] = None
    workout_type: Optional[str] = None
    sleep_duration_hrs: Optional[float] = None
    sleep_quality: Optional[int] = None
    stress_level: Optional[int] = None
    water_intake_liters: Optional[float] = None
    smoking_status: Optional[str] = None
    alcohol_units_per_week: Optional[int] = None

    # Nutrition
    daily_calories: Optional[int] = None
    protein_g: Optional[float] = None
    fiber_g: Optional[float] = None
    fat_g: Optional[float] = None
    sugar_g: Optional[float] = None

    # Medical
    conditions: list[str] = []
    medications: list[str] = []
    family_history: list[str] = []
    allergies: list[str] = []

    # Goals — single flat list, never split into categories
    lifestyle_goals: list[str] = []

    class Config:
        extra = "ignore"


# ── Health Log ────────────────────────────────────────────────────────────────

class HealthLogCreate(BaseModel):
    type: str          # 'weight' | 'sleep' | 'activity' | 'biomarker'
    label: str         # e.g. "Weight", "Sleep", "Steps", "LDL"
    value: float
    unit: str          # e.g. "kg", "hrs", "steps", "mg/dL"


class HealthLogResponse(HealthLogCreate):
    id: str
    timestamp: str     # ISO-8601


# ── App context (medications / reports / appointments from Flutter) ────────────

class MedicationContext(BaseModel):
    name: str
    dosage: str = ""
    frequency: str = ""


class ReportContext(BaseModel):
    category: str = ""
    report_type: str = ""
    diagnosis: str = ""
    clinical_notes: str = ""
    date: str = ""
    doctor_name: str = ""


class AppointmentContext(BaseModel):
    doctor_name: str = ""
    date: str = ""
    time: str = ""
    status: str = ""


class AppContextData(BaseModel):
    medications: list[MedicationContext] = []
    recent_reports: list[ReportContext] = []
    appointments: list[AppointmentContext] = []
    conditions: list[str] = []
    allergies: list[str] = []


# ── Recommend ────────────────────────────────────────────────────────────────

class RecommendRequest(BaseModel):
    question: str
    app_context: Optional[AppContextData] = None


class ActionPlan(BaseModel):
    diet: list[str]
    training: list[str]
    lifestyle: list[str]


class OTCSuggestion(BaseModel):
    name: str
    purpose: str
    dosage: str
    notes: str = ""


class AIRecommendationResponse(BaseModel):
    key_issues: list[str]
    root_causes: list[str]
    action_plan: ActionPlan
    otc_suggestions: list[OTCSuggestion] = []
    expected_timeline: str
    warnings: list[str]
    suggest_appointment: bool = False
