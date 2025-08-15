// =================================================
// 🎯 اعتراض نافذة Download Permission - Chrome Extension
// =================================================
// هذا الحل يستغل نافذة "Download Permission" في Chrome
// عندما يظهر dialog الإذن، JavaScript يكتشفه ويعترض التحميل
// =================================================

(function() {
    'use strict';
    
    console.log('🎯 Download Permission Interceptor Active (Chrome)');
    
    // =================================================
    // 1️⃣ متتبع التحميلات المعلقة
    // =================================================
    
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
        
        get(url) {
            return this.downloads.get(url);
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
    
    // =================================================
    // 2️⃣ اعتراض أحداث التحميل
    // =================================================
    
    // اعتراض beforeunload (يُستخدم للتحميلات)
    window.addEventListener('beforeunload', function(event) {
        console.log('🔍 beforeunload detected - possible download');
        
        // فحص إذا كان هناك تحميل معلق
        const activeElement = document.activeElement;
        if (activeElement && activeElement.href) {
            PendingDownloads.add(activeElement.href, {
                url: activeElement.href,
                source: 'beforeunload',
                element: activeElement.outerHTML
            });
        }
    }, true);
    
    // =================================================
    // 3️⃣ مراقب الـ Permission API
    // =================================================
    
    if ('permissions' in navigator) {
        // اعتراض query
        const originalQuery = navigator.permissions.query;
        navigator.permissions.query = async function(descriptor) {
            console.log('🔍 Permission query:', descriptor);
            
            // فحص إذا كان متعلق بالتحميل
            if (descriptor.name === 'downloads' || 
                descriptor.name === 'storage' ||
                descriptor.name === 'persistent-storage') {
                
                // تسجيل محاولة التحميل
                PendingDownloads.add('permission-query', {
                    type: 'permission',
                    descriptor: descriptor
                });
            }
            
            return originalQuery.call(this, descriptor);
        };
    }
    
    // =================================================
    // 4️⃣ اعتراض الـ Navigation للتحميلات
    // =================================================
    
    // مراقب التغييرات في document.readyState
    let lastReadyState = document.readyState;
    Object.defineProperty(document, 'readyState', {
        get: function() {
            return lastReadyState;
        },
        set: function(value) {
            console.log('🔍 Document readyState change:', value);
            
            // عندما يتغير لـ 'interactive' قد يكون تحميل
            if (value === 'interactive' && lastReadyState === 'loading') {
                // فحص الروابط النشطة
                checkForPendingDownloads();
            }
            
            lastReadyState = value;
        }
    });
    
    // =================================================
    // 5️⃣ اعتراض أحداث Chrome الخاصة
    // =================================================
    
    // Chrome يطلق أحداث خاصة عند التحميل
    document.addEventListener('visibilitychange', function() {
        console.log('🔍 Visibility change - checking for downloads');
        checkForPendingDownloads();
    });
    
    document.addEventListener('pagehide', function(event) {
        console.log('🔍 Page hide event - possible download');
        checkForPendingDownloads();
    });
    
    // =================================================
    // 6️⃣ مراقب الـ MutationObserver للنوافذ المنبثقة
    // =================================================
    
    const observer = new MutationObserver(function(mutations) {
        mutations.forEach(function(mutation) {
            // البحث عن عناصر dialog أو popup
            mutation.addedNodes.forEach(function(node) {
                if (node.nodeType === 1) {
                    // فحص إذا كان dialog أو overlay
                    const isDialog = 
                        node.tagName === 'DIALOG' ||
                        node.role === 'dialog' ||
                        node.className?.includes('modal') ||
                        node.className?.includes('popup') ||
                        node.className?.includes('overlay');
                    
                    if (isDialog) {
                        console.log('🔍 Dialog detected - might be download permission');
                        
                        // فحص المحتوى
                        const text = node.textContent?.toLowerCase() || '';
                        if (text.includes('download') || 
                            text.includes('allow') ||
                            text.includes('permission')) {
                            
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
    
    // =================================================
    // 7️⃣ اعتراض XMLHttpRequest و Fetch للتحميلات
    // =================================================
    
    // اعتراض XHR
    const originalXHROpen = XMLHttpRequest.prototype.open;
    XMLHttpRequest.prototype.open = function(method, url) {
        this._downloadURL = url;
        
        // فحص إذا كان تحميل
        if (isDownloadURL(url)) {
            console.log('🔍 XHR download detected:', url);
            PendingDownloads.add(url, {
                url: url,
                method: method,
                source: 'xhr'
            });
        }
        
        return originalXHROpen.apply(this, arguments);
    };
    
    // اعتراض Fetch
    const originalFetch = window.fetch;
    window.fetch = async function(...args) {
        const [resource] = args;
        const url = typeof resource === 'string' ? resource : resource.url;
        
        if (isDownloadURL(url)) {
            console.log('🔍 Fetch download detected:', url);
            PendingDownloads.add(url, {
                url: url,
                source: 'fetch'
            });
        }
        
        const response = await originalFetch.apply(this, args);
        
        // فحص response headers
        const contentDisposition = response.headers.get('content-disposition');
        if (contentDisposition?.includes('attachment')) {
            console.log('✅ Download response detected:', response.url);
            PendingDownloads.add(response.url, {
                url: response.url,
                filename: extractFilename(contentDisposition),
                source: 'fetch-response'
            });
        }
        
        return response;
    };
    
    // =================================================
    // 8️⃣ Chrome-specific: اعتراض download attribute
    // =================================================
    
    // عندما يضغط المستخدم على رابط بـ download attribute
    document.addEventListener('click', function(e) {
        let element = e.target;
        
        while (element && element !== document.body) {
            if (element.tagName === 'A') {
                // فحص download attribute
                if (element.hasAttribute('download') || element.download) {
                    console.log('🎯 Download link clicked:', element.href);
                    
                    // في Chrome، هذا سيؤدي لظهور نافذة الإذن
                    // نسجل المعلومات قبل ظهورها
                    PendingDownloads.add(element.href, {
                        url: element.href,
                        filename: element.download || extractFilenameFromURL(element.href),
                        source: 'download-link',
                        element: element.outerHTML
                    });
                    
                    // نحاول الاعتراض بعد 100ms
                    setTimeout(() => {
                        checkForDownloadPermission(element.href);
                    }, 100);
                }
            }
            element = element.parentElement;
        }
    }, true);
    
    // =================================================
    // 9️⃣ الدوال المساعدة
    // =================================================
    
    function isDownloadURL(url) {
        if (!url) return false;
        const lower = url.toLowerCase();
        
        const extensions = [
            '.zip', '.rar', '.7z', '.tar', '.gz',
            '.exe', '.dmg', '.pkg', '.apk',
            '.pdf', '.doc', '.xls', '.ppt',
            '.mp3', '.mp4', '.avi', '.mkv'
        ];
        
        return extensions.some(ext => lower.includes(ext));
    }
    
    function extractFilename(contentDisposition) {
        const match = contentDisposition.match(/filename[^;=\n]*=([^;\n]*)/);
        return match ? match[1].replace(/['"]/g, '') : null;
    }
    
    function extractFilenameFromURL(url) {
        try {
            const urlObj = new URL(url);
            const path = urlObj.pathname;
            return path.substring(path.lastIndexOf('/') + 1) || 'download';
        } catch {
            return 'download';
        }
    }
    
    function checkForPendingDownloads() {
        // فحص كل التحميلات المعلقة
        PendingDownloads.downloads.forEach((info, url) => {
            if (!info.intercepted) {
                console.log('🔄 Checking pending download:', url);
                checkForDownloadPermission(url);
            }
        });
    }
    
    function checkForDownloadPermission(url) {
        // البحث عن نافذة الإذن في الصفحة
        const possibleSelectors = [
            '[role="dialog"]',
            '.permission-dialog',
            '.download-permission',
            'dialog',
            '[class*="modal"]',
            '[class*="popup"]',
            '[class*="alert"]'
        ];
        
        for (const selector of possibleSelectors) {
            const elements = document.querySelectorAll(selector);
            elements.forEach(el => {
                const text = el.textContent?.toLowerCase() || '';
                if (text.includes('download') && text.includes('allow')) {
                    console.log('✅ Found download permission dialog!');
                    interceptDownloadDialog(el);
                }
            });
        }
    }
    
    function interceptDownloadDialog(dialogElement) {
        console.log('🎯 Intercepting download dialog');
        
        // استخراج معلومات التحميل من الـ dialog
        const urlMatch = dialogElement.textContent?.match(/https?:\/\/[^\s"']+/);
        const url = urlMatch ? urlMatch[0] : null;
        
        if (url) {
            // اعتراض التحميل
            PendingDownloads.intercept(url);
        }
        
        // البحث عن أزرار Allow/Deny
        const buttons = dialogElement.querySelectorAll('button');
        buttons.forEach(button => {
            const text = button.textContent?.toLowerCase() || '';
            
            if (text.includes('allow') || text.includes('download')) {
                // اعتراض زر Allow
                const originalClick = button.onclick;
                button.onclick = function(e) {
                    console.log('✅ Allow button clicked - intercepting download');
                    
                    // اعتراض التحميل
                    checkForPendingDownloads();
                    
                    // استدعاء الوظيفة الأصلية
                    if (originalClick) {
                        return originalClick.call(this, e);
                    }
                };
            }
        });
    }
    
    console.log('✅ Download Permission Interceptor Ready (Chrome)');
})();

// =================================================
// الاستماع للرسائل وإرسالها للـ Extension
// =================================================

window.addEventListener('message', function(event) {
    if (event.data && event.data.type === 'DOWNLOAD_PERMISSION_DETECTED') {
        console.log('📥 Download permission detected:', event.data.data);
        
        // إرسال للـ Background Script
        chrome.runtime.sendMessage({
            action: 'download_permission_detected',
            data: event.data.data
        });
    }
});
