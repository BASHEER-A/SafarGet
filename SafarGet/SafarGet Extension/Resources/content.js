// Safari Extension Content Script - Enhanced Download Detection with Permission Dialog Interception
// Features:
// - YouTube video downloads with quality selection
// - Content-Disposition header monitoring for sites like projectinfinity-x.com
// - XMLHttpRequest and fetch request interception
// - Form submission monitoring
// - Navigation event tracking
// - Support for dynamic download URLs
// - 🎯 NEW: Download Permission Dialog Interception (Golden Solution)

// =================================================
// 🎯 نظام اعتراض نافذة Download Permission - محسن
// =================================================
(function() {
    'use strict';
    
    console.log('🎯 Download Permission Interceptor Active');
    
    // متتبع التحميلات المعلقة
    const PendingDownloads = {
        downloads: new Map(),
        
        add(url, info) {
            console.log('📌 Pending download added:', url);
            this.downloads.set(url, {
                ...info,
                timestamp: Date.now(),
                intercepted: false
            });
        },
        
        intercept(url) {
            const download = this.downloads.get(url);
            if (download && !download.intercepted) {
                download.intercepted = true;
                this.sendToExtension(download);
                return true;
            }
            return false;
        },
        
        sendToExtension(info) {
            console.log('🎯 Intercepting download:', info);
            window.postMessage({
                type: 'DOWNLOAD_PERMISSION_DETECTED',
                data: info
            }, '*');
        }
    };
    
    // اعتراض beforeunload
    window.addEventListener('beforeunload', function(event) {
        console.log('🔍 beforeunload detected - possible download');
        const activeElement = document.activeElement;
        if (activeElement && activeElement.href) {
            PendingDownloads.add(activeElement.href, {
                url: activeElement.href,
                source: 'beforeunload',
                element: activeElement.outerHTML
            });
        }
    }, true);
    
    // مراقب الـ Permission API
    if ('permissions' in navigator) {
        const originalQuery = navigator.permissions.query;
        navigator.permissions.query = async function(descriptor) {
            console.log('🔍 Permission query:', descriptor);
            
            if (descriptor.name === 'downloads' || 
                descriptor.name === 'storage' ||
                descriptor.name === 'persistent-storage') {
                
                PendingDownloads.add('permission-query', {
                    type: 'permission',
                    descriptor: descriptor
                });
            }
            
            return originalQuery.call(this, descriptor);
        };
    }
    
    // مراقب الـ MutationObserver للنوافذ المنبثقة
    const observer = new MutationObserver(function(mutations) {
        mutations.forEach(function(mutation) {
            mutation.addedNodes.forEach(function(node) {
                if (node.nodeType === 1) {
                    const isDialog = 
                        node.tagName === 'DIALOG' ||
                        node.role === 'dialog' ||
                        node.className?.includes('modal') ||
                        node.className?.includes('popup') ||
                        node.className?.includes('overlay');
                    
                    if (isDialog) {
                        console.log('🔍 Dialog detected - might be download permission');
                        
                        const text = node.textContent?.toLowerCase() || '';
                        if (text.includes('download') && text.includes('allow')) {
                            console.log('✅ Download permission dialog detected!');
                            interceptDownloadDialog(node);
                        }
                    }
                }
            });
        });
    });
    
    observer.observe(document.documentElement, {
        childList: true,
        subtree: true
    });
    
    function interceptDownloadDialog(dialogElement) {
        console.log('🎯 Intercepting download dialog');
        
        const urlMatch = dialogElement.textContent?.match(/https?:\/\/[^\s"']+/);
        const url = urlMatch ? urlMatch[0] : null;
        
        if (url) {
            PendingDownloads.intercept(url);
        }
        
        const buttons = dialogElement.querySelectorAll('button');
        buttons.forEach(button => {
            const text = button.textContent?.toLowerCase() || '';
            
            if (text.includes('allow') || text.includes('download')) {
                const originalClick = button.onclick;
                button.onclick = function(e) {
                    console.log('✅ Allow button clicked - intercepting download');
                    checkForPendingDownloads();
                    if (originalClick) return originalClick.call(this, e);
                };
            }
        });
    }
    
    function checkForPendingDownloads() {
        PendingDownloads.downloads.forEach((info, url) => {
            if (!info.intercepted) {
                console.log('🔄 Checking pending download:', url);
            }
        });
    }
    
    console.log('✅ Download Permission Interceptor Ready');
})();

(function() {
    'use strict';
    
    // =================================================
    // 🎯 نظام التشخيص الشامل
    // =================================================
    console.log('🚀 SafarGet Extension Starting...');
    console.log('📊 Browser API Check:');
    console.log('  - browser.runtime:', typeof browser !== 'undefined' && browser.runtime ? '✅ Available' : '❌ Not Available');
    console.log('  - safari.extension:', typeof safari !== 'undefined' && safari.extension ? '✅ Available' : '❌ Not Available');
    console.log('  - window.location:', window.location.href);
    console.log('  - document.readyState:', document.readyState);
    
    // تتبع الروابط التي تم النقر عليها بزر الماوس الأيمن
    let contextMenuTarget = null;
    
    // متغيرات YouTube
    let downloadButton = null;
    let qualityMenu = null;
    
    // الاستماع للنقر بزر الماوس الأيمن
    document.addEventListener('contextmenu', function(e) {
        contextMenuTarget = e.target;
        
        // التحقق من أن العنصر هو رابط أو يحتوي على رابط
        let link = e.target.closest('a');
        if (link && link.href) {
            safari.extension.dispatchMessage('contextMenuUpdate', {
                url: link.href,
                fileName: extractFileName(link.href) || link.textContent.trim()
            });
        }
    });
    
    // مراقبة النقرات على جميع الروابط - محسن
    document.addEventListener('click', function(e) {
        console.log('🔍 Click detected on:', e.target.tagName, e.target.href || e.target.textContent?.substring(0, 50));
        
        const link = e.target.closest('a');
        if (link && link.href) {
            console.log('🔗 Link clicked:', link.href);
            
            // التحقق من أن الرابط قابل للتحميل
            if (isDownloadableLink(link.href)) {
                console.log('📥 Downloadable link detected:', link.href);
                
                // التحقق من وجود download attribute أو إذا كان ملف
                if (link.hasAttribute('download') || isDirectFileLink(link.href)) {
                    console.log('✅ Intercepting download link:', link.href);
                    e.preventDefault();
                    e.stopPropagation();
                    sendDownloadRequest(link.href, extractFileName(link.href));
                    return false;
                }
            }
            
            // التحقق من الروابط مع Alt/Option key
            if (e.altKey) {
                console.log('⌥ Alt+Click detected, intercepting:', link.href);
                e.preventDefault();
                e.stopPropagation();
                sendDownloadRequest(link.href, extractFileName(link.href));
                return false;
            }
            
            // مراقبة الروابط التي قد تؤدي إلى تحميلات مع Content-Disposition
            // خاصة للمواقع مثل projectinfinity-x.com
            if (shouldMonitorForContentDisposition(link.href)) {
                console.log('SafarGet: Monitoring link for Content-Disposition:', link.href);
                // لا نمنع السلوك الافتراضي، فقط نراقب
            }
        }
        
        // مراقبة النقرات على أزرار التحميل الديناميكية
        const target = e.target;
        if (target && (target.textContent?.toLowerCase().includes('download') || 
                      target.textContent?.toLowerCase().includes('تحميل') ||
                      target.className?.toLowerCase().includes('download') ||
                      target.id?.toLowerCase().includes('download'))) {
            console.log('SafarGet: Detected download button click:', target.textContent);
            
            // مراقبة التغييرات في location بعد النقر
            setTimeout(() => {
                if (window.location.href !== currentLocation) {
                    console.log('SafarGet: Location changed after download button click:', window.location.href);
                    currentLocation = window.location.href;
                }
            }, 1000);
        }
    }, true);
    
    // التحقق من الروابط المباشرة للملفات - محسن
    function isDirectFileLink(url) {
        try {
            const fileExtensions = [
                '.zip', '.rar', '.7z', '.tar', '.gz',
                '.exe', '.dmg', '.pkg', '.deb', '.rpm',
                '.pdf', '.doc', '.docx', '.xls', '.xlsx',
                '.mp4', '.avi', '.mkv', '.mov', '.wmv',
                '.mp3', '.wav', '.flac', '.aac', '.m4a',
                '.jpg', '.jpeg', '.png', '.gif', '.bmp',
                '.iso', '.img', '.bin', '.ipsw',
            ];
            
            const urlLower = url.toLowerCase();
            const urlObj = new URL(url);
            const urlPath = urlObj.pathname.toLowerCase();
            
            const isDirect = fileExtensions.some(ext => urlPath.endsWith(ext));
            console.log('🔍 isDirectFileLink check:', url, 'result:', isDirect);
            
            return isDirect;
        } catch (error) {
            console.error('❌ Error in isDirectFileLink:', error);
            return false;
        }
    }
    
    // مراقبة طلبات التحميل من الصفحة
    const originalOpen = XMLHttpRequest.prototype.open;
    XMLHttpRequest.prototype.open = function(method, url) {
        console.log('SafarGet: XMLHttpRequest to:', url, 'method:', method);
        
        // مراقبة خاصة للطلبات من about:blank
        if (window.location.href === 'about:blank') {
            console.log('SafarGet: XMLHttpRequest from about:blank to:', url);
        }
        
        this.addEventListener('load', function() {
            if (this.status === 200) {
                // التحقق من Content-Disposition header للتحميلات
                const contentDisposition = this.getResponseHeader('Content-Disposition');
                if (contentDisposition && contentDisposition.toLowerCase().includes('attachment')) {
                    const fileName = extractFileNameFromHeaders(this) || extractFileName(url);
                    if (fileName) {
                        console.log('SafarGet: Detected download via XMLHttpRequest Content-Disposition:', fileName);
                        sendDownloadRequest(url, fileName);
                    }
                } else {
                    // التحقق من Content-Type للتحميلات
                    const contentType = this.getResponseHeader('Content-Type');
                    if (contentType && isDownloadableContentType(contentType)) {
                        const fileName = extractFileNameFromHeaders(this) || extractFileName(url);
                        if (fileName) {
                            console.log('SafarGet: Detected download via XMLHttpRequest Content-Type:', contentType, fileName);
                            sendDownloadRequest(url, fileName);
                        }
                    }
                }
            }
        });
        
        this.addEventListener('error', function() {
            console.log('SafarGet: XMLHttpRequest error for:', url);
        });
        
        return originalOpen.apply(this, arguments);
    };
    
    // التحقق من الروابط القابلة للتحميل - محسن
    function isDownloadableLink(url) {
        try {
            const downloadableExtensions = [
                '.zip', '.rar', '.7z', '.tar', '.gz',
                '.exe', '.dmg', '.pkg', '.deb', '.rpm',
                '.pdf', '.doc', '.docx', '.xls', '.xlsx',
                '.mp4', '.avi', '.mkv', '.mov', '.wmv',
                '.mp3', '.wav', '.flac', '.aac', '.m4a',
                '.jpg', '.jpeg', '.png', '.gif', '.bmp',
                '.iso', '.img', '.bin', '.ipsw',
            ];
            
            const urlLower = url.toLowerCase();
            const isDownloadable = downloadableExtensions.some(ext => urlLower.includes(ext));
            console.log('🔍 isDownloadableLink check:', url, 'result:', isDownloadable);
            
            return isDownloadable;
        } catch (error) {
            console.error('❌ Error in isDownloadableLink:', error);
            return false;
        }
    }
    
    // التحقق من المواقع التي تحتاج مراقبة Content-Disposition
    function shouldMonitorForContentDisposition(url) {
        const monitoredDomains = [
            'projectinfinity-x.com',
            'mirror.tejas101k.workers.dev',
            'github.com',
            'gitlab.com',
            'sourceforge.net',
            'mediafire.com',
            'mega.nz',
            'dropbox.com',
            'drive.google.com'
        ];
        
        try {
            const urlObj = new URL(url);
            return monitoredDomains.some(domain => urlObj.hostname.includes(domain));
        } catch (e) {
            return false;
        }
    }
    
    // استخراج اسم الملف من URL
    function extractFileName(url) {
        try {
            const urlObj = new URL(url);
            const pathname = urlObj.pathname;
            const fileName = pathname.substring(pathname.lastIndexOf('/') + 1);
            
            // فك ترميز URL
            return decodeURIComponent(fileName) || null;
        } catch (e) {
            return null;
        }
    }
    
    // استخراج اسم الملف من Headers
    function extractFileNameFromHeaders(response) {
        let contentDisposition;
        
        // التعامل مع XMLHttpRequest و Response objects
        if (response.getResponseHeader) {
            // XMLHttpRequest
            contentDisposition = response.getResponseHeader('Content-Disposition');
        } else if (response.headers && response.headers.get) {
            // Response object من fetch
            contentDisposition = response.headers.get('Content-Disposition');
        }
        
        if (contentDisposition) {
            // البحث عن filename في Content-Disposition header
            const fileNameMatch = contentDisposition.match(/filename[^;=\n]*=((['"]).*?\2|[^;\n]*)/);
            if (fileNameMatch && fileNameMatch[1]) {
                let fileName = fileNameMatch[1].replace(/['"]/g, '');
                
                // فك ترميز URL encoding إذا كان موجود
                try {
                    fileName = decodeURIComponent(fileName);
                } catch (e) {
                    // تجاهل الأخطاء في فك الترميز
                }
                
                return fileName;
            }
            
            // البحث عن filename* (RFC 5987) إذا كان filename العادي غير موجود
            const fileNameStarMatch = contentDisposition.match(/filename\*[^;=\n]*=([^;\n]*)/);
            if (fileNameStarMatch && fileNameStarMatch[1]) {
                let fileName = fileNameStarMatch[1];
                
                // فك ترميز RFC 5987 format
                try {
                    if (fileName.includes("''")) {
                        const parts = fileName.split("''");
                        if (parts.length === 2) {
                            fileName = decodeURIComponent(parts[1]);
                        }
                    }
                } catch (e) {
                    // تجاهل الأخطاء في فك الترميز
                }
                
                return fileName;
            }
        }
        return null;
    }
    
    // التحقق من المحتوى القابل للتحميل
    function isDownloadableContent(xhr) {
        const contentType = xhr.getResponseHeader('Content-Type');
        return isDownloadableContentType(contentType);
    }
    
    // التحقق من Content-Type للتحميلات
    function isDownloadableContentType(contentType) {
        if (!contentType) return false;
        
        const downloadableTypes = [
            'application/octet-stream',
            'application/zip',
            'application/x-zip-compressed',
            'application/pdf',
            'application/x-rar-compressed',
            'application/x-7z-compressed',
            'application/x-tar',
            'application/x-gzip',
            'application/x-bzip2',
            'video/',
            'audio/',
            'image/',
            'application/vnd.android.package-archive',
            'application/x-apple-diskimage',
            'application/x-debian-package',
            'application/x-redhat-package-manager',
            'application/x-msdownload',
            'application/x-executable',
            'application/x-shockwave-flash',
            'application/x-flash-video'
        ];
        
        const mimeLower = contentType.toLowerCase();
        
        // تنظيف نوع المحتوى من الأخطاء الشائعة
        const cleanContentType = mimeLower
            .replace(/text\/htm\//, 'text/html/') // إصلاح text/htm/ إلى text/html/
            .replace(/charset=utf-8\s*$/, '') // إزالة charset=utf-8 في النهاية
            .replace(/\s+/g, ' ') // تنظيف المسافات الزائدة
            .trim();
        
        return downloadableTypes.some(type => cleanContentType.includes(type));
    }
    
    // مراقبة fetch requests للتحميلات
    const originalFetch = window.fetch;
    window.fetch = function(...args) {
        const [url, options] = args;
        console.log('SafarGet: Fetch request to:', url);
        
        // مراقبة خاصة للطلبات من about:blank
        if (window.location.href === 'about:blank') {
            console.log('SafarGet: Fetch request from about:blank to:', url);
        }
        
        return originalFetch.apply(this, args).then(response => {
            // التحقق من Content-Disposition header
            const contentDisposition = response.headers.get('Content-Disposition');
            if (contentDisposition && contentDisposition.toLowerCase().includes('attachment')) {
                const responseUrl = response.url;
                const fileName = extractFileNameFromHeaders(response) || extractFileName(responseUrl);
                if (fileName) {
                    console.log('SafarGet: Detected download via fetch Content-Disposition:', fileName);
                    sendDownloadRequest(responseUrl, fileName);
                }
            }
            
            // التحقق من Content-Type للتحميلات
            const contentType = response.headers.get('Content-Type');
            if (contentType && isDownloadableContentType(contentType)) {
                const responseUrl = response.url;
                const fileName = extractFileNameFromHeaders(response) || extractFileName(responseUrl);
                if (fileName) {
                    console.log('SafarGet: Detected download via fetch Content-Type:', contentType, fileName);
                    sendDownloadRequest(responseUrl, fileName);
                }
            }
            
            return response;
        });
    };
    
    // إرسال طلب التحميل مع النظام الذكي الجديد
    function sendDownloadRequest(url, fileName) {
        console.log('🚀 SafarGet: Sending smart download request for:', url);
        console.log('📝 SafarGet: Detected filename:', fileName);
        
        // إرسال البيانات مع معلومات إضافية للتحليل الذكي
        const downloadData = {
            url: url,
            fileName: fileName || 'download',
            pageUrl: window.location.href,
            timestamp: Date.now(),
            userAgent: navigator.userAgent,
            referrer: document.referrer,
            detectionMethod: 'smart_analysis',
            // معلومات إضافية للتحليل الذكي
            urlPattern: analyzeURLPattern(url),
            contentType: getContentTypeFromPage(),
            hasRedirects: checkForRedirects(url),
            isIntermediatePage: window.location.href === 'about:blank' || document.title === 'Untitled',
            pageContent: getPageContentAnalysis()
        };
        
        // استخدام browser.runtime.sendMessage بدلاً من safari.extension.dispatchMessage
        if (typeof browser !== 'undefined' && browser.runtime && browser.runtime.sendMessage) {
            browser.runtime.sendMessage({
                action: 'download_intercepted',
                data: downloadData
            }).then(response => {
                console.log('✅ Download request sent successfully:', response);
            }).catch(error => {
                console.error('❌ Error sending download request:', error);
                // Fallback إلى safari.extension.dispatchMessage
                if (typeof safari !== 'undefined' && safari.extension) {
                    safari.extension.dispatchMessage('downloadFile', downloadData);
                }
            });
        } else if (typeof safari !== 'undefined' && safari.extension) {
            // Fallback إلى safari.extension.dispatchMessage
            safari.extension.dispatchMessage('downloadFile', downloadData);
        } else {
            console.error('❌ No messaging API available');
        }
    }
    
    // تحليل نمط URL للكشف عن الملفات
    function analyzeURLPattern(url) {
        const urlObj = new URL(url);
        const path = urlObj.pathname.toLowerCase();
        const query = urlObj.search.toLowerCase();
        
        // فحص امتدادات الملفات المعروفة
        const fileExtensions = [
            '.zip', '.rar', '.7z', '.tar', '.gz', '.exe', '.dmg', '.pkg', '.deb', '.rpm',
            '.pdf', '.doc', '.docx', '.xls', '.xlsx', '.mp4', '.avi', '.mkv', '.mov', '.wmv',
            '.mp3', '.wav', '.flac', '.aac', '.m4a', '.jpg', '.jpeg', '.png', '.gif', '.bmp',
            '.iso', '.img', '.bin', '.ipsw', '.apk', '.ipa'
        ];
        
        const hasFileExtension = fileExtensions.some(ext => path.endsWith(ext));
        
        // فحص query parameters للبحث عن filename
        const hasFilenameParam = query.includes('filename=') || query.includes('file=');
        
        // فحص path components للأسماء المشبوهة
        const suspiciousPathComponents = ['download', 'file', 'attachment', 'get', 'fetch'];
        const hasSuspiciousPath = suspiciousPathComponents.some(component => path.includes(component));
        
        return {
            hasFileExtension,
            hasFilenameParam,
            hasSuspiciousPath,
            path: path,
            query: query,
            hostname: urlObj.hostname
        };
    }
    
    // الحصول على نوع المحتوى من الصفحة
    function getContentTypeFromPage() {
        const metaContentType = document.querySelector('meta[http-equiv="Content-Type"]');
        if (metaContentType) {
            return metaContentType.getAttribute('content');
        }
        
        // فحص Content-Type header إذا كان متاحاً
        if (window.performance && window.performance.getEntriesByType) {
            const entries = window.performance.getEntriesByType('resource');
            for (const entry of entries) {
                if (entry.name === window.location.href) {
                    return entry.initiatorType;
                }
            }
        }
        
        return null;
    }
    
    // فحص وجود redirects
    function checkForRedirects(url) {
        // فحص إذا كان الرابط من مواقع معروفة بالـ redirects
        const redirectDomains = [
            'mirror.tejas101k.workers.dev',
            'projectinfinity-x.com',
            'github.com',
            'gitlab.com',
            'sourceforge.net'
        ];
        
        const urlObj = new URL(url);
        return redirectDomains.some(domain => urlObj.hostname.includes(domain));
    }
    
    // تحليل محتوى الصفحة
    function getPageContentAnalysis() {
        return {
            title: document.title,
            bodyLength: document.body.innerHTML.length,
            hasDownloadLinks: document.querySelectorAll('a[href*="download"], a[href*="file"]').length > 0,
            hasForms: document.querySelectorAll('form').length > 0,
            hasScripts: document.querySelectorAll('script').length > 0,
            isBlankPage: document.body.innerHTML.trim() === '' || document.body.children.length === 0
        };
    }
    
    // إشعار بتوفر تحميل
    function notifyDownloadAvailable(url, fileName) {
        console.log('Download available:', fileName);
    }
    
    // الاستماع للرسائل من background script
    safari.self.addEventListener('message', function(event) {
        console.log('Received message:', event.name);
        if (event.name === 'downloadFromContextMenu') {
            if (contextMenuTarget) {
                const link = contextMenuTarget.closest('a');
                if (link && link.href) {
                    sendDownloadRequest(link.href, extractFileName(link.href));
                } else if (contextMenuTarget.src) {
                    // للصور والفيديو
                    sendDownloadRequest(contextMenuTarget.src, extractFileName(contextMenuTarget.src));
                }
            }
        }
    });
    
    // ==================== YouTube Download Feature (Fixed) ====================
    
    let currentVideoUrl = null;
    
    // التحقق من صفحة YouTube
    function isYouTubePage() {
        const isYouTube = window.location.hostname.includes('youtube.com') &&
                         (window.location.pathname.includes('/watch') ||
                          window.location.pathname.includes('/shorts'));
        
        console.log('SafarGet: isYouTubePage check:', {
            hostname: window.location.hostname,
            pathname: window.location.pathname,
            result: isYouTube
        });
        
        return isYouTube;
    }
    
    // التحقق من أن الصفحة جاهزة لإضافة الزر
    function isPageReady() {
        // التحقق من وجود عناصر أساسية في YouTube
        const essentialElements = [
            'ytd-player',
            '#movie_player',
            '.html5-video-player',
            '#player',
            'video',
            '#primary',
            '#content',
            'ytd-watch-flexy'
        ];
        
        const foundElements = essentialElements.filter(selector => document.querySelector(selector));
        console.log('SafarGet: Found elements:', foundElements);
        
        // إضافة المزيد من التفاصيل
        essentialElements.forEach(selector => {
            const element = document.querySelector(selector);
            if (element) {
                console.log(`SafarGet: Found ${selector}:`, element.tagName, element.id, element.className);
            }
        });
        
        return foundElements.length > 0;
    }
    
    // الحصول على معرف الفيديو
    function getVideoId() {
        const urlParams = new URLSearchParams(window.location.search);
        const videoId = urlParams.get('v');
        if (videoId) return videoId;
        
        // للـ Shorts
        const pathMatch = window.location.pathname.match(/\/shorts\/([a-zA-Z0-9_-]+)/);
        return pathMatch ? pathMatch[1] : null;
    }
    
    // إنشاء زر التحميل
    function createDownloadButton() {
        console.log('SafarGet: Creating download button...');
        
        if (downloadButton) {
            downloadButton.remove();
        }
        
        downloadButton = document.createElement('div');
        downloadButton.id = 'safarget-download-button';
        
        // استخدام صورة الأيقونة بدلاً من SVG
        const iconImg = document.createElement('img');
        iconImg.src = safari.extension.baseURI + 'icon18.png';
        iconImg.style.width = '20px';
        iconImg.style.height = '20px';
        iconImg.style.filter = 'brightness(0) invert(1)'; // جعل الأيقونة بيضاء
        iconImg.alt = 'Download';
        
        // إضافة معالج للأخطاء في حالة عدم تحميل الصورة
        iconImg.onerror = function() {
            console.log('SafarGet: Failed to load icon, using fallback SVG');
            this.style.display = 'none';
            // إضافة SVG كبديل
            const svgFallback = document.createElement('div');
            svgFallback.innerHTML = `
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                    <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path>
                    <polyline points="7 10 12 15 17 10"></polyline>
                    <line x1="12" y1="15" x2="12" y2="3"></line>
                </svg>
            `;
            downloadButton.appendChild(svgFallback);
        };
        
        downloadButton.appendChild(iconImg);
        
        // تطبيق الأنماط
        Object.assign(downloadButton.style, {
            position: 'absolute',
            top: '10px',
            right: '10px',
            width: '40px',
            height: '40px',
            backgroundColor: 'rgba(255, 0, 0, 0.9)',
            borderRadius: '50%',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            cursor: 'pointer',
            zIndex: '99999',
            color: 'white',
            transition: 'all 0.3s ease',
            border: '2px solid white',
            boxShadow: '0 2px 8px rgba(0, 0, 0, 0.3)',
            fontSize: '16px',
            fontWeight: 'bold'
        });
        
        // تأثيرات التحويم
        downloadButton.addEventListener('mouseenter', function() {
            this.style.backgroundColor = 'rgba(255, 0, 0, 1)';
            this.style.transform = 'scale(1.15)';
            this.style.boxShadow = '0 4px 12px rgba(255, 0, 0, 0.4)';
        });
        
        downloadButton.addEventListener('mouseleave', function() {
            this.style.backgroundColor = 'rgba(255, 0, 0, 0.9)';
            this.style.transform = 'scale(1)';
            this.style.boxShadow = '0 2px 8px rgba(0, 0, 0, 0.3)';
        });
        
        // حدث النقر
        downloadButton.addEventListener('click', function(e) {
            e.stopPropagation();
            e.preventDefault();
            console.log('SafarGet: Download button clicked!');
            showQualityMenu();
        });
        
        console.log('SafarGet: Download button created successfully');
        return downloadButton;
    }
    
    // إنشاء قائمة الجودة (محسنة)
    function createQualityMenu() {
        if (qualityMenu) {
            qualityMenu.remove();
        }
        
        qualityMenu = document.createElement('div');
                    qualityMenu.id = 'safarget-quality-menu';
        
        Object.assign(qualityMenu.style, {
            position: 'absolute',
            top: '50px',
            right: '10px',
            backgroundColor: 'rgba(0, 0, 0, 0.95)',
            borderRadius: '8px',
            padding: '8px',
            zIndex: '10000',
            minWidth: '220px',
            boxShadow: '0 4px 12px rgba(0, 0, 0, 0.4)',
            display: 'none',
            color: 'white',
            fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
            fontSize: '14px',
            backdropFilter: 'blur(10px)'
        });
        
        // إضافة عنوان
        const title = document.createElement('div');
        title.textContent = 'Download Quality';
        Object.assign(title.style, {
            padding: '8px 12px',
            borderBottom: '1px solid rgba(255, 255, 255, 0.2)',
            marginBottom: '8px',
            fontWeight: 'bold',
            fontSize: '16px',
            textAlign: 'center'
        });
        qualityMenu.appendChild(title);
        
        // الجودات المحسنة مع yt-dlp formats صحيحة
        const qualities = [
            {
                id: 'best-video',
                label: '🎬 Best Video + Audio',
                format: 'bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best',
                description: 'Highest quality available',
                type: 'video'
            },
            {
                id: '4k',
                label: '✨ 4K UHD',
                format: 'bestvideo[height>=2160][ext=mp4]+bestaudio[ext=m4a]/best[height>=2160][ext=mp4]',
                description: 'Ultra HD 3840x2160',
                type: 'video'
            },
            {
                id: '2k',
                label: '🌟 2K QHD',
                format: 'bestvideo[height>=1440][ext=mp4]+bestaudio[ext=m4a]/best[height>=1440][ext=mp4]',
                description: 'Quad HD 2560x1440',
                type: 'video'
            },
            {
                id: '1080p',
                label: '🎥 1080p Full HD',
                format: '137+140/248+251/bestvideo[height<=1080][ext=mp4]+bestaudio[ext=m4a]/best[height<=1080][ext=mp4]',
                description: 'Full HD 1920x1080',
                type: 'video'
            },
            {
                id: '720p',
                label: '🎞️ 720p HD',
                format: '136+140/247+251/bestvideo[height<=720][ext=mp4]+bestaudio[ext=m4a]/best[height<=720][ext=mp4]/22',
                description: 'HD 1280x720',
                type: 'video'
            },
            {
                id: '480p',
                label: '📺 480p',
                format: '135+140/244+251/bestvideo[height<=480][ext=mp4]+bestaudio[ext=m4a]/best[height<=480][ext=mp4]/18',
                description: 'SD 854x480',
                type: 'video'
            },
            {
                id: '360p',
                label: '📱 360p',
                format: '134+140/243+251/bestvideo[height<=360][ext=mp4]+bestaudio[ext=m4a]/best[height<=360][ext=mp4]/18',
                description: 'Mobile 640x360',
                type: 'video'
            },
            {
                id: 'audio-best',
                label: '🎵 Best Audio',
                format: 'bestaudio[ext=m4a]/bestaudio',
                description: 'Highest quality audio only',
                type: 'audio',
                audioOnly: true
            },
            {
                id: 'audio-128',
                label: '🎶 Audio 128kbps',
                format: 'bestaudio[abr<=128]/bestaudio',
                description: 'Medium quality audio',
                type: 'audio',
                audioOnly: true
            }
        ];
        
        qualities.forEach(quality => {
            const item = document.createElement('div');
            item.innerHTML = `
                <div style="display: flex; align-items: center; justify-content: space-between;">
                    <div>
                        <div style="font-weight: bold;">${quality.label}</div>
                        <div style="font-size: 12px; color: rgba(255,255,255,0.7); margin-top: 2px;">${quality.description}</div>
                    </div>
                    <div style="font-size: 10px; color: rgba(255,255,255,0.5);">${quality.type}</div>
                </div>
            `;
            
            Object.assign(item.style, {
                padding: '12px',
                cursor: 'pointer',
                borderRadius: '6px',
                transition: 'all 0.2s ease',
                marginBottom: '4px',
                border: '1px solid transparent'
            });
            
            item.addEventListener('mouseenter', function() {
                this.style.backgroundColor = 'rgba(255, 255, 255, 0.1)';
                this.style.border = '1px solid rgba(255, 255, 255, 0.2)';
            });
            
            item.addEventListener('mouseleave', function() {
                this.style.backgroundColor = 'transparent';
                this.style.border = '1px solid transparent';
            });
            
            item.addEventListener('click', function() {
                downloadVideo(quality);
                hideQualityMenu();
            });
            
            qualityMenu.appendChild(item);
        });
        
        // زر الإغلاق
        const closeButton = document.createElement('div');
        closeButton.innerHTML = '✕';
        Object.assign(closeButton.style, {
            position: 'absolute',
            top: '8px',
            right: '8px',
            width: '24px',
            height: '24px',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            cursor: 'pointer',
            borderRadius: '50%',
            backgroundColor: 'rgba(255, 255, 255, 0.1)',
            fontSize: '14px',
            fontWeight: 'bold',
            transition: 'all 0.2s ease'
        });
        
        closeButton.addEventListener('mouseenter', function() {
            this.style.backgroundColor = 'rgba(255, 0, 0, 0.8)';
        });
        
        closeButton.addEventListener('mouseleave', function() {
            this.style.backgroundColor = 'rgba(255, 255, 255, 0.1)';
        });
        
        closeButton.addEventListener('click', hideQualityMenu);
        qualityMenu.appendChild(closeButton);
        
        // إغلاق عند النقر خارج القائمة
        document.addEventListener('click', function(e) {
            if (!qualityMenu.contains(e.target) && e.target !== downloadButton) {
                hideQualityMenu();
            }
        });
        
        return qualityMenu;
    }
    
    // عرض قائمة الجودة
    function showQualityMenu() {
        if (!qualityMenu) {
            qualityMenu = createQualityMenu();
            document.body.appendChild(qualityMenu);
        }
        qualityMenu.style.display = 'block';
    }
    
    // إخفاء قائمة الجودة
    function hideQualityMenu() {
        if (qualityMenu) {
            qualityMenu.style.display = 'none';
        }
    }
    
    // تحميل الفيديو (محسن)
    function downloadVideo(quality) {
        const videoId = getVideoId();
        if (!videoId) {
            console.error('Could not extract video ID');
            return;
        }
        
        const videoUrl = window.location.href;
        
        // محاولة استخراج العنوان من عدة مواقع
        const videoTitle =
            document.querySelector('h1.ytd-video-primary-info-renderer yt-formatted-string')?.textContent ||
            document.querySelector('h1.ytd-video-primary-info-renderer')?.textContent ||
            document.querySelector('h1.title')?.textContent ||
            document.querySelector('#title h1')?.textContent ||
            document.querySelector('.ytp-title')?.textContent ||
            document.querySelector('[data-title]')?.getAttribute('data-title') ||
            document.querySelector('meta[property="og:title"]')?.getAttribute('content') ||
            document.title.replace(' - YouTube', '') ||
            'YouTube Video';
        
        // تنظيف العنوان من الأحرف غير المسموحة
        const cleanTitle = videoTitle.trim()
            .replace(/[<>:"/\\|?*]/g, '')
            .replace(/\s+/g, ' ')
            .substring(0, 100);
        
        console.log('Downloading:', cleanTitle, quality.label);
        console.log('Format:', quality.format);
        console.log('Type:', quality.type);
        console.log('Audio Only:', quality.audioOnly);
        
        // تحديد امتداد الملف
        const fileExtension = quality.audioOnly ? '.mp3' : '.mp4';
        
        // إرسال طلب التحميل للتطبيق
        safari.extension.dispatchMessage('youtubeDownload', {
            url: videoUrl,
            videoId: videoId,
            title: cleanTitle,
            fileName: cleanTitle + fileExtension,
            quality: quality.format,
            qualityLabel: quality.label,
            qualityId: quality.id,
            audioOnly: quality.audioOnly || false,
            type: quality.type || 'video',
            timestamp: Date.now(),
            pageTitle: document.title
        });
        
        // عرض رسالة تأكيد
        showDownloadNotification(quality.label, cleanTitle);
    }
    
    // عرض إشعار التحميل (محسن)
    function showDownloadNotification(quality, title) {
        const notification = document.createElement('div');
        notification.innerHTML = `
            <div style="display: flex; align-items: center; gap: 8px;">
                <div style="width: 6px; height: 6px; background: #00ff00; border-radius: 50%; animation: pulse 1s infinite;"></div>
                <div>
                    <div style="font-weight: bold; margin-bottom: 4px;">Download Started</div>
                    <div style="font-size: 12px; opacity: 0.9;">${quality}</div>
                    <div style="font-size: 11px; opacity: 0.7; margin-top: 2px;">${title.substring(0, 50)}${title.length > 50 ? '...' : ''}</div>
                </div>
            </div>
        `;
        
        Object.assign(notification.style, {
            position: 'fixed',
            bottom: '20px',
            right: '20px',
            backgroundColor: 'rgba(0, 150, 0, 0.95)',
            color: 'white',
            padding: '16px 20px',
            borderRadius: '10px',
            zIndex: '10001',
            fontFamily: '-apple-system, BlinkMacSystemFont, sans-serif',
            fontSize: '14px',
            boxShadow: '0 6px 20px rgba(0, 0, 0, 0.4)',
            backdropFilter: 'blur(10px)',
            border: '1px solid rgba(255, 255, 255, 0.1)',
            maxWidth: '300px',
            animation: 'slideIn 0.3s ease'
        });
        
        document.body.appendChild(notification);
        
        // إضافة تأثير النبض
        const pulseStyle = document.createElement('style');
        pulseStyle.textContent = `
            @keyframes pulse {
                0%, 100% { opacity: 1; }
                50% { opacity: 0.3; }
            }
        `;
        document.head.appendChild(pulseStyle);
        
        setTimeout(() => {
            notification.style.animation = 'slideOut 0.3s ease';
            setTimeout(() => {
                notification.remove();
                pulseStyle.remove();
            }, 300);
        }, 4000);
    }
    
    // إضافة الأنماط للرسوم المتحركة
    function addAnimationStyles() {
        if (document.getElementById('safarget-styles')) return;
        
        const style = document.createElement('style');
        style.id = 'safarget-styles';
        style.textContent = `
            @keyframes slideIn {
                from {
                    transform: translateX(100%);
                    opacity: 0;
                }
                to {
                    transform: translateX(0);
                    opacity: 1;
                }
            }
            
            @keyframes slideOut {
                from {
                    transform: translateX(0);
                    opacity: 1;
                }
                to {
                    transform: translateX(100%);
                    opacity: 0;
                }
            }
        `;
        document.head.appendChild(style);
    }
    
    // البحث عن مشغل الفيديو وإضافة الزر
    function addDownloadButtonToPlayer() {
        console.log('SafarGet: addDownloadButtonToPlayer called');
        console.log('SafarGet: isYouTubePage() =', isYouTubePage());
        console.log('SafarGet: isPageReady() =', isPageReady());
        
        if (!isYouTubePage()) {
            console.log('SafarGet: Not a YouTube page, returning');
            return;
        }
        
        // التحقق من أن الصفحة جاهزة
        if (!isPageReady()) {
            console.log('SafarGet: Page not ready yet, will retry...');
            return;
        }
        
        // البحث عن مشغل الفيديو مع selectors محدثة
        const playerSelectors = [
            '#movie_player',
            '.html5-video-player',
            '#player',
            '#ytd-player',
            'ytd-player',
            '#primary-inner',
            '#primary',
            '#content',
            'ytd-watch-flexy',
            '#above-the-fold',
            '#player-container',
            '#player-container-inner',
            '#secondary-inner',
            '#secondary',
            '#page-manager',
            '#page',
            '#main',
            '#body',
            'body'
        ];
        
        console.log('SafarGet: Testing all player selectors...');
        playerSelectors.forEach(selector => {
            const element = document.querySelector(selector);
            if (element) {
                console.log(`SafarGet: Found player selector "${selector}":`, element.tagName, element.id, element.className);
            }
        });
        
        let playerContainer = null;
        for (const selector of playerSelectors) {
            playerContainer = document.querySelector(selector);
            if (playerContainer) {
                console.log('SafarGet: Found player container with selector:', selector);
                break;
            }
        }
        
        if (playerContainer && !playerContainer.querySelector('#safarget-download-button')) {
            const button = createDownloadButton();
            playerContainer.appendChild(button);
            
            // إضافة قائمة الجودة
            if (!document.querySelector('#safarget-quality-menu')) {
                const menu = createQualityMenu();
                document.body.appendChild(menu);
            }
            
            console.log('SafarGet: Download button added to player successfully!');
        } else if (!playerContainer) {
            console.log('SafarGet: Player container not found, trying alternative approach...');
            
            // محاولة بديلة: إضافة الزر إلى body إذا لم نجد مشغل الفيديو
            if (!document.querySelector('#safarget-download-button')) {
                const button = createDownloadButton();
                // تغيير موضع الزر ليكون في الزاوية العلوية اليمنى من الصفحة
                Object.assign(button.style, {
                    position: 'fixed',
                    top: '80px',
                    right: '20px',
                    zIndex: '99999'
                });
                document.body.appendChild(button);
                
                // إضافة قائمة الجودة
                if (!document.querySelector('#safarget-quality-menu')) {
                    const menu = createQualityMenu();
                    document.body.appendChild(menu);
                }
                
                console.log('SafarGet: Download button added to body as fallback successfully!');
            }
        }
    }
    
    // مراقبة تغييرات الصفحة
    function observePageChanges() {
        let lastAttempt = 0;
        const minInterval = 1000; // الحد الأدنى بين المحاولات (1 ثانية)
        
        const observer = new MutationObserver((mutations) => {
            if (!isYouTubePage()) return;
            
            const now = Date.now();
            if (now - lastAttempt < minInterval) return;
            
            // التحقق من وجود الزر
            if (!document.querySelector('#safarget-download-button')) {
                lastAttempt = now;
                console.log('SafarGet: Page changed, attempting to add download button...');
                setTimeout(() => {
                    addDownloadButtonToPlayer();
                }, 200);
            }
        });
        
        observer.observe(document.body, {
            childList: true,
            subtree: true,
            attributes: true,
            attributeFilter: ['class', 'id']
        });
        
        console.log('SafarGet: Page change observer started');
    }
    
    // تهيئة ميزة YouTube
    function initYouTubeFeature() {
        if (!isYouTubePage()) return;
        
        console.log('SafarGet: Initializing YouTube feature');
        addAnimationStyles();
        
        // محاولات متعددة لإضافة الزر مع فترات انتظار مختلفة
        const attempts = [500, 1000, 2000, 3000, 5000];
        
        attempts.forEach((delay, index) => {
            setTimeout(() => {
                console.log(`SafarGet: Attempt ${index + 1} to add download button (${delay}ms)`);
                addDownloadButtonToPlayer();
            }, delay);
        });
        
        // بدء مراقبة التغييرات
        setTimeout(() => {
            observePageChanges();
        }, 1000);
    }
    
    // تشغيل عند تحميل الصفحة
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', initYouTubeFeature);
    } else {
        initYouTubeFeature();
    }
    
    // مراقبة تغيير URL (للتنقل في YouTube بدون إعادة تحميل)
    let lastUrl = location.href;
    new MutationObserver(() => {
        const url = location.href;
        if (url !== lastUrl) {
            lastUrl = url;
            console.log('SafarGet: URL changed, reinitializing...');
            
            // تنظيف الأزرار القديمة
            const oldButton = document.querySelector('#safarget-download-button');
            if (oldButton) {
                oldButton.remove();
                console.log('SafarGet: Removed old download button');
            }
            
            const oldMenu = document.querySelector('#safarget-quality-menu');
            if (oldMenu) {
                oldMenu.remove();
                console.log('SafarGet: Removed old quality menu');
            }
            
            setTimeout(initYouTubeFeature, 1000);
        }
    }).observe(document, { subtree: true, childList: true });

// =================================================
// 🎯 اختبار شامل للنظام
// =================================================
setTimeout(() => {
    console.log('🧪 Running comprehensive system test...');
    
    // اختبار الدوال الأساسية
    const testUrl = 'https://example.com/test.zip';
    console.log('🔍 Testing isDownloadableLink:', isDownloadableLink(testUrl));
    console.log('🔍 Testing isDirectFileLink:', isDirectFileLink(testUrl));
    
    // اختبار إرسال رسالة
    if (typeof browser !== 'undefined' && browser.runtime && browser.runtime.sendMessage) {
        browser.runtime.sendMessage({
            action: 'test_connection',
            data: { test: true }
        }).then(response => {
            console.log('✅ Test message sent successfully:', response);
        }).catch(error => {
            console.error('❌ Test message failed:', error);
        });
    }
    
    // اختبار postMessage
    window.postMessage({
        type: 'TEST_MESSAGE',
        data: { test: true }
    }, '*');
    
    console.log('✅ Comprehensive system test completed');
}, 2000);
    
    // مراقبة navigation events للتحميلات
    function setupNavigationMonitoring() {
        // مراقبة beforeunload للتحقق من التحميلات
        window.addEventListener('beforeunload', function(e) {
            // التحقق من أن الصفحة تحتوي على Content-Disposition
            if (document.querySelector('meta[http-equiv="Content-Disposition"]')) {
                console.log('SafarGet: Detected Content-Disposition in page meta');
            }
        });
        
        // مراقبة visibility change للتحقق من التحميلات في الخلفية
        document.addEventListener('visibilitychange', function() {
            if (document.hidden) {
                // الصفحة أصبحت مخفية، قد يكون هناك تحميل
                console.log('SafarGet: Page became hidden, monitoring for downloads');
                
                // إذا كانت الصفحة about:blank وأصبحت مخفية، قد يكون هناك تحميل
                if (window.location.href === 'about:blank') {
                    console.log('SafarGet: about:blank page hidden - download likely started');
                    
                    // محاولة التقاط التحميل من خلال مراقبة التغييرات
                    setTimeout(() => {
                        if (window.location.href !== 'about:blank') {
                            console.log('SafarGet: about:blank redirected to:', window.location.href);
                            const fileName = extractFileName(window.location.href);
                            if (fileName) {
                                sendDownloadRequest(window.location.href, fileName);
                            }
                        }
                    }, 500);
                }
            }
        });
        
        // مراقبة window.open للتحميلات
        const originalWindowOpen = window.open;
        window.open = function(url, target, features) {
            console.log('SafarGet: window.open called with URL:', url);
            
            // مراقبة خاصة للطلبات من about:blank
            if (window.location.href === 'about:blank') {
                console.log('SafarGet: window.open from about:blank to:', url);
                
                // إذا كان الرابط قابل للتحميل، قم بالتقاطه فوراً
                if (url && shouldMonitorForContentDisposition(url)) {
                    console.log('SafarGet: Download detected from about:blank window.open');
                    const fileName = extractFileName(url);
                    if (fileName) {
                        sendDownloadRequest(url, fileName);
                    }
                }
            }
            
            if (url && shouldMonitorForContentDisposition(url)) {
                console.log('SafarGet: Monitoring window.open for Content-Disposition:', url);
            }
            return originalWindowOpen.apply(this, arguments);
        };
        
        // مراقبة window.location.href للتحميلات
        const originalLocationHref = Object.getOwnPropertyDescriptor(window.location, 'href');
        Object.defineProperty(window.location, 'href', {
            get: function() {
                return originalLocationHref.get.call(this);
            },
            set: function(value) {
                console.log('SafarGet: window.location.href changed to:', value);
                
                // مراقبة التغييرات من about:blank
                if (window.location.href === 'about:blank' && value !== 'about:blank') {
                    console.log('SafarGet: about:blank redirecting to:', value);
                    
                    // التحقق من أن الرابط الجديد قابل للتحميل
                    if (shouldMonitorForContentDisposition(value)) {
                        console.log('SafarGet: Download detected from about:blank redirect');
                        const fileName = extractFileName(value);
                        if (fileName) {
                            sendDownloadRequest(value, fileName);
                        }
                    }
                }
                
                if (value && shouldMonitorForContentDisposition(value)) {
                    console.log('SafarGet: Monitoring location.href for Content-Disposition:', value);
                }
                return originalLocationHref.set.call(this, value);
            }
        });
        
        // مراقبة window.location.assign للتحميلات
        const originalLocationAssign = window.location.assign;
        window.location.assign = function(url) {
            console.log('SafarGet: window.location.assign called with URL:', url);
            if (url && shouldMonitorForContentDisposition(url)) {
                console.log('SafarGet: Monitoring location.assign for Content-Disposition:', url);
            }
            return originalLocationAssign.call(this, url);
        };
        
        // مراقبة window.location.replace للتحميلات
        const originalLocationReplace = window.location.replace;
        window.location.replace = function(url) {
            console.log('SafarGet: window.location.replace called with URL:', url);
            if (url && shouldMonitorForContentDisposition(url)) {
                console.log('SafarGet: Monitoring location.replace for Content-Disposition:', url);
            }
            return originalLocationReplace.call(this, url);
        };
        
        // مراقبة location.href changes
        let currentLocation = window.location.href;
        setInterval(() => {
            if (window.location.href !== currentLocation) {
                const newLocation = window.location.href;
                
                // مراقبة خاصة للتغييرات من about:blank
                if (currentLocation === 'about:blank' && newLocation !== 'about:blank') {
                    console.log('SafarGet: about:blank redirected to:', newLocation);
                    
                    // التحقق من أن الرابط الجديد قابل للتحميل
                    if (shouldMonitorForContentDisposition(newLocation)) {
                        console.log('SafarGet: Download detected from about:blank redirect');
                        const fileName = extractFileName(newLocation);
                        if (fileName) {
                            sendDownloadRequest(newLocation, fileName);
                        }
                    }
                }
                
                if (shouldMonitorForContentDisposition(newLocation)) {
                    console.log('SafarGet: Location changed to monitored URL:', newLocation);
                }
                currentLocation = newLocation;
            }
        }, 100); // تقليل الفاصل الزمني لمراقبة أسرع
        
        // مراقبة form submissions للتحميلات
        document.addEventListener('submit', function(e) {
            const form = e.target;
            console.log('SafarGet: Form submission to:', form.action);
            if (form.action && shouldMonitorForContentDisposition(form.action)) {
                console.log('SafarGet: Form submission to monitored URL:', form.action);
            }
        });
        
        // مراقبة Beacon API للتحميلات
        if (navigator.sendBeacon) {
            const originalSendBeacon = navigator.sendBeacon;
            navigator.sendBeacon = function(url, data) {
                console.log('SafarGet: sendBeacon called with URL:', url);
                if (url && shouldMonitorForContentDisposition(url)) {
                    console.log('SafarGet: Monitoring sendBeacon for Content-Disposition:', url);
                }
                return originalSendBeacon.call(this, url, data);
            };
        }
        
        // مراقبة Navigator API للتحميلات
        if (navigator.share) {
            const originalShare = navigator.share;
            navigator.share = function(data) {
                console.log('SafarGet: navigator.share called with data:', data);
                if (data && data.url && shouldMonitorForContentDisposition(data.url)) {
                    console.log('SafarGet: Monitoring navigator.share for Content-Disposition:', data.url);
                }
                return originalShare.call(this, data);
            };
        }
        
        // مراقبة جميع أنواع الطلبات HTTP
        const originalCreateElement = document.createElement;
        document.createElement = function(tagName) {
            const element = originalCreateElement.call(this, tagName);
            
            if (tagName.toLowerCase() === 'script') {
                // مراقبة إضافة scripts جديدة
                setTimeout(() => {
                    if (element.src) {
                        console.log('SafarGet: New script added with src:', element.src);
                    }
                }, 0);
            }
            
            return element;
        };
        
        // مراقبة إضافة عناصر جديدة للصفحة
        const observer = new MutationObserver((mutations) => {
            mutations.forEach((mutation) => {
                mutation.addedNodes.forEach((node) => {
                    if (node.nodeType === Node.ELEMENT_NODE) {
                        const element = node;
                        
                        // مراقبة إضافة أزرار التحميل
                        if (element.textContent && element.textContent.toLowerCase().includes('download')) {
                            console.log('SafarGet: Download button added to page:', element.textContent);
                        }
                        
                        // مراقبة إضافة روابط التحميل
                        if (element.tagName === 'A' && element.href) {
                            if (shouldMonitorForContentDisposition(element.href)) {
                                console.log('SafarGet: Download link added to page:', element.href);
                            }
                        }
                    }
                });
            });
        });
        
        observer.observe(document.body, {
            childList: true,
            subtree: true
        });
    }
    
    // إضافة console log للتأكد من تحميل السكريبت
    console.log('SafaRGo content script loaded with enhanced YouTube support and Content-Disposition monitoring');
    
    // تشغيل مراقبة navigation
    setupNavigationMonitoring();
    
    // مراقبة شاملة لجميع أنواع الطلبات
    console.log('SafarGet: Starting comprehensive monitoring for projectinfinity-x.com and similar sites');
    
    // مراقبة إضافية للمواقع المعقدة
    if (window.location.hostname.includes('projectinfinity-x.com')) {
        console.log('SafarGet: Enhanced monitoring enabled for projectinfinity-x.com');
        
        // مراقبة جميع النقرات على الصفحة
        document.addEventListener('click', function(e) {
            const target = e.target;
            console.log('SafarGet: Click detected on:', target.tagName, target.textContent?.substring(0, 50));
        }, true);
    }
    
    // مراقبة شاملة لجميع أنواع الصفحات الوسيطة للتحميلات
    function setupComprehensivePageMonitoring() {
        const currentUrl = window.location.href;
        const currentTitle = document.title;
        
        // مراقبة الصفحات الوسيطة (about:blank, Untitled, blank pages)
        const isIntermediatePage = (
            currentUrl === 'about:blank' || 
            currentUrl === 'about:blank#' ||
            currentTitle === 'Untitled' ||
            currentTitle === '' ||
            currentTitle === 'about:blank' ||
            document.body.innerHTML.trim() === '' ||
            document.body.children.length === 0
        );
        
        if (isIntermediatePage) {
            console.log('SafarGet: Detected intermediate page - URL:', currentUrl, 'Title:', currentTitle);
            console.log('SafarGet: Body content length:', document.body.innerHTML.length);
            console.log('SafarGet: Body children count:', document.body.children.length);
            
            // مراقبة شاملة لجميع أنواع الطلبات
            monitorAllRequests();
            
            // مراقبة التغييرات في location
            let lastLocation = window.location.href;
            let lastTitle = document.title;
            
            setInterval(() => {
                const newLocation = window.location.href;
                const newTitle = document.title;
                
                if (newLocation !== lastLocation) {
                    console.log('SafarGet: Intermediate page location changed to:', newLocation);
                    lastLocation = newLocation;
                    
                    // التحقق من أن الرابط الجديد قابل للتحميل
                    if (shouldMonitorForContentDisposition(newLocation)) {
                        console.log('SafarGet: Download detected from intermediate page redirect');
                        const fileName = extractFileName(newLocation);
                        if (fileName) {
                            sendDownloadRequest(newLocation, fileName);
                        }
                    }
                }
                
                if (newTitle !== lastTitle) {
                    console.log('SafarGet: Intermediate page title changed to:', newTitle);
                    lastTitle = newTitle;
                }
            }, 50); // مراقبة أسرع
            
            // مراقبة beforeunload للتحميلات
            window.addEventListener('beforeunload', function(e) {
                console.log('SafarGet: Intermediate page unloading - possible download');
                console.log('SafarGet: Final URL before unload:', window.location.href);
                console.log('SafarGet: Final title before unload:', document.title);
            });
            
            // مراقبة visibility change للتحميلات
            document.addEventListener('visibilitychange', function() {
                if (document.hidden) {
                    console.log('SafarGet: Intermediate page became hidden - download likely started');
                    
                    // محاولة التقاط التحميل من خلال مراقبة التغييرات
                    setTimeout(() => {
                        if (window.location.href !== currentUrl) {
                            console.log('SafarGet: Intermediate page redirected to:', window.location.href);
                            const fileName = extractFileName(window.location.href);
                            if (fileName) {
                                sendDownloadRequest(window.location.href, fileName);
                            }
                        }
                    }, 200);
                }
            });
            
            // مراقبة DOM changes للتحميلات
            const observer = new MutationObserver(function(mutations) {
                mutations.forEach(function(mutation) {
                    if (mutation.type === 'childList' && mutation.addedNodes.length > 0) {
                        console.log('SafarGet: DOM changed in intermediate page');
                        mutation.addedNodes.forEach(function(node) {
                            if (node.nodeType === Node.ELEMENT_NODE) {
                                console.log('SafarGet: Added element:', node.tagName, node.innerHTML?.substring(0, 100));
                            }
                        });
                    }
                });
            });
            
            observer.observe(document.body, {
                childList: true,
                subtree: true
            });
        }
    }
    
    // مراقبة شاملة لجميع أنواع الطلبات
    function monitorAllRequests() {
        console.log('SafarGet: Setting up comprehensive request monitoring');
        
        // مراقبة جميع أنواع الطلبات HTTP
        monitorHTTPRequests();
        
        // مراقبة جميع أنواع التنقل
        monitorNavigation();
        
        // مراقبة جميع أنواع الأحداث
        monitorEvents();
        
        // مراقبة جميع أنواع التغييرات
        monitorChanges();
    }
    
    // مراقبة جميع أنواع الطلبات HTTP
    function monitorHTTPRequests() {
        console.log('SafarGet: Monitoring HTTP requests');
        
        // مراقبة XMLHttpRequest
        const originalXHROpen = XMLHttpRequest.prototype.open;
        XMLHttpRequest.prototype.open = function(method, url) {
            console.log('SafarGet: XHR Request:', method, url);
            console.log('SafarGet: XHR from page:', window.location.href, 'Title:', document.title);
            
            this.addEventListener('load', function() {
                console.log('SafarGet: XHR Response:', this.status, this.responseURL);
                console.log('SafarGet: XHR Headers:', {
                    'Content-Type': this.getResponseHeader('Content-Type'),
                    'Content-Disposition': this.getResponseHeader('Content-Disposition'),
                    'Content-Length': this.getResponseHeader('Content-Length')
                });
                
                if (this.status === 200) {
                    const contentDisposition = this.getResponseHeader('Content-Disposition');
                    if (contentDisposition && contentDisposition.toLowerCase().includes('attachment')) {
                        console.log('SafarGet: Download detected via XHR Content-Disposition');
                        const fileName = extractFileNameFromHeaders(this) || extractFileName(url);
                        if (fileName) {
                            sendDownloadRequest(url, fileName);
                        }
                    }
                }
            });
            
            return originalXHROpen.apply(this, arguments);
        };
        
        // مراقبة Fetch
        const originalFetch = window.fetch;
        window.fetch = function(...args) {
            const [url, options] = args;
            console.log('SafarGet: Fetch Request:', url);
            console.log('SafarGet: Fetch from page:', window.location.href, 'Title:', document.title);
            
            return originalFetch.apply(this, args).then(response => {
                console.log('SafarGet: Fetch Response:', response.status, response.url);
                console.log('SafarGet: Fetch Headers:', {
                    'Content-Type': response.headers.get('Content-Type'),
                    'Content-Disposition': response.headers.get('Content-Disposition'),
                    'Content-Length': response.headers.get('Content-Length')
                });
                
                const contentDisposition = response.headers.get('Content-Disposition');
                if (contentDisposition && contentDisposition.toLowerCase().includes('attachment')) {
                    console.log('SafarGet: Download detected via Fetch Content-Disposition');
                    const fileName = extractFileNameFromHeaders(response) || extractFileName(url);
                    if (fileName) {
                        sendDownloadRequest(response.url, fileName);
                    }
                }
                
                return response;
            });
        };
    }
    
    // مراقبة جميع أنواع التنقل
    function monitorNavigation() {
        console.log('SafarGet: Monitoring navigation');
        
        // مراقبة window.open
        const originalWindowOpen = window.open;
        window.open = function(url, target, features) {
            console.log('SafarGet: window.open:', url, 'target:', target, 'features:', features);
            console.log('SafarGet: window.open from page:', window.location.href, 'Title:', document.title);
            
            if (url && shouldMonitorForContentDisposition(url)) {
                console.log('SafarGet: Download detected via window.open');
                const fileName = extractFileName(url);
                if (fileName) {
                    sendDownloadRequest(url, fileName);
                }
            }
            
            return originalWindowOpen.apply(this, arguments);
        };
        
        // مراقبة window.location.href
        const originalLocationHref = Object.getOwnPropertyDescriptor(window.location, 'href');
        Object.defineProperty(window.location, 'href', {
            get: function() {
                return originalLocationHref.get.call(this);
            },
            set: function(value) {
                console.log('SafarGet: location.href changed to:', value);
                console.log('SafarGet: location.href from page:', window.location.href, 'Title:', document.title);
                
                if (value && shouldMonitorForContentDisposition(value)) {
                    console.log('SafarGet: Download detected via location.href');
                    const fileName = extractFileName(value);
                    if (fileName) {
                        sendDownloadRequest(value, fileName);
                    }
                }
                
                return originalLocationHref.set.call(this, value);
            }
        });
        
        // مراقبة window.location.assign
        const originalLocationAssign = window.location.assign;
        window.location.assign = function(url) {
            console.log('SafarGet: location.assign:', url);
            console.log('SafarGet: location.assign from page:', window.location.href, 'Title:', document.title);
            
            if (url && shouldMonitorForContentDisposition(url)) {
                console.log('SafarGet: Download detected via location.assign');
                const fileName = extractFileName(url);
                if (fileName) {
                    sendDownloadRequest(url, fileName);
                }
            }
            
            return originalLocationAssign.apply(this, arguments);
        };
        
        // مراقبة window.location.replace
        const originalLocationReplace = window.location.replace;
        window.location.replace = function(url) {
            console.log('SafarGet: location.replace:', url);
            console.log('SafarGet: location.replace from page:', window.location.href, 'Title:', document.title);
            
            if (url && shouldMonitorForContentDisposition(url)) {
                console.log('SafarGet: Download detected via location.replace');
                const fileName = extractFileName(url);
                if (fileName) {
                    sendDownloadRequest(url, fileName);
                }
            }
            
            return originalLocationReplace.apply(this, arguments);
        };
    }
    
    // مراقبة جميع أنواع الأحداث
    function monitorEvents() {
        console.log('SafarGet: Monitoring events');
        
        // مراقبة جميع النقرات
        document.addEventListener('click', function(e) {
            const target = e.target;
            console.log('SafarGet: Click event on:', target.tagName, target.textContent?.substring(0, 50));
            console.log('SafarGet: Click from page:', window.location.href, 'Title:', document.title);
            
            // التحقق من الروابط
            const link = target.closest('a');
            if (link && link.href) {
                console.log('SafarGet: Click on link:', link.href);
                if (shouldMonitorForContentDisposition(link.href)) {
                    console.log('SafarGet: Download link clicked');
                    const fileName = extractFileName(link.href);
                    if (fileName) {
                        sendDownloadRequest(link.href, fileName);
                    }
                }
            }
        }, true);
        
        // مراقبة جميع النماذج
        document.addEventListener('submit', function(e) {
            const form = e.target;
            console.log('SafarGet: Form submission:', form.action);
            console.log('SafarGet: Form from page:', window.location.href, 'Title:', document.title);
            
            if (form.action && shouldMonitorForContentDisposition(form.action)) {
                console.log('SafarGet: Download form submitted');
                const fileName = extractFileName(form.action);
                if (fileName) {
                    sendDownloadRequest(form.action, fileName);
                }
            }
        });
    }
    
    // مراقبة جميع أنواع التغييرات
    function monitorChanges() {
        console.log('SafarGet: Monitoring changes');
        
        // مراقبة التغييرات في location
        let lastLocation = window.location.href;
        let lastTitle = document.title;
        
        setInterval(() => {
            const newLocation = window.location.href;
            const newTitle = document.title;
            
            if (newLocation !== lastLocation) {
                console.log('SafarGet: Location changed from', lastLocation, 'to', newLocation);
                lastLocation = newLocation;
                
                if (shouldMonitorForContentDisposition(newLocation)) {
                    console.log('SafarGet: Download detected via location change');
                    const fileName = extractFileName(newLocation);
                    if (fileName) {
                        sendDownloadRequest(newLocation, fileName);
                    }
                }
            }
            
            if (newTitle !== lastTitle) {
                console.log('SafarGet: Title changed from', lastTitle, 'to', newTitle);
                lastTitle = newTitle;
            }
        }, 25); // مراقبة أسرع جداً
    }
    
    // إضافة console log للتأكد من تحميل السكريبت
    console.log('🚀 SafarGet content script loaded successfully!');
    console.log('🎯 Current URL:', window.location.href);
    console.log('📍 Current hostname:', window.location.hostname);
    console.log('🎬 isYouTubePage():', isYouTubePage());
    
    // إضافة علامة واضحة في DOM
    const debugMarker = document.createElement('div');
    debugMarker.id = 'safarget-debug-marker';
    debugMarker.style.cssText = 'position: fixed; top: 0; left: 0; background: red; color: white; padding: 5px; z-index: 99999; font-size: 12px;';
    debugMarker.textContent = 'SafarGet Active - ' + (isYouTubePage() ? 'YouTube' : 'Other');
    document.body.appendChild(debugMarker);
    
    // إضافة دالة لاختبار الإضافة
    window.testSafarGetExtension = function() {
        console.log('SafarGet Extension Test:');
        console.log('1. Content script loaded:', true);
        console.log('2. YouTube page detected:', isYouTubePage());
        console.log('3. Page ready:', isPageReady());
        console.log('4. Debug marker visible:', !!document.querySelector('#safarget-debug-marker'));
        console.log('5. Download button exists:', !!document.querySelector('#safarget-download-button'));
        console.log('6. Quality menu exists:', !!document.querySelector('#safarget-quality-menu'));
        
        if (isYouTubePage()) {
            console.log('7. Attempting to add download button...');
            addDownloadButtonToPlayer();
        }
    };
    
    // تشغيل اختبار فوري
    setTimeout(() => {
        console.log('SafarGet: Running initial test...');
        window.testSafarGetExtension();
        window.testAllSelectors();
        
        // محاولة إضافة الزر مرة أخرى
        if (isYouTubePage()) {
            console.log('SafarGet: Attempting to add download button after initial test...');
            addDownloadButtonToPlayer();
            
            // محاولة إضافة الزر إلى body إذا لم يتم العثور على مشغل الفيديو
            if (!document.querySelector('#safarget-download-button')) {
                console.log('SafarGet: Adding button to body after initial test...');
                const button = createDownloadButton();
                Object.assign(button.style, {
                    position: 'fixed',
                    top: '160px',
                    right: '60px',
                    zIndex: '999999'
                });
                document.body.appendChild(button);
                console.log('SafarGet: Button added to body after initial test');
            }
            
            // إضافة قائمة الجودة إذا لم تكن موجودة
            if (!document.querySelector('#safarget-quality-menu')) {
                console.log('SafarGet: Adding quality menu to body after initial test...');
                const menu = createQualityMenu();
                document.body.appendChild(menu);
                console.log('SafarGet: Quality menu added to body after initial test');
            }
        }
    }, 2000);
    
    // تشغيل اختبار شامل بعد 5 ثوان
    setTimeout(() => {
        console.log('SafarGet: Running comprehensive test...');
        window.debugSafarGet();
        window.testAllSelectors();
        
        // محاولة إضافة الزر مرة أخرى
        if (isYouTubePage()) {
            console.log('SafarGet: Attempting to add download button after comprehensive test...');
            addDownloadButtonToPlayer();
            
            // محاولة إضافة الزر إلى body إذا لم يتم العثور على مشغل الفيديو
            if (!document.querySelector('#safarget-download-button')) {
                console.log('SafarGet: Adding button to body after comprehensive test...');
                const button = createDownloadButton();
                Object.assign(button.style, {
                    position: 'fixed',
                    top: '140px',
                    right: '50px',
                    zIndex: '999999'
                });
                document.body.appendChild(button);
                console.log('SafarGet: Button added to body after comprehensive test');
            }
            
            // إضافة قائمة الجودة إذا لم تكن موجودة
            if (!document.querySelector('#safarget-quality-menu')) {
                console.log('SafarGet: Adding quality menu to body after comprehensive test...');
                const menu = createQualityMenu();
                document.body.appendChild(menu);
                console.log('SafarGet: Quality menu added to body after comprehensive test');
            }
        }
    }, 5000);
    
    // تشغيل فحص شامل بعد 10 ثوان
    setTimeout(() => {
        console.log('SafarGet: Running element scan...');
        window.scanAllElements();
        window.testAllSelectors();
        
        // محاولة إضافة الزر مرة أخرى
        if (isYouTubePage()) {
            console.log('SafarGet: Attempting to add download button after scan...');
            addDownloadButtonToPlayer();
            
            // محاولة إضافة الزر إلى body إذا لم يتم العثور على مشغل الفيديو
            if (!document.querySelector('#safarget-download-button')) {
                console.log('SafarGet: Adding button to body after scan...');
                const button = createDownloadButton();
                Object.assign(button.style, {
                    position: 'fixed',
                    top: '120px',
                    right: '40px',
                    zIndex: '999999'
                });
                document.body.appendChild(button);
                console.log('SafarGet: Button added to body after scan');
            }
            
            // إضافة قائمة الجودة إذا لم تكن موجودة
            if (!document.querySelector('#safarget-quality-menu')) {
                console.log('SafarGet: Adding quality menu to body after scan...');
                const menu = createQualityMenu();
                document.body.appendChild(menu);
                console.log('SafarGet: Quality menu added to body after scan');
            }
        }
    }, 10000);
    
    // تشغيل اختبار نهائي بعد 15 ثانية
    setTimeout(() => {
        console.log('SafarGet: Running final test...');
        if (isYouTubePage()) {
            console.log('SafarGet: Final attempt to add download button...');
            addDownloadButtonToPlayer();
            window.testAllSelectors();
            
            // محاولة إضافة الزر إلى body مباشرة
            if (!document.querySelector('#safarget-download-button')) {
                console.log('SafarGet: Adding button directly to body as last resort...');
                const button = createDownloadButton();
                Object.assign(button.style, {
                    position: 'fixed',
                    top: '100px',
                    right: '30px',
                    zIndex: '999999'
                });
                document.body.appendChild(button);
                console.log('SafarGet: Button added to body as last resort');
            }
            
            // إضافة قائمة الجودة إذا لم تكن موجودة
            if (!document.querySelector('#safarget-quality-menu')) {
                console.log('SafarGet: Adding quality menu to body...');
                const menu = createQualityMenu();
                document.body.appendChild(menu);
                console.log('SafarGet: Quality menu added to body');
            }
        }
    }, 15000);
    
    // إضافة دالة لاختبار جميع العناصر في الصفحة
    window.testAllSelectors = function() {
        console.log('=== Testing All Selectors ===');
        const allSelectors = [
            'ytd-player', '#movie_player', '.html5-video-player', '#player', 'video',
            '#primary', '#content', 'ytd-watch-flexy', '#above-the-fold',
            '#player-container', '#secondary', '#page-manager', 'body',
            '#main', '#app', '#root', '#container', '#wrapper'
        ];
        
        allSelectors.forEach(selector => {
            const elements = document.querySelectorAll(selector);
            if (elements.length > 0) {
                console.log(`✓ ${selector}: Found ${elements.length} element(s)`);
                elements.forEach((element, index) => {
                    console.log(`  ${index + 1}. ${element.tagName} id="${element.id}" class="${element.className}"`);
                });
            } else {
                console.log(`✗ ${selector}: Not found`);
            }
        });
        console.log('========================');
    };
    
    // إضافة دالة اختبار للزر (يمكن استدعاؤها من Console)
    window.testSafarGetButton = function() {
        console.log('SafarGet: Testing button addition...');
        console.log('SafarGet: isYouTubePage() =', isYouTubePage());
        console.log('SafarGet: isPageReady() =', isPageReady());
        console.log('SafarGet: Current URL =', window.location.href);
        console.log('SafarGet: Document ready state =', document.readyState);
        addDownloadButtonToPlayer();
    };
    
    // دالة اختبار إضافية
    window.debugSafarGet = function() {
        console.log('=== SafarGet Debug Info ===');
        console.log('URL:', window.location.href);
        console.log('Hostname:', window.location.hostname);
        console.log('Pathname:', window.location.pathname);
        console.log('isYouTubePage():', isYouTubePage());
        console.log('isPageReady():', isPageReady());
        console.log('Document ready state:', document.readyState);
        console.log('Existing button:', document.querySelector('#safarget-download-button'));
        console.log('Existing menu:', document.querySelector('#safarget-quality-menu'));
        console.log('Debug marker:', document.querySelector('#safarget-debug-marker'));
        
        // اختبار جميع العناصر المهمة
        console.log('--- Testing Important Elements ---');
        const importantSelectors = [
            'ytd-player', '#movie_player', '.html5-video-player', '#player', 'video',
            '#primary', '#content', 'ytd-watch-flexy', '#above-the-fold',
            '#player-container', '#secondary', '#page-manager', 'body'
        ];
        
        importantSelectors.forEach(selector => {
            const element = document.querySelector(selector);
            if (element) {
                console.log(`✓ ${selector}:`, element.tagName, element.id, element.className);
            } else {
                console.log(`✗ ${selector}: Not found`);
            }
        });
        
        console.log('========================');
    };
    
    // إضافة دالة لإزالة الزر (للاختبار)
    window.removeSafarGetButton = function() {
        const button = document.querySelector('#safarget-download-button');
        const menu = document.querySelector('#safarget-quality-menu');
        if (button) button.remove();
        if (menu) menu.remove();
        console.log('SafarGet: Removed download button and menu');
    };
    
    // دالة لاختبار جميع العناصر في الصفحة
    window.scanAllElements = function() {
        console.log('=== Scanning All Elements ===');
        const allElements = document.querySelectorAll('*');
        const elementCounts = {};
        
        allElements.forEach(element => {
            const tag = element.tagName.toLowerCase();
            elementCounts[tag] = (elementCounts[tag] || 0) + 1;
            
            // البحث عن العناصر المهمة
            if (element.id && (element.id.includes('player') || element.id.includes('video') || element.id.includes('movie'))) {
                console.log('Found important element:', element.tagName, element.id, element.className);
            }
        });
        
        console.log('Element counts:', elementCounts);
        console.log('Total elements:', allElements.length);
        console.log('========================');
    };
    
    // دالة لإجبار إضافة الزر
    window.forceAddButton = function() {
        console.log('SafarGet: Force adding button...');
        
        // إزالة الأزرار الموجودة
        const existingButton = document.querySelector('#safarget-download-button');
        const existingMenu = document.querySelector('#safarget-quality-menu');
        if (existingButton) existingButton.remove();
        if (existingMenu) existingMenu.remove();
        
        // إنشاء وإضافة الزر
        const button = createDownloadButton();
        Object.assign(button.style, {
            position: 'fixed',
            top: '70px',
            right: '15px',
            zIndex: '999999',
            backgroundColor: 'rgba(255, 0, 0, 1)',
            border: '3px solid white',
            boxShadow: '0 4px 15px rgba(255, 0, 0, 0.5)'
        });
        document.body.appendChild(button);
        
        // إنشاء وإضافة قائمة الجودة
        const menu = createQualityMenu();
        document.body.appendChild(menu);
        
        console.log('SafarGet: Button and menu force added!');
        return { button, menu };
    };
    
    // تشغيل مراقبة navigation
    setupNavigationMonitoring();
    
    // تشغيل مراقبة شاملة للصفحات الوسيطة
    setupComprehensivePageMonitoring();
    
    // تشغيل ميزة YouTube إذا كانت الصفحة مناسبة
    if (isYouTubePage()) {
        console.log('SafarGet: YouTube page detected, initializing feature...');
        initYouTubeFeature();
        
        // إضافة الزر مباشرة إلى body كخطة بديلة
        setTimeout(() => {
            if (!document.querySelector('#safarget-download-button')) {
                console.log('SafarGet: Adding button to body as backup...');
                const button = createDownloadButton();
                Object.assign(button.style, {
                    position: 'fixed',
                    top: '80px',
                    right: '20px',
                    zIndex: '999999'
                });
                document.body.appendChild(button);
                
                const menu = createQualityMenu();
                document.body.appendChild(menu);
                console.log('SafarGet: Button and menu added to body as backup');
            }
        }, 3000);
    }
    
    // إضافة استدعاء إضافي عند تحميل الصفحة بالكامل
    window.addEventListener('load', function() {
        console.log('SafarGet: Window loaded, checking for YouTube...');
        if (isYouTubePage()) {
            console.log('SafarGet: YouTube page detected on window load, initializing...');
            setTimeout(initYouTubeFeature, 1000);
            
            // إضافة الزر مباشرة إلى body كخطة بديلة
            setTimeout(() => {
                if (!document.querySelector('#safarget-download-button')) {
                    console.log('SafarGet: Adding button to body on window load...');
                    const button = createDownloadButton();
                    Object.assign(button.style, {
                        position: 'fixed',
                        top: '90px',
                        right: '25px',
                        zIndex: '999999'
                    });
                    document.body.appendChild(button);
                    
                    const menu = createQualityMenu();
                    document.body.appendChild(menu);
                    console.log('SafarGet: Button and menu added to body on window load');
                }
            }, 4000);
        }
    });
    
    // مراقبة شاملة لجميع أنواع الطلبات
    console.log('SafarGet: Starting comprehensive monitoring for projectinfinity-x.com and similar sites');
    
    // مراقبة إضافية للمواقع المعقدة
    if (window.location.hostname.includes('projectinfinity-x.com')) {
        console.log('SafarGet: Enhanced monitoring enabled for projectinfinity-x.com');
        
        // مراقبة جميع النقرات على الصفحة
        document.addEventListener('click', function(e) {
            const target = e.target;
            console.log('SafarGet: Click detected on:', target.tagName, target.textContent?.substring(0, 50));
        }, true);
    }
    
    // تشغيل دالة إجبار إضافة الزر بعد 20 ثانية
    setTimeout(() => {
        if (isYouTubePage() && !document.querySelector('#safarget-download-button')) {
            console.log('SafarGet: Force adding button after 20 seconds...');
            window.forceAddButton();
        }
    }, 20000);
})();

// 🔴 الحل الذكي: حقن Script مباشرة في الصفحة
(function injectInterceptor() {
    // إنشاء script element
    const script = document.createElement('script');
    script.textContent = `
    (function() {
        console.log('🚀 Download Interceptor Active');
        
        // ============================================
        // 1️⃣ تخزين المراجع الأصلية
        // ============================================
        const originalFetch = window.fetch;
        const originalXHROpen = XMLHttpRequest.prototype.open;
        const originalXHRSend = XMLHttpRequest.prototype.send;
        const originalCreateElement = document.createElement;
        const originalClick = HTMLAnchorElement.prototype.click;
        const originalSubmit = HTMLFormElement.prototype.submit;
        const originalOpen = window.open;
        
        // ============================================
        // 2️⃣ نظام كشف التحميلات
        // ============================================
        const DownloadDetector = {
            // قائمة الامتدادات
            extensions: [
                'zip', 'rar', '7z', 'tar', 'gz', 'bz2',
                'exe', 'msi', 'dmg', 'pkg', 'deb', 'rpm',
                'apk', 'ipa', 'xapk', 'aab',
                'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx',
                'mp3', 'mp4', 'avi', 'mkv', 'mov', 'wmv',
                'jpg', 'jpeg', 'png', 'gif', 'bmp', 'svg',
                'iso', 'img', 'bin', 'torrent'
            ],
            
            // كلمات مفتاحية
            keywords: [
                '/download', '/dl/', '/get/', '/fetch/',
                '/export', '/save', '/attachment',
                'download=', 'file=', 'export=', 'get=',
                '/files/', '/uploads/', '/media/'
            ],
            
            // فحص URL
            isDownloadUrl(url) {
                if (!url) return false;
                const lower = url.toLowerCase();
                
                // فحص الامتدادات
                for (const ext of this.extensions) {
                    if (lower.includes('.' + ext)) {
                        // تأكد أنه ليس جزء من مسار
                        const regex = new RegExp('\\\\.' + ext + '($|\\\\?|#)', 'i');
                        if (regex.test(url)) return true;
                    }
                }
                
                // فحص الكلمات المفتاحية
                for (const keyword of this.keywords) {
                    if (lower.includes(keyword)) return true;
                }
                
                return false;
            },
            
            // إرسال للإضافة
            notifyExtension(data) {
                window.postMessage({
                    type: 'DOWNLOAD_DETECTED',
                    data: data
                }, '*');
            }
        };
        
        // ============================================
        // 3️⃣ اعتراض الروابط
        // ============================================
        
        // اعتراض clicks
        document.addEventListener('click', function(e) {
            let element = e.target;
            
            // البحث عن أقرب رابط
            while (element && element !== document.body) {
                if (element.tagName === 'A' && element.href) {
                    // فحص التحميل
                    if (element.download || 
                        element.getAttribute('download') !== null ||
                        DownloadDetector.isDownloadUrl(element.href)) {
                        
                        e.preventDefault();
                        e.stopPropagation();
                        e.stopImmediatePropagation();
                        
                        DownloadDetector.notifyExtension({
                            action: 'link_click',
                            url: element.href,
                            filename: element.download || '',
                            text: element.textContent
                        });
                        
                        return false;
                    }
                }
                element = element.parentElement;
            }
        }, true); // استخدم capture phase
        
        // اعتراض الروابط المبرمجة
        HTMLAnchorElement.prototype.click = function() {
            if (this.download || DownloadDetector.isDownloadUrl(this.href)) {
                DownloadDetector.notifyExtension({
                    action: 'programmatic_click',
                    url: this.href,
                    filename: this.download || ''
                });
                return;
            }
            return originalClick.apply(this, arguments);
        };
        
        // ============================================
        // 4️⃣ اعتراض window.open
        // ============================================
        window.open = function(url, target, features) {
            if (DownloadDetector.isDownloadUrl(url)) {
                DownloadDetector.notifyExtension({
                    action: 'window_open',
                    url: url
                });
                return null;
            }
            return originalOpen.apply(this, arguments);
        };
        
        // ============================================
        // 5️⃣ اعتراض fetch
        // ============================================
        window.fetch = async function(...args) {
            const [resource, config] = args;
            const url = typeof resource === 'string' ? resource : resource.url;
            
            // تنفيذ الطلب
            const response = await originalFetch.apply(this, args);
            
            // فحص الاستجابة
            const contentDisposition = response.headers.get('content-disposition');
            const contentType = response.headers.get('content-type');
            
            if ((contentDisposition && contentDisposition.includes('attachment')) ||
                (contentType && contentType.includes('application/octet-stream')) ||
                DownloadDetector.isDownloadUrl(url)) {
                
                // استنساخ الاستجابة
                const clonedResponse = response.clone();
                
                // استخراج البيانات
                try {
                    const blob = await clonedResponse.blob();
                    const blobUrl = URL.createObjectURL(blob);
                    
                    DownloadDetector.notifyExtension({
                        action: 'fetch_download',
                        url: url,
                        blobUrl: blobUrl,
                        filename: extractFilename(contentDisposition),
                        size: blob.size,
                        type: blob.type
                    });
                } catch (e) {
                    console.error('Error processing fetch download:', e);
                }
            }
            
            return response;
        };
        
        // ============================================
        // 6️⃣ اعتراض XMLHttpRequest
        // ============================================
        XMLHttpRequest.prototype.open = function(method, url) {
            this._downloadUrl = url;
            this._downloadMethod = method;
            return originalXHROpen.apply(this, arguments);
        };
        
        XMLHttpRequest.prototype.send = function() {
            const xhr = this;
            
            // مراقب الاستجابة
            this.addEventListener('readystatechange', function() {
                if (xhr.readyState === 4 && xhr.status === 200) {
                    const contentDisposition = xhr.getResponseHeader('content-disposition');
                    const contentType = xhr.getResponseHeader('content-type');
                    
                    if ((contentDisposition && contentDisposition.includes('attachment')) ||
                        (contentType && contentType.includes('application/octet-stream')) ||
                        DownloadDetector.isDownloadUrl(xhr._downloadUrl)) {
                        
                        // إنشاء blob
                        const blob = new Blob([xhr.response]);
                        const blobUrl = URL.createObjectURL(blob);
                        
                        DownloadDetector.notifyExtension({
                            action: 'xhr_download',
                            url: xhr._downloadUrl,
                            blobUrl: blobUrl,
                            filename: extractFilename(contentDisposition),
                            method: xhr._downloadMethod
                        });
                    }
                }
            });
            
            return originalXHRSend.apply(this, arguments);
        };
        
        // ============================================
        // 7️⃣ اعتراض Forms
        // ============================================
        document.addEventListener('submit', function(e) {
            const form = e.target;
            
            if (form.action && DownloadDetector.isDownloadUrl(form.action)) {
                e.preventDefault();
                
                const formData = new FormData(form);
                const params = new URLSearchParams(formData).toString();
                
                DownloadDetector.notifyExtension({
                    action: 'form_submit',
                    url: form.action,
                    method: form.method || 'GET',
                    data: params
                });
            }
        }, true);
        
        HTMLFormElement.prototype.submit = function() {
            if (this.action && DownloadDetector.isDownloadUrl(this.action)) {
                const formData = new FormData(this);
                const params = new URLSearchParams(formData).toString();
                
                DownloadDetector.notifyExtension({
                    action: 'programmatic_form_submit',
                    url: this.action,
                    method: this.method || 'GET',
                    data: params
                });
                return;
            }
            return originalSubmit.apply(this, arguments);
        };
        
        // ============================================
        // 8️⃣ اعتراض createElement للروابط الديناميكية
        // ============================================
        document.createElement = function(tagName) {
            const element = originalCreateElement.call(document, tagName);
            
            if (tagName.toLowerCase() === 'a') {
                // مراقبة التغييرات
                Object.defineProperty(element, 'download', {
                    set: function(value) {
                        this._download = value;
                        if (value && this.href) {
                            // تحميل مبرمج سيحدث
                            setTimeout(() => {
                                DownloadDetector.notifyExtension({
                                    action: 'dynamic_link',
                                    url: this.href,
                                    filename: value
                                });
                            }, 0);
                        }
                    },
                    get: function() {
                        return this._download;
                    }
                });
            }
            
            return element;
        };
        
        // ============================================
        // 9️⃣ مراقب DOM للعناصر الجديدة
        // ============================================
        const observer = new MutationObserver(function(mutations) {
            mutations.forEach(function(mutation) {
                mutation.addedNodes.forEach(function(node) {
                    if (node.nodeType === 1) { // Element node
                        // فحص الروابط الجديدة
                        if (node.tagName === 'A' && node.download) {
                            node.addEventListener('click', function(e) {
                                e.preventDefault();
                                DownloadDetector.notifyExtension({
                                    action: 'dynamic_link_click',
                                    url: this.href,
                                    filename: this.download
                                });
                            });
                        }
                        
                        // فحص الروابط داخل العنصر
                        const links = node.querySelectorAll('a[download]');
                        links.forEach(link => {
                            link.addEventListener('click', function(e) {
                                e.preventDefault();
                                DownloadDetector.notifyExtension({
                                    action: 'nested_link_click',
                                    url: this.href,
                                    filename: this.download
                                });
                            });
                        });
                    }
                });
            });
        });
        
        observer.observe(document.documentElement, {
            childList: true,
            subtree: true
        });
        
        // ============================================
        // 🔟 دوال مساعدة
        // ============================================
        function extractFilename(contentDisposition) {
            if (!contentDisposition) return null;
            
            const patterns = [
                /filename\\*=UTF-8''([^;\\n]+)/,
                /filename="([^"]+)"/,
                /filename=([^;\\n]+)/
            ];
            
            for (const pattern of patterns) {
                const match = contentDisposition.match(pattern);
                if (match) {
                    return decodeURIComponent(match[1].trim());
                }
            }
            
            return null;
        }
        
        console.log('✅ Download Interceptor Initialized');
    })();
    `;
    
    // حقن في أول الصفحة
    (document.head || document.documentElement).appendChild(script);
    script.remove();
})();

// ============================================
// الاستماع للرسائل من الصفحة
// ============================================
window.addEventListener('message', function(event) {
    if (event.data && event.data.type === 'DOWNLOAD_DETECTED') {
        console.log('📥 Download detected:', event.data.data);
        
        // إرسال للـ Background Script
        browser.runtime.sendMessage({
            action: 'download_intercepted',
            data: event.data.data,
            pageUrl: window.location.href,
            timestamp: Date.now()
        });
    }
    
    // 🎯 NEW: معالج رسائل اعتراض نافذة Download Permission
    if (event.data && event.data.type === 'DOWNLOAD_PERMISSION_DETECTED') {
        console.log('🎯 Download permission dialog detected:', event.data.data);
        
        // إرسال للـ Background Script
        browser.runtime.sendMessage({
            action: 'download_permission_detected',
            data: event.data.data,
            pageUrl: window.location.href,
            timestamp: Date.now(),
            source: 'permission_dialog'
        });
    }
    
    // 🧪 معالج الرسائل التجريبية
    if (event.data && event.data.type === 'TEST_MESSAGE') {
        console.log('🧪 Test message received:', event.data.data);
    }
});

// ============================================
// مراقب إضافي للـ Navigation
// ============================================
let lastUrl = location.href;
new MutationObserver(() => {
    const url = location.href;
    if (url !== lastUrl) {
        lastUrl = url;
        
        // فحص URL الجديد
        if (url.match(/\.(zip|exe|dmg|apk|pdf|doc|xls|ppt|mp3|mp4|avi|mkv)$/i) ||
            url.includes('/download') ||
            url.includes('download=')) {
            
            browser.runtime.sendMessage({
                action: 'url_changed_to_download',
                url: url
            });
        }
    }
}).observe(document, { subtree: true, childList: true });
