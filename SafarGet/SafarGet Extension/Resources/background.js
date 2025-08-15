// 🚀 SafarGet Extension - Background Script
// اعتراض شامل للتحميلات في Safari

console.log('🎯 Background script loaded');

// تخزين معلومات التحميلات
const downloads = new Map();

// الاستماع للرسائل من Content Script
browser.runtime.onMessage.addListener((request, sender, sendResponse) => {
    console.log('📨 Message received:', request);
    
    if (request.action === 'download_intercepted') {
        handleDownload(request.data, sender.tab);
        sendResponse({ success: true });
    }
    
    if (request.action === 'url_changed_to_download') {
        handleDirectDownload(request.url, sender.tab);
        sendResponse({ success: true });
    }
    
    // 🎯 NEW: معالج اعتراض نافذة Download Permission
    if (request.action === 'download_permission_detected') {
        console.log('🎯 Download permission dialog intercepted:', request.data);
        handlePermissionDialog(request.data, sender.tab);
        sendResponse({ success: true });
    }
    
    // 🧪 معالج الرسائل التجريبية
    if (request.action === 'test_connection') {
        console.log('🧪 Test connection received:', request.data);
        sendResponse({ success: true, message: 'Connection working!' });
    }
});

// معالج التحميلات
async function handleDownload(data, tab) {
    console.log('🔄 Processing download:', data);
    
    // تحليل URL للحصول على المعلومات
    const downloadInfo = await analyzeDownloadUrl(data.url);
    
    // دمج المعلومات
    const finalInfo = {
        ...data,
        ...downloadInfo,
        tabId: tab.id,
        tabUrl: tab.url,
        timestamp: Date.now()
    };
    
    // حفظ في التخزين
    downloads.set(data.url, finalInfo);
    
    // إرسال للتطبيق الأصلي
    sendToNativeApp(finalInfo);
}

// تحليل URL
async function analyzeDownloadUrl(url) {
    try {
        // محاولة HEAD request
        const response = await fetch(url, {
            method: 'HEAD',
            redirect: 'follow'
        }).catch(() => null);
        
        if (response) {
            const finalUrl = response.url;
            const headers = {};
            
            response.headers.forEach((value, key) => {
                headers[key] = value;
            });
            
            return {
                finalUrl: finalUrl,
                originalUrl: url,
                headers: headers,
                contentType: headers['content-type'],
                contentLength: headers['content-length'],
                filename: extractFilenameFromHeaders(headers) || extractFilenameFromUrl(finalUrl)
            };
        }
    } catch (e) {
        console.error('Error analyzing URL:', e);
    }
    
    // Fallback
    return {
        finalUrl: url,
        originalUrl: url,
        filename: extractFilenameFromUrl(url)
    };
}

// استخراج اسم الملف
function extractFilenameFromHeaders(headers) {
    const disposition = headers['content-disposition'];
    if (!disposition) return null;
    
    const match = disposition.match(/filename[^;=\n]*=([^;\n]*)/);
    if (match) {
        let filename = match[1];
        filename = filename.replace(/['"]/g, '');
        return decodeURIComponent(filename);
    }
    
    return null;
}

function extractFilenameFromUrl(url) {
    try {
        const urlObj = new URL(url);
        const path = urlObj.pathname;
        const filename = path.substring(path.lastIndexOf('/') + 1);
        return decodeURIComponent(filename) || 'download';
    } catch (e) {
        return 'download';
    }
}

// إرسال للتطبيق الأصلي
function sendToNativeApp(info) {
    console.log('📤 Sending to native app:', info);
    
    // الطريقة 1: Native Messaging (يحتاج تطبيق مساعد)
    if (browser.runtime.connectNative) {
        try {
            const port = browser.runtime.connectNative('com.safarget.downloader');
            port.postMessage(info);
        } catch (e) {
            console.error('Native messaging failed:', e);
        }
    }
    
    // الطريقة 2: فتح في التطبيق عبر URL Scheme
    const appUrl = `safarget://download?url=${encodeURIComponent(info.finalUrl || info.url)}&filename=${encodeURIComponent(info.filename || 'download')}`;
    
    browser.tabs.create({
        url: appUrl,
        active: false
    }).then(tab => {
        // إغلاق التبويب بعد ثانية
        setTimeout(() => {
            browser.tabs.remove(tab.id);
        }, 1000);
    });
    
    // الطريقة 3: حفظ في Storage للتطبيق
    browser.storage.local.set({
        lastDownload: info,
        downloads: Array.from(downloads.values())
    });
}

// معالج التحميلات المباشرة
function handleDirectDownload(url, tab) {
    handleDownload({
        action: 'direct_navigation',
        url: url
    }, tab);
}

// 🎯 NEW: معالج نافذة Download Permission
async function handlePermissionDialog(data, tab) {
    console.log('🎯 Handling download permission dialog:', data);
    
    try {
        // الحصول على URL النهائي
        const finalURL = await getFinalURL(data.url);
        
        // تحليل معلومات التحميل
        const downloadInfo = {
            url: finalURL,
            originalUrl: data.url,
            filename: data.filename || extractFilenameFromUrl(finalURL),
            source: 'permission_dialog',
            tabId: tab.id,
            tabUrl: tab.url,
            timestamp: Date.now(),
            permissionData: data
        };
        
        // حفظ في التخزين
        downloads.set(data.url, downloadInfo);
        
        // إرسال للتطبيق الأصلي
        sendToNativeApp(downloadInfo);
        
        console.log('✅ Download permission dialog handled successfully');
        
    } catch (error) {
        console.error('❌ Error handling permission dialog:', error);
        
        // Fallback: معالجة بسيطة
        const fallbackInfo = {
            url: data.url,
            filename: data.filename || 'download',
            source: 'permission_dialog_fallback',
            tabId: tab.id,
            tabUrl: tab.url,
            timestamp: Date.now()
        };
        
        sendToNativeApp(fallbackInfo);
    }
}

// دالة مساعدة للحصول على URL النهائي
async function getFinalURL(url) {
    try {
        const response = await fetch(url, {
            method: 'HEAD',
            redirect: 'follow'
        });
        return response.url;
    } catch {
        return url;
    }
}
