// Universal Download Interceptor - JavaScript
// SafarGet Comprehensive Download Detection System
// Covers all download scenarios: direct links, JavaScript redirects, XHR/Fetch, POST→GET, masked links, Service Workers, Blob URLs, Data URLs, Meta Refresh

(function() {
    'use strict';
    
    console.log('🚀 SafarGet: Universal Download Interceptor loaded');
    
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
    const originalLocationHref = Object.getOwnPropertyDescriptor(window.location, 'href');
    const originalCreateObjectURL = URL.createObjectURL;
    const originalSetAttribute = Element.prototype.setAttribute;
    const originalSetAttributeNS = Element.prototype.setAttributeNS;
    
    // ============================================
    // 2️⃣ نظام كشف التحميلات الشامل
    // ============================================
    const UniversalDownloadDetector = {
        // قائمة الامتدادات
        extensions: [
            'zip', 'rar', '7z', 'tar', 'gz', 'bz2', 'xz', 'lzma',
            'exe', 'msi', 'dmg', 'pkg', 'deb', 'rpm', 'jar', 'war', 'apk', 'ipa',
            'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'csv', 'rtf',
            'mp4', 'avi', 'mkv', 'mov', 'wmv', 'flv', 'webm', 'm4v', '3gp',
            'mp3', 'wav', 'flac', 'aac', 'ogg', 'm4a', 'wma',
            'jpg', 'jpeg', 'png', 'gif', 'bmp', 'tiff', 'svg', 'webp',
            'iso', 'img', 'bin', 'torrent', 'ipsw'
        ],
        
        // كلمات مفتاحية
        keywords: [
            '/download', '/dl/', '/get/', '/fetch/', '/export', '/save', '/attachment',
            'download=', 'file=', 'export=', 'get=', '/files/', '/uploads/', '/media/'
        ],
        
        // فحص URL شامل
        isDownloadUrl(url) {
            if (!url) return false;
            const lower = url.toLowerCase();
            
            // فحص الامتدادات
            for (const ext of this.extensions) {
                if (lower.includes('.' + ext)) {
                    const regex = new RegExp('\\.' + ext + '(?:[?#]|$)', 'i');
                    if (regex.test(url)) {
                        return true;
                    }
                }
            }
            
            // فحص الكلمات المفتاحية
            for (const keyword of this.keywords) {
                if (lower.includes(keyword)) {
                    return true;
                }
            }
            
            return false;
        },
        
        // فحص Content-Type
        isDownloadableContentType(contentType) {
            if (!contentType) return false;
            const lower = contentType.toLowerCase();
            
            const downloadableTypes = [
                'application/zip', 'application/x-zip', 'application/x-zip-compressed',
                'application/x-rar-compressed', 'application/x-7z-compressed',
                'application/x-tar', 'application/x-gzip', 'application/x-bzip2',
                'application/pdf', 'application/octet-stream',
                'application/vnd.android.package-archive', 'application/x-apple-diskimage',
                'application/x-debian-package', 'application/x-redhat-package-manager',
                'application/x-msdownload', 'application/x-executable',
                'video/', 'audio/', 'image/'
            ];
            
            // تنظيف نوع المحتوى من الأخطاء الشائعة
            const cleanContentType = lower
                .replace(/text\/htm\//, 'text/html/') // إصلاح text/htm/ إلى text/html/
                .replace(/charset=utf-8\s*$/, '') // إزالة charset=utf-8 في النهاية
                .replace(/\s+/g, ' ') // تنظيف المسافات الزائدة
                .trim();
            
            return downloadableTypes.some(type => cleanContentType.includes(type));
        },
        
        // إرسال إلى Native
        sendToNative(type, data) {
            console.log('🔗 SafarGet: Sending to native:', type, data);
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.universalDownloadDetected) {
                window.webkit.messageHandlers.universalDownloadDetected.postMessage({
                    type: type,
                    data: data,
                    timestamp: Date.now(),
                    source: window.location.href
                });
            }
        }
    };
    
    // ============================================
    // 3️⃣ اعتراض النقرات على الروابط
    // ============================================
    document.addEventListener('click', function(e) {
        const target = e.target.closest('a, button, [onclick], [role="button"]');
        if (!target) return;
        
        let url = target.href || target.getAttribute('data-url') || target.getAttribute('data-href');
        
        // فحص onclick للروابط الديناميكية
        if (!url && target.onclick) {
            const onclickStr = target.onclick.toString();
            const urlMatch = onclickStr.match(/(?:window\.open|location\.href|window\.location)\s*=\s*['"`]([^'"`]+)['"`]/);
            if (urlMatch) {
                url = urlMatch[1];
            }
        }
        
        if (url && UniversalDownloadDetector.isDownloadUrl(url)) {
            console.log('🔗 SafarGet: Intercepted link click:', url);
            e.preventDefault();
            e.stopPropagation();
            e.stopImmediatePropagation();
            
            UniversalDownloadDetector.sendToNative('link_click', {
                url: url,
                filename: target.download || target.textContent?.trim() || '',
                element: target.tagName,
                method: 'GET'
            });
            return false;
        }
    }, true);
    
    // ============================================
    // 4️⃣ اعتراض window.open
    // ============================================
    window.open = function(url, ...args) {
        if (url && UniversalDownloadDetector.isDownloadUrl(url)) {
            console.log('🪟 SafarGet: Intercepted window.open:', url);
            UniversalDownloadDetector.sendToNative('window_open', {
                url: url,
                method: 'GET'
            });
            return { close: () => {}, focus: () => {} };
        }
        return originalOpen.apply(this, arguments);
    };
    
    // ============================================
    // 5️⃣ اعتراض location.href
    // ============================================
    Object.defineProperty(window.location, 'href', {
        get: function() {
            return originalLocationHref.get.call(this);
        },
        set: function(value) {
            if (value && UniversalDownloadDetector.isDownloadUrl(value)) {
                console.log('📍 SafarGet: Intercepted location.href:', value);
                UniversalDownloadDetector.sendToNative('location_href', {
                    url: value,
                    method: 'GET'
                });
                return;
            }
            return originalLocationHref.set.call(this, value);
        }
    });
    
    // ============================================
    // 6️⃣ اعتراض Fetch API
    // ============================================
    window.fetch = function(url, options = {}) {
        const urlString = typeof url === 'string' ? url : url.toString();
        
        if (UniversalDownloadDetector.isDownloadUrl(urlString)) {
            console.log('🌐 SafarGet: Intercepted fetch:', urlString);
            UniversalDownloadDetector.sendToNative('fetch', {
                url: urlString,
                method: options.method || 'GET',
                headers: options.headers || {}
            });
        }
        
        return originalFetch.apply(this, arguments);
    };
    
    // ============================================
    // 7️⃣ اعتراض XMLHttpRequest
    // ============================================
    XMLHttpRequest.prototype.open = function(method, url, ...args) {
        if (UniversalDownloadDetector.isDownloadUrl(url)) {
            console.log('📡 SafarGet: Intercepted XHR:', url);
            UniversalDownloadDetector.sendToNative('xhr', {
                url: url,
                method: method
            });
        }
        return originalXHROpen.apply(this, arguments);
    };
    
    // ============================================
    // 8️⃣ اعتراض Form Submissions
    // ============================================
    HTMLFormElement.prototype.submit = function() {
        const form = this;
        const action = form.action;
        const method = form.method || 'GET';
        
        if (UniversalDownloadDetector.isDownloadUrl(action)) {
            console.log('📝 SafarGet: Intercepted form submission:', action);
            UniversalDownloadDetector.sendToNative('form_submit', {
                url: action,
                method: method,
                formData: new FormData(form)
            });
        }
        
        return originalSubmit.apply(this, arguments);
    };
    
    // ============================================
    // 9️⃣ اعتراض Blob URLs
    // ============================================
    URL.createObjectURL = function(blob) {
        const blobUrl = originalCreateObjectURL.call(this, blob);
        
        // مراقبة استخدام Blob URL
        setTimeout(() => {
            if (document.querySelector(`a[href="${blobUrl}"]`) || 
                document.querySelector(`img[src="${blobUrl}"]`) ||
                document.querySelector(`video[src="${blobUrl}"]`) ||
                document.querySelector(`audio[src="${blobUrl}"]`)) {
                
                console.log('💾 SafarGet: Blob URL detected:', blobUrl);
                UniversalDownloadDetector.sendToNative('blob_url', {
                    blobUrl: blobUrl,
                    blobType: blob.type,
                    blobSize: blob.size
                });
            }
        }, 100);
        
        return blobUrl;
    };
    
    // ============================================
    // 🔟 اعتراض Service Workers
    // ============================================
    if ('serviceWorker' in navigator) {
        navigator.serviceWorker.addEventListener('message', function(event) {
            if (event.data && event.data.type === 'download') {
                console.log('🔧 SafarGet: Service Worker download detected:', event.data);
                UniversalDownloadDetector.sendToNative('service_worker', event.data);
            }
        });
    }
    
    // ============================================
    // 1️⃣1️⃣ اعتراض Meta Refresh
    // ============================================
    Element.prototype.setAttribute = function(name, value) {
        if (name === 'http-equiv' && value === 'refresh') {
            const content = this.getAttribute('content');
            if (content) {
                const urlMatch = content.match(/\d+;\s*url=([^\s]+)/i);
                if (urlMatch && UniversalDownloadDetector.isDownloadUrl(urlMatch[1])) {
                    console.log('🔄 SafarGet: Meta refresh detected:', urlMatch[1]);
                    UniversalDownloadDetector.sendToNative('meta_refresh', {
                        url: urlMatch[1],
                        content: content
                    });
                }
            }
        }
        return originalSetAttribute.call(this, name, value);
    };
    
    // ============================================
    // 1️⃣2️⃣ مراقبة Data URLs
    // ============================================
    Element.prototype.setAttributeNS = function(namespace, name, value) {
        if (name === 'href' && value && value.startsWith('data:')) {
            const dataUrlMatch = value.match(/^data:([^;]+);base64,/);
            if (dataUrlMatch && UniversalDownloadDetector.isDownloadableContentType(dataUrlMatch[1])) {
                console.log('📄 SafarGet: Data URL detected:', dataUrlMatch[1]);
                UniversalDownloadDetector.sendToNative('data_url', {
                    dataUrl: value,
                    mimeType: dataUrlMatch[1]
                });
            }
        }
        return originalSetAttributeNS.call(this, namespace, name, value);
    };
    
    // ============================================
    // 1️⃣3️⃣ مراقبة MutationObserver للتغييرات الديناميكية
    // ============================================
    const observer = new MutationObserver(function(mutations) {
        mutations.forEach(function(mutation) {
            mutation.addedNodes.forEach(function(node) {
                if (node.nodeType === Node.ELEMENT_NODE) {
                    // فحص الروابط الجديدة
                    const links = node.querySelectorAll ? node.querySelectorAll('a') : [];
                    links.forEach(function(link) {
                        if (link.href && UniversalDownloadDetector.isDownloadUrl(link.href)) {
                            console.log('🔗 SafarGet: Dynamic link detected:', link.href);
                            UniversalDownloadDetector.sendToNative('dynamic_link', {
                                url: link.href,
                                element: link.tagName
                            });
                        }
                    });
                }
            });
        });
    });
    
    observer.observe(document.body, {
        childList: true,
        subtree: true
    });
    
    // ============================================
    // 1️⃣4️⃣ مراقبة beforeunload للتحميلات المباشرة
    // ============================================
    window.addEventListener('beforeunload', function(e) {
        if (UniversalDownloadDetector.isDownloadUrl(window.location.href)) {
            console.log('🚪 SafarGet: Page unload with download URL detected:', window.location.href);
            UniversalDownloadDetector.sendToNative('page_unload', {
                url: window.location.href
            });
        }
    });
    
    console.log('✅ SafarGet: Universal Download Interceptor fully loaded');
})();
