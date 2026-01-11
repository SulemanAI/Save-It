/**
 * Save It - Backend Server
 * 
 * This server handles media extraction from social media platforms.
 * Uses Puppeteer for browser-based extraction to bypass anti-scraping measures.
 * 
 * Endpoints:
 * - POST /api/extract - Extract media from a URL
 * - GET /health - Health check
 */

const express = require('express');
const cors = require('cors');
const axios = require('axios');
const cheerio = require('cheerio');
const puppeteer = require('puppeteer');

const app = express();
const PORT = process.env.PORT || 3000;

// Global browser instance (reused for performance)
let browser = null;

// Middleware
app.use(cors());
app.use(express.json());

// Common headers for requests
const DESKTOP_HEADERS = {
  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
  'Accept-Language': 'en-US,en;q=0.5',
  'Accept-Encoding': 'gzip, deflate',
  'Connection': 'keep-alive',
};

const MOBILE_HEADERS = {
  'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1',
  'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
  'Accept-Language': 'en-US,en;q=0.5',
};

// Initialize browser
async function initBrowser() {
  if (!browser) {
    console.log('[Browser] Launching headless browser...');
    browser = await puppeteer.launch({
      headless: 'new',
      args: [
        '--no-sandbox',
        '--disable-setuid-sandbox',
        '--disable-dev-shm-usage',
        '--disable-accelerated-2d-canvas',
        '--disable-gpu',
        '--window-size=1920,1080',
      ],
    });
    console.log('[Browser] Browser ready');
  }
  return browser;
}

// Helper function for delay (replaces deprecated waitForTimeout)
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Main extraction endpoint
app.post('/api/extract', async (req, res) => {
  try {
    const { url } = req.body;

    if (!url) {
      return res.status(400).json({ success: false, error: 'URL is required' });
    }

    console.log(`[Extract] Processing: ${url}`);

    // Detect platform
    const platform = detectPlatform(url);

    if (platform === 'unknown') {
      return res.status(400).json({
        success: false,
        error: 'Unsupported platform. Use Instagram, Facebook, or X (Twitter) URLs.'
      });
    }

    let result;

    switch (platform) {
      case 'instagram':
        result = await extractInstagram(url);
        break;
      case 'facebook':
        result = await extractFacebook(url);
        break;
      case 'twitter':
        result = await extractTwitter(url);
        break;
      default:
        return res.status(400).json({ success: false, error: 'Unsupported platform' });
    }

    if (result.success) {
      console.log(`[Extract] Success: Found ${result.media.length} media items`);
    } else {
      console.log(`[Extract] Failed: ${result.error}`);
    }

    res.json(result);
  } catch (error) {
    console.error('[Extract] Error:', error.message);
    res.status(500).json({
      success: false,
      error: 'Server error: ' + error.message
    });
  }
});

// Detect platform from URL
function detectPlatform(url) {
  const lowerUrl = url.toLowerCase();
  if (lowerUrl.includes('instagram.com') || lowerUrl.includes('instagr.am')) {
    return 'instagram';
  } else if (lowerUrl.includes('facebook.com') || lowerUrl.includes('fb.com') || lowerUrl.includes('fb.watch')) {
    return 'facebook';
  } else if (lowerUrl.includes('twitter.com') || lowerUrl.includes('x.com')) {
    return 'twitter';
  }
  return 'unknown';
}

// Extract from Instagram using Puppeteer (browser-based)
async function extractInstagram(url) {
  let page = null;

  try {
    const media = [];

    // Normalize URL
    let normalizedUrl = url;
    if (!url.endsWith('/')) normalizedUrl += '/';

    console.log('[Instagram] Starting browser-based extraction...');

    // Get browser instance
    const browserInstance = await initBrowser();
    page = await browserInstance.newPage();

    // Set viewport and user agent
    await page.setViewport({ width: 1920, height: 1080 });
    await page.setUserAgent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');

    // Block unnecessary resources for faster loading
    await page.setRequestInterception(true);
    page.on('request', (request) => {
      const resourceType = request.resourceType();
      if (['image', 'stylesheet', 'font'].includes(resourceType)) {
        request.abort();
      } else {
        request.continue();
      }
    });

    // Navigate to the URL
    console.log('[Instagram] Navigating to:', normalizedUrl);
    await page.goto(normalizedUrl, {
      waitUntil: 'networkidle2',
      timeout: 30000,
    });

    // Wait a bit for dynamic content
    await delay(2000);

    // Get page content
    const content = await page.content();

    // Method 1: Look for video sources in the rendered HTML
    const videoSources = await page.evaluate(() => {
      const sources = [];

      // Find all video elements
      const videos = document.querySelectorAll('video');
      videos.forEach(video => {
        if (video.src) sources.push(video.src);
        // Also check source elements
        const sourceTags = video.querySelectorAll('source');
        sourceTags.forEach(source => {
          if (source.src) sources.push(source.src);
        });
      });

      return sources;
    });

    for (const src of videoSources) {
      if (src && !media.some(m => m.url === src)) {
        console.log('[Instagram] Found video source:', src.substring(0, 80));
        media.push({ url: src, type: 'video' });
      }
    }

    // Method 2: Look for video_url in page scripts
    const scriptContent = await page.evaluate(() => {
      const scripts = document.querySelectorAll('script');
      let result = '';
      scripts.forEach(script => {
        if (script.textContent && script.textContent.includes('video_url')) {
          result += script.textContent;
        }
      });
      return result;
    });

    if (scriptContent) {
      const videoUrlMatches = scriptContent.matchAll(/"video_url"\s*:\s*"([^"]+)"/g);
      for (const match of videoUrlMatches) {
        const videoUrl = unescapeUrl(match[1]);
        if (!media.some(m => m.url === videoUrl)) {
          console.log('[Instagram] Found video_url in script');
          media.push({ url: videoUrl, type: 'video' });
        }
      }

      const displayUrlMatches = scriptContent.matchAll(/"display_url"\s*:\s*"([^"]+)"/g);
      for (const match of displayUrlMatches) {
        const imageUrl = unescapeUrl(match[1]);
        if (!media.some(m => m.url === imageUrl)) {
          console.log('[Instagram] Found display_url in script');
          media.push({ url: imageUrl, type: 'image' });
        }
      }
    }

    // Method 3: Check og meta tags
    const ogVideo = await page.$eval('meta[property="og:video"]', el => el.content).catch(() => null);
    if (ogVideo && !media.some(m => m.url === ogVideo)) {
      console.log('[Instagram] Found og:video');
      media.push({ url: ogVideo, type: 'video' });
    }

    const ogImage = await page.$eval('meta[property="og:image"]', el => el.content).catch(() => null);
    if (ogImage && !media.some(m => m.url === ogImage)) {
      console.log('[Instagram] Found og:image');
      media.push({ url: ogImage, type: 'image' });
    }

    // Method 4: Try to find in network requests (intercept)
    // Look for any CDN URLs in the page content - but filter out static resources
    const cdnUrlMatches = content.matchAll(/https:\/\/[^"'\s]*?(?:cdninstagram|fbcdn)[^"'\s]*?(?:\.mp4|\.jpg|\.jpeg)[^"'\s]*/gi);
    for (const match of cdnUrlMatches) {
      let cdnUrl = match[0];
      cdnUrl = cdnUrl.replace(/\\/g, '');
      // Filter out static resources (rsrc.php, emoji, icons, etc.)
      if (cdnUrl.includes('rsrc.php') || cdnUrl.includes('emoji') || cdnUrl.includes('/static/')) {
        continue;
      }
      if (!media.some(m => m.url === cdnUrl)) {
        const isVideo = cdnUrl.includes('.mp4');
        console.log('[Instagram] Found CDN URL:', cdnUrl.substring(0, 80));
        media.push({ url: cdnUrl, type: isVideo ? 'video' : 'image' });
      }
    }

    // Close the page
    await page.close();
    page = null;

    if (media.length === 0) {
      return {
        success: false,
        error: 'No media found. The content may be private or require login.'
      };
    }

    // Remove duplicates
    const uniqueMedia = removeDuplicates(media);

    console.log('[Instagram] Found', uniqueMedia.length, 'unique media items');
    return { success: true, platform: 'instagram', media: uniqueMedia };

  } catch (error) {
    console.error('[Instagram] Browser extraction error:', error.message);

    // Close page if still open
    if (page) {
      try { await page.close(); } catch (e) { }
    }

    return { success: false, error: 'Browser extraction failed: ' + error.message };
  }
}

// Extract from Facebook
async function extractFacebook(url) {
  try {
    const media = [];

    // Try mobile site first
    let mobileUrl = url
      .replace('www.facebook.com', 'm.facebook.com')
      .replace('web.facebook.com', 'm.facebook.com');

    try {
      const response = await axios.get(mobileUrl, {
        headers: MOBILE_HEADERS,
        timeout: 15000,
        maxRedirects: 5,
      });

      const html = response.data;

      // Look for HD video
      let hdMatch = html.match(/playable_url_quality_hd["\s:]+([^"]+)/);
      if (hdMatch) {
        const videoUrl = unescapeUrl(hdMatch[1]);
        if (videoUrl.startsWith('http')) {
          media.push({ url: videoUrl, type: 'video', quality: 'HD' });
        }
      }

      // SD fallback
      if (media.length === 0) {
        const sdMatch = html.match(/"playable_url"\s*:\s*"([^"]+)"/);
        if (sdMatch) {
          const videoUrl = unescapeUrl(sdMatch[1]);
          if (videoUrl.startsWith('http')) {
            media.push({ url: videoUrl, type: 'video', quality: 'SD' });
          }
        }
      }

      // Try og:video
      const $ = cheerio.load(html);
      const ogVideo = $('meta[property="og:video"]').attr('content');
      if (ogVideo && media.length === 0) {
        media.push({ url: ogVideo, type: 'video' });
      }

      // og:image
      const ogImage = $('meta[property="og:image"]').attr('content');
      if (ogImage) {
        media.push({ url: ogImage, type: 'image' });
      }
    } catch (e) {
      console.log('[Facebook] Mobile method failed:', e.message);
    }

    // Try desktop if mobile failed
    if (media.length === 0) {
      try {
        const response = await axios.get(url, {
          headers: DESKTOP_HEADERS,
          timeout: 15000,
        });

        const html = response.data;
        const $ = cheerio.load(html);

        const ogVideo = $('meta[property="og:video:url"]').attr('content');
        if (ogVideo) {
          media.push({ url: ogVideo, type: 'video' });
        }

        const ogImage = $('meta[property="og:image"]').attr('content');
        if (ogImage) {
          media.push({ url: ogImage, type: 'image' });
        }
      } catch (e) {
        console.log('[Facebook] Desktop method failed:', e.message);
      }
    }

    if (media.length === 0) {
      return { success: false, error: 'No media found. The content may be private.' };
    }

    return { success: true, platform: 'facebook', media: removeDuplicates(media) };
  } catch (error) {
    return { success: false, error: error.message };
  }
}

// Extract from Twitter/X
async function extractTwitter(url) {
  try {
    const media = [];

    // Extract tweet ID - handle various URL formats
    let tweetId = null;
    const patterns = [
      /status\/(\d+)/,
      /\/(\d{10,})/,
    ];

    for (const pattern of patterns) {
      const match = url.match(pattern);
      if (match) {
        tweetId = match[1];
        break;
      }
    }

    if (!tweetId) {
      return { success: false, error: 'Invalid tweet URL - could not extract tweet ID' };
    }

    console.log('[Twitter] Tweet ID:', tweetId);

    // Normalize URL to twitter.com format
    const normalizedUrl = url.replace('x.com', 'twitter.com');

    // Method 1: Try ssstwitter web scraping (most reliable current method)
    try {
      console.log('[Twitter] Trying ssstwitter...');

      // First, get the page to extract token
      const pageResponse = await axios.get('https://ssstwitter.com/', {
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Accept': 'text/html',
        },
        timeout: 10000,
      });

      // Submit the URL
      const formResponse = await axios.post('https://ssstwitter.com/result',
        `id=${encodeURIComponent(normalizedUrl)}&locale=en`,
        {
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Accept': 'text/html,application/xhtml+xml',
            'Content-Type': 'application/x-www-form-urlencoded',
            'Referer': 'https://ssstwitter.com/',
            'Origin': 'https://ssstwitter.com',
          },
          timeout: 15000,
        }
      );

      const html = formResponse.data;

      // Parse the response for download links
      const $ = cheerio.load(html);

      // Look for download buttons
      $('a.download_link').each((i, el) => {
        const href = $(el).attr('href');
        if (href && href.includes('video.twimg.com')) {
          console.log('[Twitter] Found video URL from ssstwitter');
          media.push({ url: href, type: 'video' });
        }
      });

      // Also look for direct video URLs in the HTML
      const videoMatches = html.matchAll(/https:\/\/video\.twimg\.com[^"'\s<>]+\.mp4[^"'\s<>]*/gi);
      for (const match of videoMatches) {
        const videoUrl = match[0];
        if (!media.some(m => m.url === videoUrl)) {
          console.log('[Twitter] Found video URL in HTML');
          media.push({ url: videoUrl, type: 'video' });
        }
      }

      if (media.length > 0) {
        return {
          success: true,
          platform: 'twitter',
          media: removeDuplicates(media),
        };
      }
    } catch (e) {
      console.log('[Twitter] ssstwitter failed:', e.message);
    }

    // Method 2: Try fxtwitter API (uses different format)
    try {
      console.log('[Twitter] Trying fxtwitter API...');
      // fxtwitter API format: https://api.fxtwitter.com/status/TWEET_ID
      const fxUrl = `https://api.fxtwitter.com/status/${tweetId}`;

      const response = await axios.get(fxUrl, {
        headers: {
          'User-Agent': 'fxtwitter/1.0',
          'Accept': 'application/json',
        },
        timeout: 15000,
      });

      const data = response.data;
      console.log('[Twitter] fxtwitter response:', JSON.stringify(data).substring(0, 200));

      // Extract media from fxtwitter response
      if (data.tweet && data.tweet.media) {
        const tweetMedia = data.tweet.media;

        // Videos
        if (tweetMedia.videos && tweetMedia.videos.length > 0) {
          for (const video of tweetMedia.videos) {
            if (video.url) {
              console.log('[Twitter] Found video:', video.url.substring(0, 80));
              media.push({ url: video.url, type: 'video' });
            }
          }
        }

        // Photos
        if (tweetMedia.photos && tweetMedia.photos.length > 0) {
          for (const photo of tweetMedia.photos) {
            if (photo.url) {
              console.log('[Twitter] Found photo:', photo.url.substring(0, 80));
              media.push({ url: photo.url, type: 'image' });
            }
          }
        }

        // All media
        if (tweetMedia.all && tweetMedia.all.length > 0) {
          for (const m of tweetMedia.all) {
            if (m.url && !media.some(existing => existing.url === m.url)) {
              media.push({ url: m.url, type: m.type === 'video' ? 'video' : 'image' });
            }
          }
        }
      }

      if (media.length > 0) {
        return {
          success: true,
          platform: 'twitter',
          media: removeDuplicates(media),
          username: data.tweet?.author?.screen_name,
          caption: data.tweet?.text,
        };
      }
    } catch (e) {
      console.log('[Twitter] vxtwitter failed:', e.message);
    }

    // Method 2: Syndication API
    try {
      console.log('[Twitter] Trying syndication API...');
      const syndicationUrl = `https://cdn.syndication.twimg.com/tweet-result?id=${tweetId}&lang=en&token=${Date.now()}`;

      const response = await axios.get(syndicationUrl, {
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': '*/*',
          'Referer': 'https://platform.twitter.com/',
          'Origin': 'https://platform.twitter.com',
        },
        timeout: 10000,
      });

      const data = response.data;

      // Check for video
      if (data.video) {
        const variants = data.video.variants || [];
        const mp4Variants = variants.filter(v => v.src && v.src.includes('.mp4'));
        if (mp4Variants.length > 0) {
          mp4Variants.sort((a, b) => (b.bitrate || 0) - (a.bitrate || 0));
          media.push({ url: mp4Variants[0].src, type: 'video' });
        }

        if (data.video.poster) {
          media.push({ url: data.video.poster, type: 'image' });
        }
      }

      // Check for photos
      if (data.photos && data.photos.length > 0) {
        for (const photo of data.photos) {
          if (photo.url) {
            let photoUrl = photo.url;
            if (!photoUrl.includes('name=')) {
              photoUrl += '?name=orig';
            }
            media.push({ url: photoUrl, type: 'image' });
          }
        }
      }

      // Check mediaDetails
      if (data.mediaDetails && data.mediaDetails.length > 0) {
        for (const mediaItem of data.mediaDetails) {
          if (mediaItem.type === 'video' || mediaItem.type === 'animated_gif') {
            const videoInfo = mediaItem.video_info;
            if (videoInfo && videoInfo.variants) {
              const mp4Variants = videoInfo.variants.filter(v => v.content_type === 'video/mp4');
              mp4Variants.sort((a, b) => (b.bitrate || 0) - (a.bitrate || 0));
              if (mp4Variants.length > 0 && !media.some(m => m.url === mp4Variants[0].url)) {
                media.push({ url: mp4Variants[0].url, type: 'video' });
              }
            }
          } else if (mediaItem.type === 'photo') {
            const photoUrl = (mediaItem.media_url_https || mediaItem.media_url) + '?name=orig';
            if (!media.some(m => m.url === photoUrl)) {
              media.push({ url: photoUrl, type: 'image' });
            }
          }
        }
      }

      if (media.length > 0) {
        return {
          success: true,
          platform: 'twitter',
          media: removeDuplicates(media),
          username: data.user?.screen_name,
          caption: data.text,
        };
      }
    } catch (e) {
      console.log('[Twitter] Syndication failed:', e.message);
    }

    // Method 3: Use Puppeteer for Twitter if APIs fail
    try {
      console.log('[Twitter] Trying browser-based extraction...');
      const browserInstance = await initBrowser();
      const page = await browserInstance.newPage();

      await page.setViewport({ width: 1920, height: 1080 });
      await page.setUserAgent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');

      // Try nitter or direct URL
      const tweetUrl = url.replace('x.com', 'twitter.com');
      await page.goto(tweetUrl, { waitUntil: 'domcontentloaded', timeout: 20000 });
      await delay(3000);

      // Get video sources
      const videoSources = await page.evaluate(() => {
        const sources = [];
        const videos = document.querySelectorAll('video');
        videos.forEach(video => {
          if (video.src) sources.push(video.src);
          const sourceTags = video.querySelectorAll('source');
          sourceTags.forEach(source => {
            if (source.src) sources.push(source.src);
          });
        });
        // Also check for blob URLs that might have been converted
        return sources.filter(s => !s.startsWith('blob:'));
      });

      for (const src of videoSources) {
        if (src && !media.some(m => m.url === src)) {
          console.log('[Twitter] Found video in page:', src.substring(0, 80));
          media.push({ url: src, type: 'video' });
        }
      }

      // Get image sources
      const imageSources = await page.evaluate(() => {
        const sources = [];
        const images = document.querySelectorAll('img[src*="twimg.com/media"], img[src*="pbs.twimg.com"]');
        images.forEach(img => {
          if (img.src && img.src.includes('twimg.com')) {
            sources.push(img.src.replace('name=small', 'name=orig').replace('name=medium', 'name=orig').replace('name=large', 'name=orig'));
          }
        });
        return sources;
      });

      for (const src of imageSources) {
        if (src && !media.some(m => m.url === src)) {
          console.log('[Twitter] Found image in page:', src.substring(0, 80));
          media.push({ url: src, type: 'image' });
        }
      }

      await page.close();
    } catch (e) {
      console.log('[Twitter] Browser extraction failed:', e.message);
    }

    if (media.length === 0) {
      return { success: false, error: 'No media found. The tweet may require login or the media may have expired.' };
    }

    return { success: true, platform: 'twitter', media: removeDuplicates(media) };
  } catch (error) {
    return { success: false, error: error.message };
  }
}

// Helper: Unescape URL
function unescapeUrl(url) {
  return url
    .replace(/\\\//g, '/')
    .replace(/\\u0026/g, '&')
    .replace(/\\u003C/g, '<')
    .replace(/\\u003E/g, '>');
}

// Helper: Remove duplicate media
function removeDuplicates(media) {
  const seen = new Set();
  return media.filter(m => {
    const key = m.url.split('?')[0];
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

// Cleanup on exit
process.on('SIGINT', async () => {
  console.log('\n[Server] Shutting down...');
  if (browser) {
    await browser.close();
  }
  process.exit(0);
});

// Start server
app.listen(PORT, async () => {
  console.log(`
╔══════════════════════════════════════════════╗
║          Save It Backend Server              ║
║──────────────────────────────────────────────║
║  Running on: http://localhost:${PORT}            ║
║  Health: http://localhost:${PORT}/health         ║
║  Extract: POST http://localhost:${PORT}/api/extract  ║
╚══════════════════════════════════════════════╝
  `);

  // Pre-initialize browser for faster first request
  await initBrowser();
});
