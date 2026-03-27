import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

// ── OCR parsed result model ────────────────────────────────────────────────────

class OcrParsedReport {
  final String rawText;
  final String doctorName;
  final String hospitalName;
  final DateTime? reportDate;
  final String clinicalNotes;
  final String diagnosis;
  final String additionalComments;
  final String suggestedCategory;
  final String suggestedType;
  final List<String> suggestedTags;

  const OcrParsedReport({
    required this.rawText,
    required this.doctorName,
    required this.hospitalName,
    this.reportDate,
    required this.clinicalNotes,
    required this.diagnosis,
    required this.additionalComments,
    required this.suggestedCategory,
    required this.suggestedType,
    required this.suggestedTags,
  });

  /// Number of fields that were auto-extracted (non-empty).
  int get extractedFieldCount {
    int n = 0;
    if (doctorName.isNotEmpty) n++;
    if (hospitalName.isNotEmpty) n++;
    if (reportDate != null) n++;
    if (clinicalNotes.isNotEmpty) n++;
    if (diagnosis.isNotEmpty) n++;
    if (additionalComments.isNotEmpty) n++;
    return n;
  }
}

// ── OCR service ───────────────────────────────────────────────────────────────

class OcrReportService {
  /// Run Google ML Kit text recognition on [imageFile].
  /// Returns the raw extracted text, or null if nothing was recognised.
  static Future<String?> extractText(XFile imageFile) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFilePath(imageFile.path);
      final result = await recognizer.processImage(inputImage);
      final text = result.text.trim();
      return text.isEmpty ? null : text;
    } finally {
      await recognizer.close();
    }
  }

  /// Parse [rawText] into structured report fields.
  static OcrParsedReport parseFields(String rawText) {
    return OcrParsedReport(
      rawText: rawText,
      doctorName: _extractDoctor(rawText),
      hospitalName: _extractHospital(rawText),
      reportDate: _extractDate(rawText),
      clinicalNotes: _extractSection(rawText,
          ['findings', 'clinical notes', 'observations', 'results', 'report', 'details', 'impression']),
      diagnosis: _extractSection(rawText,
          ['diagnosis', 'final diagnosis', 'assessment', 'conclusion', 'clinical impression']),
      additionalComments: _extractSection(rawText,
          ['comments', 'remarks', 'advice', 'recommendation', 'note', 'instructions']),
      suggestedCategory: _detectCategory(rawText.toLowerCase()),
      suggestedType: _detectType(rawText.toLowerCase()),
      suggestedTags: _detectTags(rawText.toLowerCase()),
    );
  }

  // ── Field extractors ─────────────────────────────────────────────────────────

  static String _extractDoctor(String text) {
    // Pattern 1: "Dr. FirstName [MiddleName] LastName"
    final drRegex = RegExp(
        r'Dr\.?\s+([A-Z][a-zA-Z]+(?:\s+[A-Z][a-zA-Z]+){0,3})',
        caseSensitive: false);
    final drMatch = drRegex.firstMatch(text);
    if (drMatch != null) {
      final name = drMatch.group(1)!.trim();
      if (name.length > 2) return 'Dr. $name';
    }

    // Pattern 2: labeled lines
    for (final line in text.split('\n')) {
      final t = line.trim();
      final l = t.toLowerCase();
      for (final label in [
        'doctor:',
        'doctor name:',
        'physician:',
        'consultant:',
        'attending physician:',
        'attending doctor:',
        'radiologist:',
        'pathologist:',
        'referred by:',
      ]) {
        if (l.startsWith(label)) {
          final val = t.substring(label.length).trim();
          if (val.isNotEmpty) return val;
        }
      }
    }
    return '';
  }

  static String _extractHospital(String text) {
    // Pattern 1: labeled lines
    for (final line in text.split('\n')) {
      final t = line.trim();
      final l = t.toLowerCase();
      for (final label in [
        'hospital:',
        'hospital name:',
        'lab:',
        'laboratory:',
        'clinic:',
        'centre:',
        'center:',
        'facility:',
        'institution:',
      ]) {
        if (l.startsWith(label)) {
          final val = t.substring(label.length).trim();
          if (val.isNotEmpty) return val;
        }
      }
    }

    // Pattern 2: lines that *contain* hospital-type keywords and look like names
    const hospitalKeywords = [
      'hospital',
      'clinic',
      'medical centre',
      'medical center',
      'diagnostic',
      'diagnostics',
      'laboratory',
      ' lab ',
      'healthcare',
      'health centre',
      'health center',
      'nursing home',
      'polyclinic',
      'medicare',
      'pathology',
    ];
    for (final line in text.split('\n')) {
      final t = line.trim();
      final l = t.toLowerCase();
      if (t.length < 6 || t.length > 80) continue;
      for (final kw in hospitalKeywords) {
        if (l.contains(kw)) return t;
      }
    }
    return '';
  }

  static DateTime? _extractDate(String text) {
    // Look for lines that contain date labels first (higher priority context)
    String searchIn = text;
    for (final line in text.split('\n')) {
      final l = line.toLowerCase();
      if (l.contains('date:') ||
          l.contains('report date:') ||
          l.contains('collection date:') ||
          l.contains('test date:') ||
          l.contains('sample date:') ||
          l.contains('visit date:')) {
        searchIn = line;
        break;
      }
    }

    final monthMap = {
      'january': 1, 'february': 2, 'march': 3, 'april': 4,
      'may': 5, 'june': 6, 'july': 7, 'august': 8,
      'september': 9, 'october': 10, 'november': 11, 'december': 12,
      'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4,
      'jun': 6, 'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
    };

    // DD/MM/YYYY or DD-MM-YYYY or DD.MM.YYYY
    final numRegex = RegExp(r'\b(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{4})\b');
    final numMatch = numRegex.firstMatch(searchIn);
    if (numMatch != null) {
      final a = int.tryParse(numMatch.group(1)!) ?? 0;
      final b = int.tryParse(numMatch.group(2)!) ?? 0;
      final year = int.tryParse(numMatch.group(3)!) ?? 0;
      if (year >= 2000 && year <= 2099 && a >= 1 && b >= 1) {
        // Prefer DD/MM (Indian format) if a<=31 and b<=12
        if (a <= 31 && b <= 12) {
          try { return DateTime(year, b, a); } catch (_) {}
        }
        if (b <= 31 && a <= 12) {
          try { return DateTime(year, a, b); } catch (_) {}
        }
      }
    }

    // DD Month YYYY (e.g. "15 March 2024")
    final wordRegex1 = RegExp(
        r'\b(\d{1,2})\s+(january|february|march|april|may|june|july|august|september|october|november|december|jan|feb|mar|apr|jun|jul|aug|sep|oct|nov|dec)\s+(\d{4})\b',
        caseSensitive: false);
    final wm1 = wordRegex1.firstMatch(searchIn);
    if (wm1 != null) {
      final day = int.tryParse(wm1.group(1)!) ?? 0;
      final month = monthMap[wm1.group(2)!.toLowerCase()] ?? 0;
      final year = int.tryParse(wm1.group(3)!) ?? 0;
      if (day > 0 && month > 0 && year >= 2000) {
        try { return DateTime(year, month, day); } catch (_) {}
      }
    }

    // Month DD, YYYY (e.g. "March 15, 2024")
    final wordRegex2 = RegExp(
        r'\b(january|february|march|april|may|june|july|august|september|october|november|december|jan|feb|mar|apr|jun|jul|aug|sep|oct|nov|dec)\s+(\d{1,2}),?\s+(\d{4})\b',
        caseSensitive: false);
    final wm2 = wordRegex2.firstMatch(searchIn);
    if (wm2 != null) {
      final month = monthMap[wm2.group(1)!.toLowerCase()] ?? 0;
      final day = int.tryParse(wm2.group(2)!) ?? 0;
      final year = int.tryParse(wm2.group(3)!) ?? 0;
      if (day > 0 && month > 0 && year >= 2000) {
        try { return DateTime(year, month, day); } catch (_) {}
      }
    }

    return null;
  }

  /// Collect multi-line content from a labelled section.
  static String _extractSection(String rawText, List<String> labels) {
    final lines = rawText.split('\n');
    for (int i = 0; i < lines.length; i++) {
      final trimmed = lines[i].trim();
      final lower = trimmed.toLowerCase();

      for (final label in labels) {
        if (lower == label ||
            lower.startsWith('$label:') ||
            lower.startsWith('${label}s:')) {
          final buf = StringBuffer();

          // Content on the same line after the colon
          final ci = trimmed.indexOf(':');
          if (ci >= 0 && ci < trimmed.length - 1) {
            final same = trimmed.substring(ci + 1).trim();
            if (same.isNotEmpty) buf.write(same);
          }

          // Following lines until a blank gap or new header
          int blanks = 0;
          for (int j = i + 1; j < lines.length && j < i + 25; j++) {
            final next = lines[j].trim();
            if (next.isEmpty) {
              blanks++;
              if (blanks >= 2) break;
              continue;
            }
            blanks = 0;
            // Stop if next line looks like a new section header
            if (next.endsWith(':') && next.length < 50) break;
            if (next == next.toUpperCase() &&
                next.length > 4 &&
                !next.contains(RegExp(r'\d'))) {
              break;
            }
            if (buf.isNotEmpty) buf.write('\n');
            buf.write(next);
          }

          final result = buf.toString().trim();
          if (result.isNotEmpty) return result;
        }
      }
    }
    return '';
  }

  // ── Category / type / tag detection ─────────────────────────────────────────

  static String _detectCategory(String lower) {
    final scores = <String, int>{};

    void score(String cat, List<String> keywords) {
      int n = 0;
      for (final kw in keywords) {
        if (lower.contains(kw)) n++;
      }
      if (n > 0) scores[cat] = n;
    }

    score('Laboratory Reports', [
      'cbc', 'wbc', 'rbc', 'hemoglobin', 'hgb', 'platelet', 'lymphocyte',
      'neutrophil', 'blood count', 'blood test', 'lipid', 'cholesterol',
      'glucose', 'hba1c', 'creatinine', 'urea', 'bilirubin', 'sgot', 'sgpt',
      'alt ', 'ast ', 'urine test', 'urine routine', 'stool', 'culture',
      'sensitivity', 'biopsy', 'tsh', 't3 ', 't4 ', 'thyroid function',
      'allergy test', 'esr', 'ferritin', 'vitamin d', 'vitamin b12', 'calcium',
      'potassium', 'sodium', 'serum', 'plasma', 'haematology',
    ]);

    score('Radiology / Imaging', [
      'x-ray', 'x ray', 'xray', 'radiograph', 'ct scan', 'computed tomography',
      'mri', 'magnetic resonance', 'ultrasound', 'usg', 'sonography',
      'pet scan', 'mammograph', 'doppler', 'echocardiog', 'scan report',
      'imaging report',
    ]);

    score('Prescription / Medication', [
      'prescription', 'tablet', 'capsule', ' mg ', ' ml ', 'syrup',
      'injection', 'medicine', 'rx:', 'once daily', 'twice daily',
      'thrice daily', 'bd ', 'tds ', 'od ', 'sos ', 'prn', 'dose',
    ]);

    score('Hospitalization Records', [
      'admission', 'discharge', 'admitted', 'discharged', 'icu',
      'intensive care', 'emergency', 'ward ', 'inpatient', 'ip no', 'uhid',
      'discharge summary', 'admission summary',
    ]);

    score('Surgical Reports', [
      'surgery', 'surgical', 'operation', 'operative', 'pre-op', 'post-op',
      'anesthesia', 'anaesthesia', 'incision', 'suture', 'laparoscop',
      'operation notes', 'procedure notes',
    ]);

    score('Vaccination Records', [
      'vaccine', 'vaccination', 'immunization', 'immunisation', 'booster',
      'dose 1', 'dose 2', 'covid-19 vaccine', 'covishield', 'covaxin',
      'bcg', 'hepatitis b', 'polio', 'mmr',
    ]);

    score('Vital Monitoring', [
      'blood pressure', 'bp:', 'bp/', 'systolic', 'diastolic',
      'blood sugar', 'fasting', 'post prandial', 'heart rate', 'pulse rate',
      'bmi:', 'oxygen saturation', 'spo2', 'weight:', 'weight kg',
      'height cm', 'temperature',
    ]);

    score('Dental Records', [
      'dental', 'tooth', 'teeth', 'oral', 'gum', 'crown', 'filling',
      'root canal', 'extraction', 'orthodont', 'cavity', 'periodont',
    ]);

    if (scores.isEmpty) return 'Other Documents';
    return scores.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  static String _detectType(String lower) {
    if (lower.contains('cbc') ||
        lower.contains('complete blood') ||
        lower.contains('blood count')) {
      return 'Blood Test (CBC, Lipid Profile, Glucose…)';
    }
    if (lower.contains('urine')) return 'Urine Test';
    if (lower.contains('stool') || lower.contains('fecal')) return 'Stool Test';
    if (lower.contains('biopsy') || lower.contains('histopath')) return 'Biopsy / Histopathology';
    if (lower.contains('culture') && lower.contains('sensitivity')) return 'Culture & Sensitivity';
    if (lower.contains('hormone') || lower.contains('tsh') || lower.contains('thyroid')) return 'Hormone Tests';
    if (lower.contains('allergy')) return 'Allergy Tests';
    if (lower.contains('x-ray') || lower.contains('xray') || lower.contains('radiograph')) return 'X-Ray';
    if (lower.contains('ct scan') || lower.contains('computed tomography')) return 'CT Scan';
    if (lower.contains('mri') || lower.contains('magnetic resonance')) return 'MRI';
    if (lower.contains('ultrasound') || lower.contains('usg') || lower.contains('sonograph')) return 'Ultrasound';
    if (lower.contains('pet scan')) return 'PET Scan';
    if (lower.contains('mammograph')) return 'Mammography';
    if (lower.contains('doppler')) return 'Doppler Study';
    if (lower.contains('prescription') || lower.contains('rx:')) return 'New Prescription';
    if (lower.contains('discharge')) return 'Discharge Summary';
    if (lower.contains('admission') || lower.contains('admitted')) return 'Admission Summary';
    if (lower.contains('icu') || lower.contains('intensive care')) return 'ICU Records';
    if (lower.contains('emergency')) return 'Emergency Visit';
    if (lower.contains('operation notes') || lower.contains('operation report')) return 'Operation Notes';
    if (lower.contains('pre-op') || lower.contains('pre operative')) return 'Pre-operative Report';
    if (lower.contains('post-op') || lower.contains('post operative')) return 'Post-operative Report';
    if (lower.contains('vaccine') || lower.contains('vaccination')) return 'Booster Doses';
    if (lower.contains('blood pressure') || lower.contains('systolic')) return 'Blood Pressure Log';
    if (lower.contains('blood sugar') || lower.contains('hba1c') || lower.contains('glucose')) return 'Blood Sugar Log';
    if (lower.contains('heart rate') || lower.contains('pulse rate')) return 'Heart Rate Monitoring';
    if (lower.contains('weight') && (lower.contains('kg') || lower.contains('bmi'))) return 'Weight Tracking';
    if (lower.contains('spo2') || lower.contains('oxygen saturation')) return 'Oxygen Saturation';
    if (lower.contains('dental') || lower.contains('oral') || lower.contains('tooth')) return 'Oral Checkup';
    return 'Miscellaneous Reports';
  }

  static List<String> _detectTags(String lower) {
    const tagMap = {
      'Diabetes': ['diabetes', 'diabetic', 'hba1c', 'fasting glucose', 'blood sugar', 'insulin'],
      'Hypertension': ['hypertension', 'high blood pressure', 'systolic', 'diastolic', 'bp:'],
      'Anemia': ['anemia', 'anaemia', 'low hemoglobin', 'iron deficiency', 'ferritin'],
      'Heart Disease': ['cardiac', 'coronary', 'ecg', 'ekg', 'heart disease', 'angina', 'myocardial', 'arrhythmia'],
      'Thyroid': ['thyroid', 'tsh', 'hypothyroid', 'hyperthyroid', 't3 ', 't4 '],
      'Asthma': ['asthma', 'bronchial', 'spirometry', 'peak flow', 'wheez'],
      'Obesity': ['obesity', 'obese', 'overweight', 'bmi:'],
      'Arthritis': ['arthritis', 'joint pain', 'rheumatoid', 'osteoporosis', 'ra factor', 'uric acid'],
    };

    final tags = <String>[];
    for (final entry in tagMap.entries) {
      for (final kw in entry.value) {
        if (lower.contains(kw)) {
          tags.add(entry.key);
          break;
        }
      }
    }
    return tags;
  }
}
