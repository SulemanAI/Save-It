# Save It - Backend Server

Node.js backend server for the Save It media downloader app.

## Quick Start

### 1. Install Dependencies

```bash
cd backend
npm install
```

### 2. Run the Server

```bash
npm start
```

The server will start on `http://localhost:3000`

## Endpoints

### Health Check
```
GET /health
```

### Extract Media
```
POST /api/extract
Content-Type: application/json

{
  "url": "https://www.instagram.com/p/ABC123/"
}
```

Response:
```json
{
  "success": true,
  "platform": "instagram",
  "media": [
    {
      "url": "https://...",
      "type": "video"
    }
  ]
}
```

## Connecting from Flutter App

### Android Emulator
The app is configured to use `10.0.2.2:3000` which maps to `localhost` on your development machine.

### Physical Device
1. Find your computer's local IP address:
   - Windows: `ipconfig` → Look for IPv4 Address
   - Mac/Linux: `ifconfig` or `ip addr`

2. Update `lib/services/backend_api.dart`:
   ```dart
   static String baseUrl = 'http://YOUR_IP:3000';
   ```

3. Make sure your phone and computer are on the same network.

## Deployment

### Option 1: Railway.app (Free Tier)
1. Push to GitHub
2. Connect Railway to your repo
3. Deploy the `/backend` folder
4. Get the public URL
5. Update Flutter app with the URL

### Option 2: Render.com (Free Tier)
1. Push to GitHub
2. Create a new Web Service on Render
3. Point to the `/backend` folder
4. Deploy and get the URL

### Option 3: Heroku
```bash
cd backend
heroku create your-app-name
git push heroku main
```

## Environment Variables

- `PORT`: Server port (default: 3000)

## Troubleshooting

### "Cannot connect to server"
- Make sure the backend is running (`npm start`)
- Check if using correct IP address for physical devices
- Ensure phone and computer are on same network

### "No media found"
- The content may be private
- The platform may have changed their API
- Rate limiting may be occurring
