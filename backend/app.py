from flask import Flask, jsonify, request
from flask_cors import CORS
from werkzeug.utils import secure_filename
from datetime import datetime, timedelta
import random
import os

app = Flask(__name__)
CORS(app)

# Configure upload folder
UPLOAD_FOLDER = 'uploads'
ALLOWED_EXTENSIONS = {'pdf', 'png', 'jpg', 'jpeg', 'doc', 'docx', 'txt'}
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER
app.config['MAX_CONTENT_LENGTH'] = 16 * 1024 * 1024  # 16MB max file size

# Create upload folder if it doesn't exist
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

# Sample health data storage (in production, use a database)
health_data = {
    'vitals': {
        'heart_rate': 72,
        'blood_pressure': {'systolic': 120, 'diastolic': 80},
        'temperature': 98.6,
        'oxygen_saturation': 98,
        'last_updated': datetime.now().isoformat()
    },
    'reports': [
        {
            'id': 1,
            'type': 'Blood Test',
            'date': (datetime.now() - timedelta(days=7)).isoformat(),
            'status': 'Normal',
            'summary': 'All parameters within normal range'
        },
        {
            'id': 2,
            'type': 'ECG',
            'date': (datetime.now() - timedelta(days=14)).isoformat(),
            'status': 'Normal',
            'summary': 'Regular rhythm, no abnormalities detected'
        }
    ],
    'medication': [
        {
            'id': 1,
            'name': 'Vitamin D',
            'dosage': '1000 IU',
            'frequency': 'Once daily',
            'next_dose': (datetime.now() + timedelta(hours=8)).isoformat(),
            'status': 'active'
        },
        {
            'id': 2,
            'name': 'Multivitamin',
            'dosage': '1 tablet',
            'frequency': 'Once daily',
            'next_dose': (datetime.now() + timedelta(hours=8)).isoformat(),
            'status': 'active'
        }
    ],
    'consultations': [
        {
            'id': 1,
            'doctor': 'Dr. Sarah Johnson',
            'specialty': 'General Medicine',
            'date': (datetime.now() + timedelta(days=5)).isoformat(),
            'status': 'scheduled',
            'notes': 'Annual checkup'
        }
    ],
    'avatar_mood': 'calm'
}

@app.route('/')
def health_check():
    return jsonify({'status': 'ok', 'message': 'BodyClone API is running'})

@app.route('/api/health')
def api_health():
    return jsonify({'status': 'healthy'})

# Health Metrics Endpoints
@app.route('/api/vitals', methods=['GET'])
def get_vitals():
    """Get current vital signs"""
    # Simulate slight variations in real-time data
    vitals = health_data['vitals'].copy()
    vitals['heart_rate'] = random.randint(68, 76)
    vitals['temperature'] = round(random.uniform(98.2, 98.8), 1)
    vitals['last_updated'] = datetime.now().isoformat()
    return jsonify(vitals)

@app.route('/api/reports', methods=['GET'])
def get_reports():
    """Get medical reports"""
    return jsonify({
        'reports': health_data['reports'],
        'count': len(health_data['reports'])
    })

@app.route('/api/reports/upload', methods=['POST'])
def upload_report():
    """Upload a report or prescription file"""
    if 'file' not in request.files:
        return jsonify({'error': 'No file provided'}), 400
    
    file = request.files['file']
    is_prescription = request.form.get('is_prescription', 'false').lower() == 'true'
    file_name = request.form.get('file_name', file.filename)
    
    if file.filename == '':
        return jsonify({'error': 'No file selected'}), 400
    
    if file and allowed_file(file.filename):
        filename = secure_filename(file_name or file.filename)
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        filename = f"{timestamp}_{filename}"
        filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
        file.save(filepath)
        
        # Create report entry
        report_type = 'Prescription' if is_prescription else 'Medical Report'
        new_report = {
            'id': len(health_data['reports']) + 1,
            'type': report_type,
            'date': datetime.now().isoformat(),
            'status': 'Uploaded',
            'summary': f'Uploaded {report_type.lower()}',
            'file_path': filepath,
            'file_name': file_name or file.filename
        }
        health_data['reports'].append(new_report)
        
        # If it's a prescription, also add to medication if needed
        if is_prescription:
            # Create or update medication entry
            medication_id = len(health_data['medication']) + 1
            new_medication = {
                'id': medication_id,
                'name': 'Prescription Document',
                'dosage': 'As prescribed',
                'frequency': 'See prescription',
                'next_dose': datetime.now().isoformat(),
                'status': 'active',
                'prescription_path': filepath,
                'prescription_file_name': file_name or file.filename,
                'prescription_upload_date': datetime.now().isoformat()
            }
            health_data['medication'].append(new_medication)
        
        return jsonify({
            'message': 'File uploaded successfully',
            'report': new_report
        }), 201
    
    return jsonify({'error': 'File type not allowed'}), 400

@app.route('/api/reports/from-voice', methods=['POST'])
def create_voice_report():
    """Create a medical report from voice dictation"""
    data = request.get_json()
    
    if not data or 'transcript' not in data:
        return jsonify({'error': 'Transcript required'}), 400
    
    transcript = data['transcript']
    structured_data = data.get('structured_data', {})
    
    # Extract structured fields (from n8n AI processing)
    patient_name = structured_data.get('patient_name', 'Unknown Patient')
    complaints = structured_data.get('complaints', '')
    diagnosis = structured_data.get('diagnosis', '')
    notes = structured_data.get('notes', '')
    prescription = structured_data.get('prescription', '')
    
    # Create report entry
    new_report = {
        'id': len(health_data['reports']) + 1,
        'type': 'Voice Report',
        'date': datetime.now().isoformat(),
        'status': 'Completed',
        'summary': diagnosis[:100] if diagnosis else 'Medical consultation report',
        'patient_name': patient_name,
        'complaints': complaints,
        'diagnosis': diagnosis,
        'notes': notes,
        'prescription': prescription,
        'raw_transcript': transcript,
        'is_voice_report': True
    }
    
    health_data['reports'].append(new_report)
    
    return jsonify({
        'message': 'Voice report created successfully',
        'report': new_report
    }), 201

@app.route('/api/medication', methods=['GET'])
def get_medication():
    """Get medication schedule"""
    return jsonify({
        'medications': health_data['medication'],
        'count': len(health_data['medication'])
    })

@app.route('/api/consultations', methods=['GET'])
def get_consultations():
    """Get upcoming consultations"""
    return jsonify({
        'consultations': health_data['consultations'],
        'count': len(health_data['consultations'])
    })

@app.route('/api/avatar/mood', methods=['GET'])
def get_avatar_mood():
    """Get current avatar mood state"""
    return jsonify({
        'mood': health_data['avatar_mood'],
        'timestamp': datetime.now().isoformat()
    })

@app.route('/api/avatar/mood', methods=['POST'])
def set_avatar_mood():
    """Update avatar mood state"""
    data = request.get_json()
    if 'mood' in data:
        health_data['avatar_mood'] = data['mood']
        return jsonify({
            'mood': health_data['avatar_mood'],
            'message': 'Avatar mood updated successfully'
        })
    return jsonify({'error': 'Mood parameter required'}), 400

@app.route('/api/health/summary', methods=['GET'])
def get_health_summary():
    """Get overall health summary"""
    return jsonify({
        'vitals': health_data['vitals'],
        'reports_count': len(health_data['reports']),
        'medications_count': len(health_data['medication']),
        'consultations_count': len(health_data['consultations']),
        'avatar_mood': health_data['avatar_mood'],
        'overall_status': 'Good',
        'last_updated': datetime.now().isoformat()
    })

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)

