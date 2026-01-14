# Save It 📥

A powerful, personal media downloader app for **Instagram**, **Facebook**, and **X (Twitter)**. Download videos, reels, and images directly to your phone's gallery with just one tap.

![Flutter](https://img.shields.io/badge/Flutter-3.9+-blue?logo=flutter)
![Node.js](https://img.shields.io/badge/Node.js-18+-green?logo=node.js)
![License](https://img.shields.io/badge/License-Personal_Use-orange)

---

## ✨ Features

- 🎬 **Download Videos** - Save videos from Instagram Reels, Facebook, and X
- 📸 **Download Images** - Save photos and thumbnails
- 📁 **Gallery Integration** - Downloads appear directly in your phone's gallery under "SaveIt" album  
- 🔗 **Smart URL Detection** - Automatically detects platform from pasted URLs
- 📊 **Download Progress** - Real-time progress tracking with percentage
- 🎨 **Modern UI** - Beautiful, intuitive interface with dark mode

---

## 📱 Supported Platforms

| Platform | Videos | Images | Reels/Stories |
|----------|--------|--------|---------------|
| **Instagram** | ✅ | ✅ | ✅ Reels |
| **Facebook** | ✅ | ✅ | ✅ Watch Videos |
| **X (Twitter)** | ✅ | ✅ | ✅ |

---

## 🏗️ Architecture

This app uses a **client-server architecture** for reliable media extraction:

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Flutter App   │────▶│  Backend Server │────▶│ Social Platforms│
│   (Frontend)    │◀────│   (Node.js)     │◀────│ (IG, FB, X)     │
└─────────────────┘     └─────────────────┘     └─────────────────┘
         │
         ▼
    📱 Gallery
```

### Why a Backend?

Social media platforms actively block direct API requests from mobile apps. The backend server:
- Acts as a proxy with proper browser headers
- Uses Puppeteer for headless browser rendering when needed
- Implements multiple fallback extraction methods
- Handles platform-specific quirks and anti-scraping measures

---

## 🚀 Getting Started

### Prerequisites

- **Flutter** 3.9 or higher
- **Node.js** 18 or higher
- **Android Studio** or **VS Code** with Flutter extensions
- A physical Android/iOS device or emulator

### Installation

#### 1. Clone the Repository

```bash
git clone https://github.com/SulemanAI/Save-It
cd Save-It
```

#### 2. Install Flutter Dependencies

```bash
flutter pub get
```

#### 3. Install Backend Dependencies

```bash
cd backend
npm install
```

#### 4. Start the Backend Server

```bash
npm start
```

The server will start on `http://localhost:3000`

#### 5. Configure the App

Edit `lib/services/backend_api.dart` and set your backend URL:

**For Android Emulator:**
```dart
static String baseUrl = 'http://10.0.2.2:3000';
```

**For Physical Device (same network):**
```dart
static String baseUrl = 'http://YOUR_LOCAL_IP:3000';
```

Find your local IP:
- Windows: `ipconfig` → IPv4 Address
- Mac/Linux: `ifconfig` or `ip addr`

#### 6. Run the App

```bash
flutter run
```

---

## 📂 Project Structure

```
save_it/
├── lib/
│   ├── core/
│   │   └── constants.dart       # App-wide constants
│   ├── models/
│   │   └── media_info.dart      # Data models
│   ├── screens/
│   │   └── home_screen.dart     # Main UI
│   ├── services/
│   │   ├── backend_api.dart     # Backend communication
│   │   ├── download_service.dart # File downloading
│   │   ├── media_service.dart   # Media extraction coordination
│   │   └── platforms/           # Platform-specific handlers
│   ├── utils/
│   │   └── url_parser.dart      # URL parsing utilities
│   ├── widgets/                 # Reusable UI components
│   └── main.dart                # App entry point
├── backend/
│   ├── server.js                # Express server with extraction logic
│   ├── package.json             # Node.js dependencies
│   └── README.md                # Backend documentation
├── android/                     # Android platform files
├── ios/                         # iOS platform files
└── pubspec.yaml                 # Flutter dependencies
```

---

## 🔧 Backend API

### Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/health` | Health check |
| `POST` | `/api/extract` | Extract media from URL |

### Extract Media Request

```json
POST /api/extract
{
  "url": "https://www.instagram.com/reel/ABC123/"
}
```

### Response (Success)

```json
{
  "success": true,
  "platform": "instagram",
  "media": [
    {
      "url": "https://cdn.instagram.com/video.mp4",
      "type": "video"
    }
  ]
}
```

### Response (Error)

```json
{
  "success": false,
  "error": "No media found. The content may be private."
}
```

---

## 📦 Dependencies

### Flutter (Frontend)

| Package | Purpose |
|---------|---------|
| `http` | HTTP client for API calls |
| `path_provider` | File system access |
| `permission_handler` | Storage permissions |
| `image_gallery_saver` | Save files to gallery |
| `fluttertoast` | Toast notifications |
| `share_plus` | Share functionality |
| `url_launcher` | Open external links |

### Node.js (Backend)

| Package | Purpose |
|---------|---------|
| `express` | Web server framework |
| `axios` | HTTP client |
| `cheerio` | HTML parsing |
| `puppeteer` | Headless browser for complex extraction |
| `cors` | Cross-origin resource sharing |

---

## 🚀 Deployment

### Backend Deployment Options

#### Railway (Recommended)

1. Create a [Railway](https://railway.app) account
2. Connect your GitHub repository
3. Deploy the `backend` folder
4. Get your deployment URL
5. Update `baseUrl` in the Flutter app

#### Render

1. Create a [Render](https://render.com) account
2. Create a new Web Service
3. Connect your repository and select `backend` folder
4. Set build command: `npm install`
5. Set start command: `npm start`

#### Self-Hosted

```bash
cd backend
npm install
NODE_ENV=production npm start
```

---

## 🔐 Permissions

### Android

The app requires these permissions (automatically requested):

- `INTERNET` - Network access
- `READ_EXTERNAL_STORAGE` - Read files
- `WRITE_EXTERNAL_STORAGE` - Save files
- `READ_MEDIA_VIDEO` - Access videos (Android 13+)
- `READ_MEDIA_IMAGES` - Access images (Android 13+)

### iOS

- Photo Library access for saving media

---

## ⚠️ Limitations

- **Private Content**: Cannot download private/protected content
- **Stories**: Instagram Stories require login (not supported)
- **Rate Limits**: Excessive use may trigger temporary blocks
- **Platform Changes**: Social media platforms frequently update their systems

---

## 🐛 Troubleshooting

### "Backend not available"

1. Ensure the backend server is running (`npm start` in backend folder)
2. Check the `baseUrl` in `backend_api.dart`
3. Verify your device and computer are on the same network

### "No media found"

- The content may be private
- The URL may be invalid or expired
- Try a different post from the same platform

### "Storage permission denied"

- Go to Settings → Apps → Save It → Permissions
- Enable Storage/Media access

### Download not appearing in Gallery

- Check the "SaveIt" album in your gallery
- Try refreshing the gallery app

---

## 📄 License

This project is for **personal use only**. Do not redistribute or use for commercial purposes.

---

## 🙏 Acknowledgments

- [Flutter](https://flutter.dev) - UI framework
- [Puppeteer](https://pptr.dev) - Browser automation
- Platform extraction methods inspired by various open-source projects

---

## 📞 Support

For issues and feature requests, please open an issue on GitHub.

---

**Made with ❤️ for personal media archiving**
