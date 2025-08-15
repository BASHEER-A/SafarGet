// Advanced Download Interceptor - SafarGet
(function() {
    'use strict';
    
    console.log('🚀 SafarGet: Advanced Download Interceptor Loading...');
    
    // حفظ المراجع الأصلية
    const _originalOpen = window.open;
    const _originalLocationHref = Object.getOwnPropertyDescriptor(window.location, 'href');
    
    const InterceptorSystem = {
        downloadExtensions: ['zip', 'rar', '7z', 'exe', 'msi', 'dmg', 'pdf', 'mp4', 'mp3'],
        downloadKeywords: ['/download', '/dl/', '/get/', 'download=', 'file='],
        
        isDownloadURL(url) {
            if (!url) return false;
            const lower = url.toLowerCase();
            
            for (const ext of this.downloadExtensions) {
                if (lower.includes('.' + ext)) {
                    console.log('🎯 SafarGet: Download detected by extension:', ext, url);
                    return true;
                }
            }
            
            for (const keyword of this.downloadKeywords) {
                if (lower.includes(keyword)) {
                    console.log('🎯 SafarGet: Download detected by keyword:', keyword, url);
                    return true;
                }
            }
            
            return false;
        },
        
        interceptDownload(info) {
            console.log('🚫 SafarGet: Intercepting download:', info);
            
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.popupDownloadDetected) {
                window.webkit.messageHandlers.popupDownloadDetected.postMessage({
                    type: 'DOWNLOAD_INTERCEPTED',
                    data: {
                        url: info.url,
                        filename: info.filename || '',
                        source: info.source || 'unknown',
                        timestamp: Date.now()
                    }
                });
            }
            
            return false;
        }
    };
    
    // اعتراض window.open
    window.open = function(url, target, features) {
        console.log('🔍 SafarGet: window.open called:', url);
        
        if (url && InterceptorSystem.isDownloadURL(url)) {
            InterceptorSystem.interceptDownload({
                url: url,
                source: 'window.open'
            });
            return null;
        }
        
        return _originalOpen.apply(this, arguments);
    };
    
    // اعتراض location.href
    Object.defineProperty(window.location, 'href', {
        get: function() {
            return _originalLocationHref.get.call(this);
        },
        set: function(url) {
            console.log('🔍 SafarGet: location.href set:', url);
            
            if (InterceptorSystem.isDownloadURL(url)) {
                InterceptorSystem.interceptDownload({
                    url: url,
                    source: 'location.href'
                });
                return;
            }
            
            return _originalLocationHref.set.call(this, url);
        }
    });
    
    // اعتراض النقرات
    document.addEventListener('click', function(e) {
        let element = e.target;
        
        while (element && element !== document.body) {
            if (element.tagName === 'A' && element.href) {
                if (element.download !== undefined ||
                    element.hasAttribute('download') ||
                    element.target === '_blank' ||
                    InterceptorSystem.isDownloadURL(element.href)) {
                    
                    e.preventDefault();
                    e.stopPropagation();
                    
                    InterceptorSystem.interceptDownload({
                        url: element.href,
                        filename: element.download || element.getAttribute('download') || '',
                        source: 'link_click'
                    });
                    
                    return false;
                }
            }
            
            element = element.parentElement;
        }
    }, true);
    
    console.log('✅ SafarGet: Advanced Download Interceptor System Active');
})();
