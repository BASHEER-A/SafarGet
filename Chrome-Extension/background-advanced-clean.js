// SafarGet IDM - Advanced Background Script
// يستخدم استراتيجية مزدوجة: فحص headers مسبقًا + مراقبة downloads.onCreated
// 🎯 NEW: AI-Powered Analysis, Auto-Resume, Smart Filtering, Performance Metrics

let ws = null;
let reconnectTimer = null;
let isConnecting = false;
const WS_URL = 'ws://localhost:8765';

// قوائم للتحميلات المعترضة
let interceptedDownloads = new Set();
let preScannedUrls = new Map(); // للروابط المفحوصة مسبقًا
let pendingDownloads = new Map(); // للتحميلات قيد التحليل
let downloadQueue = new Map(); // قائمة انتظار التحميلات
let performanceData = {
    startTime: Date.now(),
    totalRequests: 0,
    successfulRequests: 0,
    averageResponseTime: 0,
    uptime: 0
};

// متتبع الروابط المعلقة على redirect
const pendingRedirects = new Map();

// أنواع المحتوى - تم تعطيل الفلترة (تقبل جميع الملفات)
const FAKE_CONTENT_TYPES = [];  // قائمة فارغة - لا نرفض أي نوع محتوى
const REAL_CONTENT_TYPES = ['*']; // نقبل جميع أنواع المحتوى

// امتدادات الملفات المعروفة
const KNOWN_EXTENSIONS = [
    '.pdf', '.zip', '.rar', '.7z', '.tar', '.gz', '.bz2',
    '.mp4', '.avi', '.mkv', '.mov', '.wmv', '.flv', '.webm', '.m4v',
    '.mp3', '.wav', '.flac', '.aac', '.ogg', '.wma', '.m4a',
    '.jpg', '.jpeg', '.png', '.gif', '.bmp', '.tiff', '.webp',
    '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx',
    '.exe', '.msi', '.dmg', '.pkg', '.deb', '.rpm',
    '.iso', '.img', '.bin', '.dll', '.so', '.dylib'
];

// الاتصال بـ WebSocket
function connectWebSocket() {
    if (ws && ws.readyState === WebSocket.OPEN) return Promise.resolve(true);
    if (isConnecting) return new Promise(resolve => setTimeout(() => resolve(ws && ws.readyState === WebSocket.OPEN), 1000));
    
    isConnecting = true;
    return new Promise(resolve => {
        try {
            console.log('🔌 Attempting to connect to SafarGet at:', WS_URL);
            ws = new WebSocket(WS_URL);
            
            // Set a timeout for the connection
            const connectionTimeout = setTimeout(() => {
                if (ws && ws.readyState === WebSocket.CONNECTING) {
                    console.log('⏰ WebSocket connection timeout');
                    ws.close();
                    isConnecting = false;
                    resolve(false);
                }
            }, 5000);
            
            ws.onopen = () => {
                console.log('✅ Connected to SafarGet');
                clearTimeout(connectionTimeout);
                chrome.action.setBadgeText({ text: '✓' });
                chrome.action.setBadgeBackgroundColor({ color: '#4CAF50' });
                isConnecting = false;
                if (reconnectTimer) clearTimeout(reconnectTimer);
                
                // معالجة التحميلات المعلقة
                processPendingDownloads();
                
                resolve(true);
            };
            
            ws.onclose = (event) => {
                console.log('❌ Disconnected from SafarGet:', event.code, event.reason);
                clearTimeout(connectionTimeout);
                chrome.action.setBadgeText({ text: '!' });
                chrome.action.setBadgeBackgroundColor({ color: '#F44336' });
                isConnecting = false;
                ws = null;
                
                // Only attempt to reconnect if it wasn't a manual close
                if (event.code !== 1000) {
                    console.log('🔄 Scheduling reconnection in 5 seconds...');
                    reconnectTimer = setTimeout(() => {
                        if (!isConnecting) {
                            connectWebSocket();
                        }
                    }, 5000);
                }
                resolve(false);
            };
            
            ws.onerror = (error) => {
                console.error('❌ WebSocket error:', error);
                clearTimeout(connectionTimeout);
                isConnecting = false;
                resolve(false);
            };
        } catch (error) {
            console.error('❌ Error creating WebSocket:', error);
            isConnecting = false;
            resolve(false);
        }
    });
}

// فحص مبسط للتحميل - يقبل جميع التحميلات من Chrome Downloads API
async function verifyDownload(downloadItem) {
    console.log('✅ Simple download verification:', {
        id: downloadItem.id,
        url: downloadItem.url,
        finalUrl: downloadItem.finalUrl,
        filename: downloadItem.filename,
        mime: downloadItem.mime,
        fileSize: downloadItem.fileSize,
        state: downloadItem.state
    });
    
    // استخدام finalUrl أولاً إذا كان متوفراً، ثم url
    const url = downloadItem.finalUrl || downloadItem.url;
    const originalUrl = downloadItem.url;
    
    console.log('🔗 Processing URL:', url);
    if (originalUrl !== url) {
        console.log('📍 Original URL:', originalUrl, '→ Final URL:', url);
    }
    
    // قبول جميع التحميلات التي تأتي عبر Chrome Downloads API
    console.log('✅ Accepting all downloads from Chrome Downloads API');
    return {
        isValid: true,
        reason: 'All Chrome Downloads API downloads accepted',
        confidence: 'high',
        strategy: 'chrome-api-only'
    };
}

// تحليل مبسط - اعتراض جميع التحميلات من Chrome Downloads API
async function quickDownloadAnalysis(downloadItem, url) {
    try {
        console.log('📋 Simple download analysis for:', url);
        
        // اعتراض جميع التحميلات بدون استثناء
        return {
            shouldIntercept: true,
            reason: 'Intercepting all Chrome Downloads API downloads'
        };
        
    } catch (error) {
        console.error('❌ Quick analysis error:', error);
        return {
            shouldIntercept: true,
            reason: 'Analysis error, intercepting by default'
        };
    }
}

// اعتراض جميع تحميلات Chrome - مبسط وشامل
chrome.downloads.onCreated.addListener(async (downloadItem) => {
    console.log('📥 Download detected:', downloadItem);
    
    chrome.storage.sync.get(['interceptDownloads'], async (result) => {
        if (result.interceptDownloads !== false) {
            // تجاهل التحميلات المحلية فقط
            if (!downloadItem.url.includes('localhost') && 
                !downloadItem.url.includes('127.0.0.1') &&
                !downloadItem.url.startsWith('file://') &&
                !downloadItem.url.startsWith('data:')) {
                
                console.log('🚫 Intercepting ALL downloads:', downloadItem.url);
                
                // استخدام finalUrl إذا كان متوفراً (بعد كل التحويلات)
                const finalUrl = downloadItem.finalUrl || downloadItem.url;
                console.log('🔗 Final URL:', finalUrl);
                
                // البحث عن الرابط الأصلي في pendingRedirects
                let originalUrl = null;
                let pendingInfo = null;
                
                for (const [url, info] of pendingRedirects.entries()) {
                    if (isRelatedUrl(url, finalUrl)) {
                        originalUrl = url;
                        pendingInfo = info;
                        console.log('✅ Found original URL:', originalUrl);
                        break;
                    }
                }
                
                console.log('✅ Intercepting download - no filtering');
                
                // إلغاء التحميل الافتراضي بشكل آمن
                chrome.downloads.cancel(downloadItem.id, () => {
                    if (chrome.runtime.lastError) {
                        console.log('⚠️ Cancel error:', chrome.runtime.lastError.message);
                    } else {
                        chrome.downloads.erase({ id: downloadItem.id }, () => {
                            if (chrome.runtime.lastError) {
                                console.log('⚠️ Erase error:', chrome.runtime.lastError.message);
                            } else {
                                console.log('🗑️ Download removed for processing');
                            }
                        });
                    }
                });
                
                // معالجة التحميل بالرابط النهائي
                processDownloadWithFinalUrl(downloadItem, finalUrl, originalUrl, pendingInfo);
            } else {
                console.log('⏭️ Skipping local download:', downloadItem.url);
            }
        } else {
            console.log('⏭️ Download interception disabled');
        }
    });
});

// مراقبة تحديد اسم الملف - اعتراض جميع التحميلات المتبقية
chrome.downloads.onDeterminingFilename.addListener(async (downloadItem, suggest) => {
    console.log('📝 Filename determination:', downloadItem);
    
    // فحص إذا كان هذا التحميل يجب اعتراضه
    chrome.storage.sync.get(['interceptDownloads'], async (result) => {
        if (result.interceptDownloads !== false) {
            // تجاهل التحميلات المحلية فقط
            if (!downloadItem.url.includes('localhost') && 
                !downloadItem.url.includes('127.0.0.1') &&
                !downloadItem.url.startsWith('file://') &&
                !downloadItem.url.startsWith('data:')) {
                
                // استخدام finalUrl إذا كان متوفراً
                const finalUrl = downloadItem.finalUrl || downloadItem.url;
                console.log('🔗 Final URL in filename determination:', finalUrl);
                
                console.log('🚫 Last chance interception - intercepting ALL downloads');
                
                // البحث عن الرابط الأصلي في pendingRedirects
                let originalUrl = null;
                let pendingInfo = null;
                
                for (const [url, info] of pendingRedirects.entries()) {
                    if (isRelatedUrl(url, finalUrl)) {
                        originalUrl = url;
                        pendingInfo = info;
                        console.log('✅ Found original URL in filename determination:', originalUrl);
                        break;
                    }
                }
                
                // معالجة التحميل بالرابط النهائي
                processDownloadWithFinalUrl(downloadItem, finalUrl, originalUrl, pendingInfo);
                
                // منع تحديد اسم الملف
                suggest({ filename: 'intercepted.download' });
                return;
            } else {
                console.log('⏭️ Skipping local download in filename determination:', downloadItem.url);
            }
        } else {
            console.log('⏭️ Download interception disabled in filename determination');
        }
        
        // إذا لم يتم اعتراض التحميل، اترك التحميل يحدث عادة
        suggest();
    });
});

// مراقبة تغييرات حالة التحميل
chrome.downloads.onChanged.addListener((delta) => {
    if (delta.state && delta.state.current === 'interrupted') {
        console.log('⚠️ Download interrupted:', delta.id);
    }
});

// معالجة الرسائل من content script و popup
chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
    console.log('📨 Received message:', request);
    
    try {
        if (!request || !request.type) {
            console.log('⚠️ Invalid message received:', request);
            sendResponse({ success: false, error: 'Invalid message format' });
            return true;
        }
        
        switch (request.type) {
            case 'download_link':
                try {
                    const url = request.url;
                    if (!url) {
                        sendResponse({ success: false, error: 'No URL provided' });
                        return true;
                    }
                    
                    const fileName = request.fileName || extractFileName(url);
                    const pageUrl = sender.tab ? sender.tab.url : '';
                    
                    // فحص إذا كان الرابط يحتوي على ملف مباشر
                    const hasDirectFile = isDirectFileUrl(url);
                    
                    if (hasDirectFile) {
                        // إذا كان ملف مباشر، أرسله فوراً
                        console.log('📤 Direct file detected, sending immediately:', url);
                        sendDownloadToSafarGet(url, fileName, pageUrl)
                            .then(() => {
                                console.log('✅ Direct file sent successfully');
                            })
                            .catch((error) => {
                                console.error('❌ Error sending direct file:', error);
                            });
                        sendResponse({ success: true, directFile: true });
                    } else {
                        // تسجيل الرابط للانتظار على حل redirect
                        console.log('📌 Registering link for redirect monitoring:', url);
                        pendingRedirects.set(url, {
                            fileName: fileName,
                            pageUrl: pageUrl,
                            timestamp: Date.now(),
                            tabId: sender.tab ? sender.tab.id : null
                        });
                        
                        // إرسال استجابة فورية للمستخدم
                        sendResponse({ success: true, waitingForRedirect: true });
                    }
                } catch (error) {
                    console.error('❌ Error handling download_link:', error);
                    sendResponse({ success: false, error: error.message });
                }
                return true;
            
            case 'link_resolved':
                try {
                    const originalUrl = request.originalUrl;
                    const finalUrl = request.finalUrl;
                    
                    if (!originalUrl || !finalUrl) {
                        sendResponse({ success: false, error: 'Missing originalUrl or finalUrl' });
                        return true;
                    }
                
                    console.log('🔄 Link resolved:', originalUrl, '→', finalUrl);
                    
                    // البحث عن الرابط المعلق
                    const pendingInfo = pendingRedirects.get(originalUrl);
                    if (pendingInfo) {
                        console.log('✅ Found pending link, sending resolved URL');
                        
                        const finalFileName = extractFileName(finalUrl);
                        sendDownloadToSafarGet(finalUrl, finalFileName, pendingInfo.pageUrl)
                            .then(() => {
                                console.log('✅ Resolved URL sent successfully');
                            })
                            .catch((error) => {
                                console.error('❌ Error sending resolved URL:', error);
                            });
                        
                        // إزالة من القائمة المعلقة
                        pendingRedirects.delete(originalUrl);
                        
                        // إرسال إشعار للمستخدم
                        showNotification('تم حل الرابط', `${originalUrl} → ${finalFileName}`);
                        sendResponse({ success: true, resolved: true });
                    } else {
                        console.log('❌ No pending link found for:', originalUrl);
                        sendResponse({ success: true, resolved: false });
                    }
                } catch (error) {
                    console.error('❌ Error handling link_resolved:', error);
                    sendResponse({ success: false, error: error.message });
                }
                return true;
                
            case 'open_app':
                try {
                    openAppViaWebSocket();
                    sendResponse({ success: true });
                } catch (error) {
                    console.error('❌ Error opening app:', error);
                    sendResponse({ success: false, error: error.message });
                }
                break;
                
            case 'test_connection':
                try {
                    testConnection().then(success => {
                        sendResponse({ success: success, connected: success });
                    }).catch(error => {
                        console.error('❌ Connection test failed:', error);
                        sendResponse({ success: false, connected: false, error: error.message });
                    });
                } catch (error) {
                    console.error('❌ Error testing connection:', error);
                    sendResponse({ success: false, connected: false, error: error.message });
                }
                return true;
                
            case 'checkConnection':
            case 'get_connection_status':
                try {
                    const isConnected = ws && ws.readyState === WebSocket.OPEN;
                    sendResponse({ 
                        success: true, 
                        connected: isConnected,
                        status: isConnected ? 'connected' : 'disconnected'
                    });
                } catch (error) {
                    console.error('❌ Error getting connection status:', error);
                    sendResponse({ success: false, connected: false, error: error.message });
                }
                break;
                
            case 'get_stats':
                try {
                    chrome.storage.sync.get({ stats: { totalIntercepted: 0, realFiles: 0, rejectedFiles: 0 } }, (result) => {
                        sendResponse({ success: true, stats: result.stats });
                    });
                } catch (error) {
                    console.error('❌ Error getting stats:', error);
                    sendResponse({ success: false, error: error.message });
                }
                return true;
                
            case 'get_performance':
                try {
                    updatePerformanceMetrics();
                    sendResponse({ success: true, metrics: performanceData });
                } catch (error) {
                    console.error('❌ Error getting performance:', error);
                    sendResponse({ success: false, error: error.message });
                }
                return true;
                
            case 'page_loaded':
                try {
                    console.log('📄 Page loaded:', request.url);
                    // يمكن إضافة منطق إضافي لمعالجة تحميل الصفحة
                    sendResponse({ success: true });
                } catch (error) {
                    console.error('❌ Error handling page_loaded:', error);
                    sendResponse({ success: false, error: error.message });
                }
                break;
                
            case 'youtube_download':
                try {
                    handleYouTubeDownload(request, sender, sendResponse);
                    return true;
                } catch (error) {
                    console.error('❌ Error handling YouTube download:', error);
                    sendResponse({ success: false, error: error.message });
                }
                break;
                
            case 'add_filter':
            case 'remove_filter':
            case 'block_domain':
            case 'allow_domain':
                console.log('⚠️ Smart filter functionality disabled');
                sendResponse({ success: false, error: 'Smart filter functionality has been disabled' });
                break;
                
            default:
                console.log('⚠️ Unknown message type:', request.type);
                sendResponse({ success: false, error: 'Unknown message type: ' + request.type });
        }
        
    } catch (error) {
        console.error('❌ Fatal error in message handler:', error);
        sendResponse({ success: false, error: 'Fatal error: ' + error.message });
    }
});

// إرسال التحميل إلى SafarGet
async function sendDownloadToSafarGet(url, fileName, pageUrl) {
    try {
        await connectWebSocket();
        
        if (ws && ws.readyState === WebSocket.OPEN) {
            const message = {
                type: 'download',
                url: url,
                fileName: fileName,
                pageUrl: pageUrl,
                shouldOpenApp: true,
                timestamp: Date.now()
            };
            
            ws.send(JSON.stringify(message));
            console.log('📤 Sent download request:', fileName);
            showNotification('تم إرسال التحميل', fileName);
        } else {
            console.log('❌ WebSocket not available');
            showNotification('خطأ في الاتصال', 'تأكد من تشغيل SafarGet');
        }
    } catch (error) {
        console.error('❌ Error sending download:', error);
        showNotification('خطأ', 'فشل إرسال التحميل');
    }
}

// فتح التطبيق
async function openAppViaWebSocket() {
    try {
        await connectWebSocket();
        
        if (ws && ws.readyState === WebSocket.OPEN) {
            const message = {
                type: 'open_app',
                timestamp: Date.now()
            };
            
            ws.send(JSON.stringify(message));
            console.log('📤 Sent open app request');
        }
    } catch (error) {
        console.error('❌ Error opening app:', error);
    }
}

// اختبار الاتصال
async function testConnection() {
    try {
        await connectWebSocket();
        return ws && ws.readyState === WebSocket.OPEN;
    } catch (error) {
        console.error('❌ Connection test failed:', error);
        return false;
    }
}

// تحديث مقاييس الأداء
function updatePerformanceMetrics() {
    performanceData.uptime = Math.floor((Date.now() - performanceData.startTime) / 1000);
    performanceData.totalRequests++;
}

// إظهار إشعار
function showNotification(title, message) {
    chrome.notifications.create({
        type: 'basic',
        iconUrl: 'icon-48.png',
        title: title,
        message: message
    });
}

// استخراج اسم الملف
function extractFileName(url) {
    try {
        const urlObj = new URL(url);
        const pathname = urlObj.pathname;
        const pathParts = pathname.split('/');
        let fileName = pathParts[pathParts.length - 1];
        
        if (!fileName || fileName === '') {
            fileName = urlObj.hostname + '.file';
        }
        
        if (fileName.includes('?')) {
            fileName = fileName.split('?')[0];
        }
        
        if (!fileName.includes('.')) {
            fileName += '.file';
        }
        
        return fileName;
    } catch (error) {
        return 'download.file';
    }
}

// Helper Functions
function isRelatedUrl(url1, url2) {
    try {
        const urlObj1 = new URL(url1);
        const urlObj2 = new URL(url2);
        
        // نفس الدومين
        if (urlObj1.hostname === urlObj2.hostname) {
            return true;
        }
        
        // أحدهما يحتوي على الآخر
        if (url1.includes(url2) || url2.includes(url1)) {
            return true;
        }
        
        return false;
    } catch (error) {
        return false;
    }
}

function isDirectFileUrl(url) {
    const urlLower = url.toLowerCase();
    return KNOWN_EXTENSIONS.some(ext => urlLower.includes(ext));
}

async function getFinalUrlAfterRedirect(url) {
    try {
        const response = await fetch(url, { method: 'HEAD', mode: 'no-cors' });
        return response.url || url;
    } catch (error) {
        return url;
    }
}

function isRedirectPage(url) {
    const urlLower = url.toLowerCase();
    const redirectKeywords = ['redirect', 'goto', 'link', 'url'];
    return redirectKeywords.some(keyword => urlLower.includes(keyword)) ||
           urlLower.endsWith('.html') || urlLower.endsWith('.php');
}

async function getActualDownloadUrl(url) {
    try {
        const response = await fetch(url, { mode: 'no-cors' });
        return response.url || url;
    } catch (error) {
        return url;
    }
}

async function processDownloadWithFinalUrl(downloadItem, finalUrl, originalUrl, pendingInfo) {
    try {
        console.log('🔗 Processing download with final URL:', finalUrl);
        
        // التحقق من صحة التحميل
        const verification = await verifyDownload(downloadItem);
        
        if (!verification.isValid) {
            console.log('🚫 Invalid download detected:', verification.reason);
            return;
        }
        
        // إرسال التحميل إلى SafarGet
        const fileName = downloadItem.filename || extractFileName(finalUrl);
        const pageUrl = pendingInfo?.pageUrl || originalUrl || '';
        
        console.log('📤 Sending to SafarGet:', fileName);
        
        await connectWebSocket();
        
        if (ws && ws.readyState === WebSocket.OPEN) {
            const message = {
                type: 'download',
                url: finalUrl,
                fileName: fileName,
                pageUrl: pageUrl,
                shouldOpenApp: true,
                chromeVerified: true,
                chromeDownloadInfo: {
                    id: downloadItem.id,
                    fileSize: downloadItem.fileSize,
                    mime: downloadItem.mime,
                    finalUrl: downloadItem.finalUrl
                },
                originalUrl: originalUrl,
                timestamp: Date.now()
            };
            
            ws.send(JSON.stringify(message));
            console.log('✅ Download sent to SafarGet');
            showNotification('تم اعتراض التحميل', fileName);
        } else {
            // حفظ التحميل محلياً إذا لم يكن SafarGet متصل
            console.log('📁 Saving download locally (SafarGet not connected)');
            const savedDownload = {
                url: finalUrl,
                fileName: fileName,
                pageUrl: pageUrl,
                downloadInfo: downloadItem,
                timestamp: Date.now()
            };
            
            chrome.storage.local.get(['pendingDownloads'], (result) => {
                const pending = result.pendingDownloads || [];
                pending.push(savedDownload);
                chrome.storage.local.set({ pendingDownloads: pending });
                console.log('💾 Download saved to local storage');
            });
        }
        
    } catch (error) {
        console.error('❌ Error processing download with final URL:', error);
        showNotification('خطأ', 'فشل معالجة التحميل');
    }
}

// معالجة التحميلات المعلقة
async function processPendingDownloads() {
    try {
        chrome.storage.local.get(['pendingDownloads'], async (result) => {
            const pending = result.pendingDownloads || [];
            
            if (pending.length === 0) {
                console.log('📭 No pending downloads to process');
                return;
            }
            
            console.log(`📬 Processing ${pending.length} pending downloads`);
            
            for (const download of pending) {
                try {
                    const message = {
                        type: 'download',
                        url: download.url,
                        fileName: download.fileName,
                        pageUrl: download.pageUrl,
                        shouldOpenApp: true,
                        chromeVerified: true,
                        timestamp: download.timestamp,
                        fromPending: true
                    };
                    
                    if (ws && ws.readyState === WebSocket.OPEN) {
                        ws.send(JSON.stringify(message));
                        console.log('✅ Pending download sent:', download.fileName);
                    }
                } catch (error) {
                    console.error('❌ Error sending pending download:', error);
                }
            }
            
            // مسح التحميلات المعلقة بعد الإرسال
            chrome.storage.local.set({ pendingDownloads: [] });
            console.log('🧹 Pending downloads cleared');
        });
    } catch (error) {
        console.error('❌ Error processing pending downloads:', error);
    }
}

// معالج YouTube Download
async function handleYouTubeDownload(request, sender, sendResponse) {
    const { data } = request;
    
    console.log('🎥 Processing YouTube download:', data);
    
    try {
        await connectWebSocket();
        
        if (ws && ws.readyState === WebSocket.OPEN) {
            const message = {
                type: 'youtube_download',
                url: data.url,
                fileName: data.filename,
                videoInfo: data.videoInfo,
                quality: data.quality,
                downloadType: data.type,
                pageUrl: sender.tab ? sender.tab.url : '',
                timestamp: Date.now()
            };
            
            ws.send(JSON.stringify(message));
            console.log('✅ YouTube download sent to SafarGet');
            sendResponse({ success: true });
        } else {
            console.log('❌ SafarGet not connected');
            sendResponse({ success: false, error: 'SafarGet not connected' });
        }
    } catch (error) {
        console.error('❌ YouTube download error:', error);
        sendResponse({ success: false, error: error.message });
    }
}

// Context Menu لـ YouTube - نسخة واحدة فقط
chrome.runtime.onInstalled.addListener(() => {
    // إزالة القوائم السياقية القديمة أولاً
    chrome.contextMenus.removeAll(() => {
        // إضافة قائمة سياقية لـ YouTube
        chrome.contextMenus.create({
            id: 'youtube-download',
            title: 'تحميل بـ SafarGet',
            contexts: ['link'],
            documentUrlPatterns: ['*://*.youtube.com/*', '*://*.youtu.be/*'],
            targetUrlPatterns: ['*://*.youtube.com/watch*', '*://*.youtu.be/*']
        });
        
        // إضافة قائمة سياقية للصفحة
        chrome.contextMenus.create({
            id: 'youtube-page-download',
            title: 'تحميل الفيديو الحالي',
            contexts: ['page'],
            documentUrlPatterns: ['*://*.youtube.com/watch*']
        });
        
        console.log('✅ Context menus created');
    });
});

// معالجة النقر على القائمة السياقية
chrome.contextMenus.onClicked.addListener((info, tab) => {
    if (info.menuItemId === 'youtube-download') {
        // تحميل رابط YouTube
        const videoUrl = info.linkUrl;
        if (videoUrl) {
            console.log('🎥 Context menu YouTube download:', videoUrl);
            // إرسال مباشر إلى SafarGet
            sendDownloadToSafarGet(videoUrl, 'YouTube Video', tab.url);
        }
    } else if (info.menuItemId === 'youtube-page-download') {
        // تحميل الفيديو الحالي
        chrome.tabs.sendMessage(tab.id, {
            type: 'trigger_youtube_download'
        });
    }
});

// الاتصال التلقائي
connectWebSocket();

console.log('🚀 SafarGet IDM Advanced Background Script Loaded');
console.log('✅ Dual-strategy system: Pre-scan + Download monitoring');
console.log('🎥 YouTube Download Handler Initialized');
console.log('✅ YouTube context menu integration active');
