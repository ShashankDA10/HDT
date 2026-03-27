# N8N Workflow Setup for AI Medical Report Structuring

This guide explains how to set up an n8n workflow to structure medical report transcripts using AI.

## Overview

The workflow receives a raw transcript from the Flutter app, sends it to an LLM (OpenAI, Anthropic, etc.), and returns structured JSON with medical report fields.

## Workflow Architecture

```
Webhook (Receive transcript)
    ↓
HTTP Request (Send to LLM)
    ↓
Code Node (Parse & Structure JSON)
    ↓
Response (Return structured data)
```

## Step-by-Step Setup

### 1. Create New Workflow in n8n

1. Open n8n (usually at `http://localhost:5678`)
2. Click "New Workflow"
3. Name it "Medical Report Structuring"

### 2. Add Webhook Node

1. Add a **Webhook** node
2. Configure:
   - **HTTP Method**: POST
   - **Path**: `/webhook/medical-report`
   - **Response Mode**: "Respond When Last Node Finishes"
3. Click "Listen for Test Event" to get the webhook URL
4. Copy the webhook URL (e.g., `http://localhost:5678/webhook/medical-report`)

### 3. Update Flutter App

Update `lib/services/n8n_service.dart`:

```dart
static const String n8nWebhookUrl = 'http://YOUR_N8N_URL/webhook/medical-report';
```

For production, use your n8n instance URL.

### 4. Add HTTP Request Node (LLM Call)

1. Add an **HTTP Request** node after the Webhook
2. Configure for **OpenAI** (or your preferred LLM):

**For OpenAI:**
- **Method**: POST
- **URL**: `https://api.openai.com/v1/chat/completions`
- **Authentication**: Header Auth
  - **Name**: `Authorization`
  - **Value**: `Bearer YOUR_OPENAI_API_KEY`
- **Headers**:
  - `Content-Type`: `application/json`
- **Body**:
```json
{
  "model": "gpt-4o-mini",
  "messages": [
    {
      "role": "system",
      "content": "You are a medical assistant that structures doctor dictations into JSON format. Extract patient information, symptoms, diagnosis, notes, and prescriptions from the transcript."
    },
    {
      "role": "user",
      "content": "Convert this doctor's dictation into a structured medical report with the following fields: patient_name, date, complaints, diagnosis, notes, prescription. Transcript: {{ $json.transcript }}"
    }
  ],
  "temperature": 0.3,
  "response_format": { "type": "json_object" }
}
```

**For Anthropic Claude:**
- **Method**: POST
- **URL**: `https://api.anthropic.com/v1/messages`
- **Authentication**: Header Auth
  - **Name**: `x-api-key`
  - **Value**: `YOUR_ANTHROPIC_API_KEY`
  - **Name**: `anthropic-version`
  - **Value**: `2023-06-01`
- **Body**:
```json
{
  "model": "claude-3-5-sonnet-20241022",
  "max_tokens": 1024,
  "system": "You are a medical assistant that structures doctor dictations into JSON format.",
  "messages": [
    {
      "role": "user",
      "content": "Convert this doctor's dictation into a structured medical report with fields: patient_name, date, complaints, diagnosis, notes, prescription. Transcript: {{ $json.transcript }}"
    }
  ]
}
```

### 5. Add Code Node (Parse Response)

1. Add a **Code** node after the HTTP Request
2. Use **JavaScript**:
```javascript
// Parse LLM response
const llmResponse = $input.item.json;

// Extract the structured data from LLM response
let structuredData;

if (llmResponse.choices && llmResponse.choices[0]) {
  // OpenAI format
  const content = llmResponse.choices[0].message.content;
  structuredData = JSON.parse(content);
} else if (llmResponse.content && llmResponse.content[0]) {
  // Anthropic format
  const content = llmResponse.content[0].text;
  structuredData = JSON.parse(content);
} else {
  // Direct JSON response
  structuredData = llmResponse;
}

// Ensure all required fields exist
const result = {
  patient_name: structuredData.patient_name || 'Unknown Patient',
  date: structuredData.date || new Date().toISOString().split('T')[0],
  complaints: structuredData.complaints || structuredData.symptoms || '',
  diagnosis: structuredData.diagnosis || '',
  notes: structuredData.notes || structuredData.notes || '',
  prescription: structuredData.prescription || structuredData.medications || ''
};

return result;
```

### 6. Add Response Node

1. Add a **Respond to Webhook** node (or use the Webhook's response)
2. Set the response body to:
```json
{{ $json }}
```

### 7. Activate Workflow

1. Click "Save" in n8n
2. Toggle "Active" to enable the workflow
3. The webhook is now ready to receive requests

## Expected JSON Response Format

The workflow should return:

```json
{
  "patient_name": "Ramesh Kumar",
  "date": "2026-01-27",
  "complaints": "Patient complains of persistent headache and fatigue for the past week",
  "diagnosis": "Migraine with tension headache component",
  "notes": "Patient advised to maintain regular sleep schedule and reduce screen time",
  "prescription": "Paracetamol 500mg twice daily for 3 days. Follow up in 1 week if symptoms persist."
}
```

## Testing the Workflow

### Test with n8n UI:
1. Click "Execute Workflow"
2. In the Webhook node, click "Listen for Test Event"
3. Send a test POST request:
```bash
curl -X POST http://localhost:5678/webhook/medical-report \
  -H "Content-Type: application/json" \
  -d '{
    "transcript": "Patient Ramesh Kumar, age 45. Complains of headache and fatigue. Diagnosis: Migraine. Prescribe Paracetamol 500mg twice daily."
  }'
```

### Test from Flutter App:
1. Run the app
2. Go to Reports → Record Voice Report
3. Record or enter test transcript
4. Click "Generate Report"
5. Check n8n execution logs

## Alternative: Using n8n AI Nodes

If you have n8n AI nodes installed:

1. Use **OpenAI** node instead of HTTP Request
2. Configure:
   - **Operation**: Chat
   - **Model**: gpt-4o-mini
   - **System Message**: "You are a medical assistant..."
   - **User Message**: "Convert this transcript: {{ $json.transcript }}"
3. Add **Code** node to parse response

## Environment Variables

For production, use n8n environment variables:

1. Go to Settings → Environment Variables
2. Add:
   - `OPENAI_API_KEY` (or `ANTHROPIC_API_KEY`)
3. In HTTP Request node, use: `{{ $env.OPENAI_API_KEY }}`

## Security Considerations

1. **API Keys**: Never commit API keys to git
2. **Webhook Security**: Consider adding authentication
3. **Rate Limiting**: Implement rate limiting in n8n
4. **Data Privacy**: Ensure HIPAA compliance for medical data

## Troubleshooting

### Webhook not receiving requests:
- Check n8n workflow is active
- Verify webhook URL in Flutter app
- Check n8n logs for errors

### LLM not responding:
- Verify API key is correct
- Check API quota/limits
- Review request format

### JSON parsing errors:
- Ensure LLM returns valid JSON
- Check Code node logic
- Add error handling

## Example Prompt Template

For better results, use this prompt:

```
Convert this doctor's medical dictation into a structured JSON report.

Required fields:
- patient_name: Full name of the patient
- date: Date of consultation (YYYY-MM-DD format)
- complaints: Patient's symptoms and complaints
- diagnosis: Medical diagnosis
- notes: Additional clinical notes
- prescription: Medications and dosages prescribed

Transcript: {{ $json.transcript }}

Return ONLY valid JSON, no additional text.
```

## Next Steps

1. Set up n8n workflow as described
2. Test with sample transcripts
3. Fine-tune the prompt for your use case
4. Deploy n8n to production server
5. Update webhook URL in Flutter app

