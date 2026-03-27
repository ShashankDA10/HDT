# BodyClone Backend

Python Flask backend for the BodyClone mobile application.

## Setup

1. Create a virtual environment:
   ```bash
   python -m venv venv
   ```

2. Activate the virtual environment:
   - Windows: `venv\Scripts\activate`
   - macOS/Linux: `source venv/bin/activate`

3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

4. Run the server:
   ```bash
   python app.py
   ```

The API will be available at `http://localhost:5000`

## API Endpoints

- `GET /` - Health check
- `GET /api/health` - API health status

