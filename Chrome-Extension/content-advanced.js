// SafarGet Advanced Content Script
// Enhanced with dual-strategy download detection

console.log('🚀 SafarGet Advanced Content Script Loading...');

// تتبع الإعدادات
let interceptDownloads = true;

// التحقق من الإعدادات
chrome.storage.sync.get(['interceptDownloads'], (result) => {
    interceptDownloads = result.interceptDownloads !== false;
    console.log('📋 Interception enabled:', interceptDownloads);
});

// مراقبة تغييرات الإعدادات
chrome.storage.onChanged.addListener((changes) => {
    if (changes.interceptDownloads) {
        interceptDownloads = changes.interceptDownloads.newValue;
        console.log('📋 Interception setting changed:', interceptDownloads);
    }
});

// إرسال معلومات الصفحة للـ background script
function sendPageInfo() {
    if (interceptDownloads) {
        chrome.runtime.sendMessage({
            type: 'page_loaded',
            url: window.location.href,
            title: document.title
        });
    }
}

// إرسال معلومات الصفحة عند التحميل
sendPageInfo();

// مراقبة تغييرات الصفحة
let lastUrl = window.location.href;
const observer = new MutationObserver(() => {
    if (window.location.href !== lastUrl) {
        lastUrl = window.location.href;
        sendPageInfo();
    }
});

observer.observe(document.body, {
        childList: true,
        subtree: true
    });
    
// مراقبة تغييرات الـ URL في Single Page Applications
window.addEventListener('popstate', sendPageInfo);

// مراقبة إضافية للتطبيقات الحديثة
(function() {
    const originalPushState = history.pushState;
    const originalReplaceState = history.replaceState;
    
    history.pushState = function() {
        originalPushState.apply(history, arguments);
        setTimeout(sendPageInfo, 100);
    };
    
    history.replaceState = function() {
        originalReplaceState.apply(history, arguments);
        setTimeout(sendPageInfo, 100);
    };
})();

console.log('✅ Working with dual-strategy system');

// =================================================
// 🎥 SafarGet YouTube Downloader - Complete Implementation
// =================================================

(function() {
    'use strict';
    
    console.log('🎥 SafarGet YouTube Downloader Module Loading...');
    
    // التحقق من أننا على YouTube
    function isYouTube() {
        return window.location.hostname.includes('youtube.com') || 
               window.location.hostname.includes('youtu.be');
    }
    
    if (!isYouTube()) {
        console.log('❌ Not on YouTube, module disabled');
        return;
    }
    
    // تعطيل هذا المودول مؤقتاً - سيتم استخدام youtube-detector.js بدلاً منه
    console.log('🚫 YouTube module disabled - using youtube-detector.js instead');
    return;
    
    console.log('✅ YouTube detected, initializing downloader...');
    
    // =================================================
    // الإعدادات والمتغيرات العامة
    // =================================================
    
    let currentVideoInfo = null;
    let downloadButton = null;
    let qualityMenu = null;
    let isProcessing = false;
    let ytPlayer = null;
    let lastVideoId = null;
    
    // =================================================
    // استخراج معلومات الفيديو
    // =================================================
    
    // استخراج Video ID من URL
    function getVideoId() {
        const urlParams = new URLSearchParams(window.location.search);
        const videoId = urlParams.get('v');
        
        if (videoId) return videoId;
        
        // محاولة استخراج من URL قصير
        const match = window.location.pathname.match(/\/watch\/([a-zA-Z0-9_-]+)/);
        return match ? match[1] : null;
    }
    
    // استخراج معلومات الفيديو من الصفحة
    function getVideoInfo() {
        try {
            // محاولة استخراج من ytInitialData
            let videoInfo = null;
            
            // محاولة 1: من ytInitialData
            if (window.ytInitialData) {
                const contents = window.ytInitialData.contents;
                if (contents && contents.twoColumnWatchNextResults) {
                    const results = contents.twoColumnWatchNextResults.results;
                    if (results && results.results) {
                        const primary = results.results.contents[0];
                        if (primary && primary.videoPrimaryInfoRenderer) {
                            const title = primary.videoPrimaryInfoRenderer.title;
                            videoInfo = {
                                title: title.runs ? title.runs[0].text : title.simpleText || 'Unknown'
                            };
                        }
                    }
                }
            }
            
            // محاولة 2: من العناصر DOM
            if (!videoInfo) {
                const titleElement = document.querySelector('h1[class*="title"], .watch-main-col h1, #eow-title, h1.ytd-video-primary-info-renderer');
                if (titleElement) {
                    videoInfo = {
                        title: titleElement.textContent.trim() || 'Unknown'
                    };
                }
            }
            
            // محاولة 3: من meta tags
            if (!videoInfo) {
                const metaTitle = document.querySelector('meta[property="og:title"]');
                if (metaTitle) {
                    videoInfo = {
                        title: metaTitle.content || 'Unknown'
                    };
                }
            }
            
            // إضافة معلومات أساسية
            if (videoInfo) {
                videoInfo.videoId = getVideoId();
                videoInfo.url = window.location.href;
                
                // إضافة معلومات القناة
                const channelElement = document.querySelector('a[class*="channel"], .yt-user-info a, #owner-name a, .ytd-channel-name a');
                if (channelElement) {
                    videoInfo.channel = channelElement.textContent.trim();
                }
                
                // إضافة المدة
                const durationElement = document.querySelector('.ytp-time-duration, .video-stream .length, .ytd-thumbnail-overlay-time-status-renderer');
                if (durationElement) {
                    videoInfo.duration = durationElement.textContent.trim();
                }
                
                console.log('📺 Video info extracted:', videoInfo);
                return videoInfo;
            }
            
        } catch (error) {
            console.error('❌ Error extracting video info:', error);
        }
        
        return null;
    }
    
    // =================================================
    // استخراج روابط التحميل
    // =================================================
    
    // استخراج روابط التحميل المختلفة
    async function getDownloadLinks() {
        try {
            console.log('🔍 Extracting download links...');
            
            const videoId = getVideoId();
            if (!videoId) {
                throw new Error('No video ID found');
            }
            
            // طرق مختلفة لاستخراج الروابط
            let links = await tryMultipleMethods(videoId);
            
            if (!links || links.length === 0) {
                console.log('⚠️ No direct links found, using fallback method');
                links = await getFallbackLinks(videoId);
            }
            
            return links || [];
            
        } catch (error) {
            console.error('❌ Error getting download links:', error);
            return [];
        }
    }
    
    // محاولة طرق متعددة لاستخراج الروابط
    async function tryMultipleMethods(videoId) {
        const methods = [
            () => extractFromPlayerResponse(videoId),
            () => extractFromNetworkRequests(videoId),
            () => extractFromVideoElement(videoId)
        ];
        
        for (const method of methods) {
            try {
                const result = await method();
                if (result && result.length > 0) {
                    console.log('✅ Links extracted successfully');
                    return result;
                }
            } catch (error) {
                console.log('⚠️ Method failed, trying next...');
            }
        }
        
        return null;
    }
    
    // استخراج من Player Response
    async function extractFromPlayerResponse(videoId) {
        try {
            // البحث عن ytInitialPlayerResponse
            if (window.ytInitialPlayerResponse) {
                const player = window.ytInitialPlayerResponse;
                return parsePlayerResponse(player);
            }
            
            // محاولة الحصول من player config
            if (window.ytplayer && window.ytplayer.config) {
                const args = window.ytplayer.config.args;
                if (args.player_response) {
                    const playerResponse = JSON.parse(args.player_response);
                    return parsePlayerResponse(playerResponse);
                }
            }
            
        } catch (error) {
            console.error('❌ Error extracting from player response:', error);
        }
        
        return null;
    }
    
    // تحليل Player Response
    function parsePlayerResponse(playerResponse) {
        const links = [];
        
        try {
            // استخراج من streamingData
            if (playerResponse.streamingData) {
                const streamingData = playerResponse.streamingData;
                
                // الفيديوهات التكيفية
                if (streamingData.adaptiveFormats) {
                    streamingData.adaptiveFormats.forEach(format => {
                        if (format.url && format.itag) {
                            links.push({
                                quality: getQualityLabel(format),
            url: format.url,
                                itag: format.itag,
                                type: format.mimeType,
                                hasAudio: format.audioChannels > 0,
                                hasVideo: format.width > 0
                            });
            }
        });
    }
    
                // الفيديوهات العادية
                if (streamingData.formats) {
                    streamingData.formats.forEach(format => {
                        if (format.url && format.itag) {
                            links.push({
                                quality: getQualityLabel(format),
                                url: format.url,
                                itag: format.itag,
                                type: format.mimeType,
                                hasAudio: true,
                                hasVideo: true
                            });
                        }
                    });
                }
            }
            
        } catch (error) {
            console.error('❌ Error parsing player response:', error);
        }
        
        return links;
    }
    
    // الحصول على تسمية الجودة
    function getQualityLabel(format) {
        if (format.qualityLabel) {
            return format.qualityLabel;
        }
        
        if (format.height) {
            return `${format.height}p`;
        }
        
        if (format.quality) {
            return format.quality;
        }
        
        return 'Unknown';
    }
    
    // استخراج من طلبات الشبكة
    async function extractFromNetworkRequests(videoId) {
        // هذا يتطلب تتبع طلبات الشبكة
        // يمكن تنفيذه لاحقاً إذا لزم الأمر
            return null;
        }
        
    // استخراج من عنصر الفيديو
    async function extractFromVideoElement(videoId) {
        try {
            const videoElement = document.querySelector('video');
            if (videoElement && videoElement.src) {
                return [{
                    quality: 'Current',
                    url: videoElement.src,
                    type: 'video/mp4',
                    hasAudio: true,
                    hasVideo: true
                }];
            }
        } catch (error) {
            console.error('❌ Error extracting from video element:', error);
        }
        
        return null;
    }
    
    // روابط احتياطية
    async function getFallbackLinks(videoId) {
        // إنشاء رابط يستخدم yt-dlp في SafarGet
        return [{
            quality: 'Best Available',
            url: `https://www.youtube.com/watch?v=${videoId}`,
            type: 'youtube/video',
            hasAudio: true,
            hasVideo: true,
            requiresProcessing: true
        }];
    }
    
    // =================================================
    // واجهة المستخدم
    // =================================================
    
    // إنشاء الأيقونة العائمة
    function createFloatingIcon() {
        const floatingIcon = document.createElement('div');
        floatingIcon.id = 'safarget-floating-icon';
        floatingIcon.className = 'safarget-floating-icon';
        floatingIcon.innerHTML = `
            <div class="safarget-icon-content">
                <svg width="24" height="24" viewBox="0 0 24 24" fill="currentColor">
                    <path d="M19 9h-4V3H9v6H5l7 7 7-7zM5 18v2h14v-2H5z"/>
                </svg>
                <span class="safarget-tooltip">تحميل فيديو YouTube</span>
            </div>
        `;
        
        // إضافة حدث النقر
        floatingIcon.addEventListener('click', handleDownloadClick);
        
        return floatingIcon;
    }

    // إنشاء زر التحميل العادي (احتياطي)
    function createDownloadButton() {
        const button = document.createElement('button');
        button.id = 'safarget-youtube-download';
        button.className = 'safarget-download-btn';
        button.innerHTML = `
            <svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor">
                <path d="M19 9h-4V3H9v6H5l7 7 7-7zM5 18v2h14v-2H5z"/>
            </svg>
            <span>تحميل</span>
        `;
        
        // إضافة حدث النقر
        button.addEventListener('click', handleDownloadClick);
        
        return button;
    }
    
    // معالجة النقر على زر التحميل
    async function handleDownloadClick(e) {
        e.preventDefault();
        e.stopPropagation();
        
        if (isProcessing) {
            console.log('⚠️ Download already in progress');
            return;
        }
        
        try {
            isProcessing = true;
            downloadButton.classList.add('loading');
            
            // الحصول على معلومات الفيديو
            currentVideoInfo = getVideoInfo();
            if (!currentVideoInfo) {
                throw new Error('Unable to get video information');
            }
            
            // الحصول على روابط التحميل
            const links = await getDownloadLinks();
            if (!links || links.length === 0) {
                throw new Error('No download links found');
            }
            
            // عرض قائمة الجودات
            showQualityMenu(links);
            
        } catch (error) {
            console.error('❌ Download error:', error);
            showError('خطأ في التحميل: ' + error.message);
        } finally {
            isProcessing = false;
            downloadButton.classList.remove('loading');
        }
    }
    
    // إنشاء قائمة الجودات
    function createQualityMenu() {
        const menu = document.createElement('div');
        menu.id = 'safarget-quality-menu';
        menu.className = 'safarget-quality-menu';
        
        return menu;
    }
    
    // عرض قائمة الجودات
    function showQualityMenu(links) {
        if (!qualityMenu) {
            insertQualityMenu();
        }
        
        // مسح المحتوى السابق
        qualityMenu.innerHTML = '';
        
        // إضافة الرأس
        const header = document.createElement('div');
        header.className = 'safarget-menu-header';
        header.innerHTML = `
            <h3>اختر جودة التحميل</h3>
            <button class="safarget-close-btn" onclick="hideQualityMenu()">×</button>
        `;
        qualityMenu.appendChild(header);
        
        // إضافة خيارات الجودة
        const optionsList = document.createElement('div');
        optionsList.className = 'safarget-quality-options';
        
        // تصنيف الروابط
        const videoLinks = links.filter(link => link.hasVideo);
        const audioLinks = links.filter(link => link.hasAudio && !link.hasVideo);
        
        // إضافة خيارات الفيديو
        if (videoLinks.length > 0) {
            const videoHeader = document.createElement('div');
            videoHeader.className = 'safarget-option-header';
            videoHeader.textContent = 'فيديو';
            optionsList.appendChild(videoHeader);
            
            videoLinks.forEach(link => {
                const option = createQualityOption(link, 'video');
                optionsList.appendChild(option);
            });
        }
        
        // إضافة خيارات الصوت
        if (audioLinks.length > 0) {
            const audioHeader = document.createElement('div');
            audioHeader.className = 'safarget-option-header';
            audioHeader.textContent = 'صوت فقط';
            optionsList.appendChild(audioHeader);
            
            audioLinks.forEach(link => {
                const option = createQualityOption(link, 'audio');
                optionsList.appendChild(option);
            });
        }
        
        qualityMenu.appendChild(optionsList);
        
        // عرض القائمة
        qualityMenu.style.display = 'block';
        
        // تحديد موقع القائمة
        positionQualityMenu();
    }
    
    // إنشاء خيار جودة
    function createQualityOption(link, type) {
        const option = document.createElement('div');
        option.className = 'safarget-quality-option';
        option.innerHTML = `
            <div class="quality-info">
                <span class="quality-label">${link.quality}</span>
                <span class="quality-type">${type === 'video' ? 'فيديو' : 'صوت'}</span>
                    </div>
            <button class="download-btn" data-url="${link.url}" data-quality="${link.quality}" data-type="${type}">
                تحميل
                    </button>
        `;
        
        // إضافة حدث النقر
        const downloadBtn = option.querySelector('.download-btn');
        downloadBtn.addEventListener('click', (e) => {
            e.preventDefault();
            downloadSelectedQuality(link, type);
        });
        
        return option;
    }
    
    // تحميل الجودة المحددة
    async function downloadSelectedQuality(link, type) {
        try {
            console.log('📥 Starting download:', link.quality);
            
            hideQualityMenu();
            showSuccess('بدأ التحميل...');
            
            // إرسال للـ background script
            const downloadData = {
                url: link.url,
                filename: generateFileName({
                    quality: link.quality,
                    type: type,
                    extension: getFileExtension(link.type)
                }),
                videoInfo: currentVideoInfo,
                quality: link.quality,
                type: type
            };
            
            // إرسال رسالة للـ background script
            chrome.runtime.sendMessage({
                type: 'youtube_download',
                data: downloadData
            }, (response) => {
                if (response && response.success) {
                    showSuccess('تم بدء التحميل بنجاح');
                } else {
                    showError('خطأ في بدء التحميل');
                }
            });
            
        } catch (error) {
            console.error('❌ Download error:', error);
            showError('خطأ في التحميل: ' + error.message);
        }
    }
    
    // الحصول على امتداد الملف
    function getFileExtension(mimeType) {
        if (!mimeType) return 'mp4';
        
        if (mimeType.includes('mp4')) return 'mp4';
        if (mimeType.includes('webm')) return 'webm';
        if (mimeType.includes('mp3')) return 'mp3';
        if (mimeType.includes('m4a')) return 'm4a';
        
        return 'mp4';
    }
    
    // إخفاء قائمة الجودات
    function hideQualityMenu() {
        if (qualityMenu) {
            qualityMenu.style.display = 'none';
        }
    }
    
    // تحديد موقع قائمة الجودات
    function positionQualityMenu() {
        if (!qualityMenu || !downloadButton) return;
        
        const buttonRect = downloadButton.getBoundingClientRect();
        const menuHeight = qualityMenu.offsetHeight;
        const viewportHeight = window.innerHeight;
        
        // تحديد الموقع
        let top = buttonRect.bottom + 10;
        if (top + menuHeight > viewportHeight) {
            top = buttonRect.top - menuHeight - 10;
        }
        
        qualityMenu.style.position = 'fixed';
        qualityMenu.style.top = top + 'px';
        qualityMenu.style.left = (buttonRect.left - 200) + 'px';
        qualityMenu.style.zIndex = '10000';
    }
    
    // =================================================
    // إدراج العناصر في الصفحة
    // =================================================
    
    // إدراج الأيقونة العائمة في الركن الأيمن العلوي
    function insertFloatingIcon() {
        console.log('🎯 Inserting floating download icon...');
        
        // التأكد من أننا على YouTube وعلى صفحة فيديو
        if (!isYouTube() || !getVideoId()) {
            console.log('❌ Not on YouTube video page, skipping floating icon');
            return false;
        }
        
        // التحقق من وجود أيقونة قديمة
        const existingIcon = document.getElementById('safarget-floating-icon');
        if (existingIcon) {
            console.log('🗑️ Removing existing floating icon');
            existingIcon.remove();
        }
        
        // إنشاء الأيقونة العائمة
        const floatingIcon = createFloatingIcon();
        
        // إدراج الأيقونة في body
        document.body.appendChild(floatingIcon);
        
        // تأثير ظهور سلس
        setTimeout(() => {
            floatingIcon.style.opacity = '1';
            floatingIcon.style.transform = 'scale(1)';
        }, 100);
        
        console.log('✅ Floating download icon inserted successfully');
        return true;
    }

    // إدراج زر التحميل (احتياطي للطريقة التقليدية)
    function insertDownloadButton() {
        console.log('🔍 Looking for download button location...');
        
        // البحث عن مكان مناسب للزر - selectors محدثة لـ YouTube 2024
        const targetSelectors = [
            // YouTube الجديد 2024 - الأكثر شيوعاً
            'ytd-menu-renderer[class*="ytd-video-primary-info-renderer"] #top-level-buttons-computed',
            '#top-level-buttons-computed',
            'ytd-menu-renderer #top-level-buttons-computed',
            '#actions.ytd-video-primary-info-renderer',
            '#actions.ytd-watch-metadata',
            'ytd-watch-metadata #actions',
            'ytd-video-primary-info-renderer #actions',
            // محاولات إضافية
            '.ytd-video-primary-info-renderer [id*="actions"]',
            '.ytd-watch-metadata [id*="actions"]',
            '[id*="menu-container"]',
            '.ytd-menu-renderer .top-level-buttons',
            'ytd-segmented-like-dislike-button-renderer',
            // احتياطي عام
            '[class*="ytd-menu-renderer"] [class*="buttons"]',
            '[class*="video-primary-info"] [class*="actions"]',
            '[aria-label*="actions"], [aria-label*="Actions"]'
        ];
        
        let target = null;
        for (const selector of targetSelectors) {
            target = document.querySelector(selector);
            if (target) {
                console.log('✅ Found target:', selector);
                break;
            }
        }
        
        if (!target) {
            console.log('❌ No suitable location found with primary selectors');
            console.log('🔍 Searching for fallback targets...');
            
            // محاولة احتياطية أكثر شمولية
            const fallbackSelectors = [
                '[id*="actions"]',
                '[class*="actions"]', 
                '[class*="ytd-menu-renderer"]',
                '[class*="buttons"]',
                '.ytd-video-owner-renderer',
                '#owner',
                '#upload-info'
            ];
            
            for (const selector of fallbackSelectors) {
                target = document.querySelector(selector);
                if (target) {
                    console.log('✅ Found fallback target:', selector);
                    break;
                }
            }
            
            if (!target) {
                console.log('❌ No suitable location found anywhere');
                console.log('🔍 Available elements with "ytd" classes:');
                const ytdElements = document.querySelectorAll('[class*="ytd"]');
                ytdElements.forEach((el, i) => {
                    if (i < 10) { // محدود بـ 10 عناصر للتجنب الإكثار
                        console.log(`  ${i + 1}:`, el.tagName, el.className);
                    }
                });
            return false;
            }
        }
        
        // إزالة الزر القديم إن وجد
        const oldButton = document.getElementById('safarget-youtube-download');
        if (oldButton) {
            console.log('🗑️ Removing old button');
            oldButton.remove();
        }
        
        // إنشاء وإدراج الزر الجديد
        downloadButton = createDownloadButton();
        
        // محاولة إدراج الزر في المكان الأنسب
        if (target.firstChild) {
        target.insertBefore(downloadButton, target.firstChild);
        } else {
            target.appendChild(downloadButton);
        }
        
        console.log('✅ Download button inserted successfully');
        return true;
    }
    
    // إدراج قائمة الجودات
    function insertQualityMenu() {
        // إزالة القائمة القديمة إن وجدت
        const oldMenu = document.getElementById('safarget-quality-menu');
        if (oldMenu) oldMenu.remove();
        
        // إنشاء وإدراج القائمة الجديدة
        qualityMenu = createQualityMenu();
        document.body.appendChild(qualityMenu);
        
        // إضافة حدث الإغلاق عند النقر خارج القائمة
        document.addEventListener('click', (e) => {
            if (qualityMenu && 
                !qualityMenu.contains(e.target) && 
                downloadButton &&
                !downloadButton.contains(e.target) &&
                qualityMenu.style.display !== 'none') {
                hideQualityMenu();
            }
        });
        
        // جعل hideQualityMenu متاحة globally
        window.hideQualityMenu = hideQualityMenu;
    }
    
    // =================================================
    // الأدوات المساعدة
    // =================================================
    
    // إنشاء اسم الملف
    function generateFileName(format) {
        const title = currentVideoInfo?.title || 'youtube_video';
        const quality = format.quality || 'unknown';
        const extension = format.extension || 'mp4';
        
        // تنظيف اسم الملف
        const cleanTitle = title.replace(/[^\w\s-]/g, '').trim().replace(/\s+/g, '_');
        
        return `${cleanTitle}_${quality}.${extension}`;
    }
    
    // عرض رسالة نجاح
    function showSuccess(message) {
        showNotification(message, 'success');
    }
    
    function showError(message) {
        showNotification(message, 'error');
    }
    
    function showNotification(message, type = 'info') {
        const notification = document.createElement('div');
        notification.className = `safarget-notification safarget-notification-${type}`;
        notification.textContent = message;
        
        document.body.appendChild(notification);
        
        setTimeout(() => {
            notification.classList.add('safarget-notification-show');
        }, 10);
        
        setTimeout(() => {
            notification.classList.remove('safarget-notification-show');
            setTimeout(() => {
                notification.remove();
            }, 300);
        }, 3000);
    }
    
    // =================================================
    // المراقبة والتهيئة
    // =================================================
    
    // مراقب التغييرات في الصفحة - محسن لـ YouTube
    function observePageChanges() {
        console.log('👀 Starting enhanced page observer...');
        
        let insertionAttempts = 0;
        const maxInsertionAttempts = 5;
        
        const observer = new MutationObserver((mutations) => {
            const newVideoId = getVideoId();
            const hasVideoId = Boolean(newVideoId);
            
            // مراقبة تغيير الفيديو
            if (newVideoId && newVideoId !== lastVideoId) {
                console.log('🔄 Video changed:', newVideoId);
                lastVideoId = newVideoId;
                currentVideoInfo = null;
                insertionAttempts = 0;
                
                // انتظار متدرج لإدراج الأيقونة العائمة
                const delays = [500, 1000, 2000, 4000];
                delays.forEach((delay, index) => {
                setTimeout(() => {
                        if (!document.getElementById('safarget-floating-icon') && hasVideoId) {
                            console.log(`🔄 Inserting floating icon for new video (attempt ${index + 1})...`);
                            insertFloatingIcon();
                        }
                    }, delay);
                });
            }
            
            // فحص دوري للتأكد من وجود الأيقونة العائمة
            if (hasVideoId && !document.getElementById('safarget-floating-icon') && insertionAttempts < maxInsertionAttempts) {
                insertionAttempts++;
                console.log(`🔄 Re-inserting missing floating icon (attempt ${insertionAttempts})...`);
                setTimeout(() => {
                    insertFloatingIcon();
                }, 200);
            }
        });
        
        // مراقبة أكثر شمولية
        observer.observe(document.body, {
            childList: true,
            subtree: true,
            attributes: false,
            attributeOldValue: false
        });
        
        console.log('✅ Enhanced page observer started');
    }
    
    // التهيئة المحسنة لـ YouTube
    function initialize() {
        console.log('🚀 Initializing SafarGet YouTube Downloader...');
        
        // إدراج الأنماط أولاً
        injectStyles();
        
        // بدء مراقبة التغييرات على الفور
        observePageChanges();
        
        // محاولة إدراج الزر بناءً على حالة الصفحة
        function attemptButtonInsertion() {
        if (document.readyState === 'loading') {
                document.addEventListener('DOMContentLoaded', () => {
                    setTimeout(tryInsertButton, 1000);
                });
        } else {
                tryInsertButton();
            }
        }
        
        function tryInsertButton() {
            console.log('🎯 Attempting to insert floating icon...');
            
            // محاولات متعددة مع فترات انتظار مختلفة
            const attempts = [500, 1000, 2000, 3000];
            
            attempts.forEach((delay, index) => {
                setTimeout(() => {
                    if (!document.getElementById('safarget-floating-icon')) {
                        console.log(`🔄 Attempt ${index + 1}: Inserting floating icon...`);
                        const success = insertFloatingIcon();
                        if (success) {
                            console.log(`✅ Floating icon inserted on attempt ${index + 1}`);
                        }
                    }
                }, delay);
            });
        }
        
        // بدء المحاولات
        attemptButtonInsertion();
        
        console.log('✅ SafarGet YouTube Downloader initialized');
    }
    
    // إدراج أنماط CSS
    function injectStyles() {
        if (document.getElementById('safarget-youtube-styles')) return;
        
        const styles = `
            /* الأيقونة العائمة في الركن الأيمن العلوي */
            .safarget-floating-icon {
                position: fixed !important;
                top: 100px !important;
                right: 20px !important;
                width: 60px !important;
                height: 60px !important;
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%) !important;
                border-radius: 50% !important;
                cursor: pointer !important;
                z-index: 999999 !important;
                box-shadow: 0 4px 20px rgba(102, 126, 234, 0.4) !important;
                transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1) !important;
                display: flex !important;
                align-items: center !important;
                justify-content: center !important;
                border: 3px solid rgba(255, 255, 255, 0.2) !important;
                backdrop-filter: blur(10px) !important;
                animation: safarget-pulse 2s infinite !important;
                /* تأثير الظهور */
                opacity: 0 !important;
                transform: scale(0.8) !important;
            }
            
            .safarget-floating-icon:hover {
                transform: scale(1.1) translateY(-2px) !important;
                box-shadow: 0 8px 32px rgba(102, 126, 234, 0.6) !important;
                background: linear-gradient(135deg, #764ba2 0%, #667eea 100%) !important;
                animation: none !important;
            }
            
            .safarget-floating-icon:active {
                transform: scale(0.95) !important;
            }
            
            .safarget-floating-icon .safarget-icon-content {
                position: relative !important;
                width: 100% !important;
                height: 100% !important;
                display: flex !important;
                align-items: center !important;
                justify-content: center !important;
            }
            
            .safarget-floating-icon svg {
                color: white !important;
                filter: drop-shadow(0 2px 4px rgba(0, 0, 0, 0.3)) !important;
                transition: transform 0.3s ease !important;
            }
            
            .safarget-floating-icon:hover svg {
                transform: translateY(-2px) !important;
            }
            
            /* Tooltip للأيقونة العائمة */
            .safarget-tooltip {
                position: absolute !important;
                right: 70px !important;
                top: 50% !important;
                transform: translateY(-50%) !important;
                background: rgba(0, 0, 0, 0.9) !important;
                color: white !important;
                padding: 8px 12px !important;
                border-radius: 6px !important;
                font-size: 12px !important;
                font-weight: 500 !important;
                white-space: nowrap !important;
                opacity: 0 !important;
                visibility: hidden !important;
                transition: all 0.3s ease !important;
                pointer-events: none !important;
                z-index: 1000000 !important;
            }
            
            .safarget-tooltip::after {
                content: '' !important;
                position: absolute !important;
                left: 100% !important;
                top: 50% !important;
                transform: translateY(-50%) !important;
                border: 6px solid transparent !important;
                border-left-color: rgba(0, 0, 0, 0.9) !important;
            }
            
            .safarget-floating-icon:hover .safarget-tooltip {
                opacity: 1 !important;
                visibility: visible !important;
                transform: translateY(-50%) translateX(-5px) !important;
            }
            
            /* تأثير النبضة */
            @keyframes safarget-pulse {
                0% {
                    box-shadow: 0 4px 20px rgba(102, 126, 234, 0.4), 0 0 0 0 rgba(102, 126, 234, 0.7);
                }
                70% {
                    box-shadow: 0 4px 20px rgba(102, 126, 234, 0.4), 0 0 0 10px rgba(102, 126, 234, 0);
                }
                100% {
                    box-shadow: 0 4px 20px rgba(102, 126, 234, 0.4), 0 0 0 0 rgba(102, 126, 234, 0);
                }
            }
            
            /* زر التحميل العادي (احتياطي) */
            .safarget-download-btn {
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%) !important;
                color: white !important;
                border: none !important;
                border-radius: 8px !important;
                padding: 8px 16px !important;
                margin-right: 8px !important;
                font-size: 14px !important;
                font-weight: 500 !important;
                cursor: pointer !important;
                display: inline-flex !important;
                align-items: center !important;
                gap: 6px !important;
                transition: all 0.3s ease !important;
                box-shadow: 0 2px 8px rgba(102, 126, 234, 0.3) !important;
                z-index: 1000 !important;
                position: relative !important;
            }
            
            .safarget-download-btn:hover {
                transform: translateY(-1px) !important;
                box-shadow: 0 4px 12px rgba(102, 126, 234, 0.4) !important;
                background: linear-gradient(135deg, #764ba2 0%, #667eea 100%) !important;
            }
            
            .safarget-download-btn.loading {
                opacity: 0.7 !important;
                pointer-events: none !important;
            }
            
            .safarget-download-btn svg {
                transition: transform 0.3s ease !important;
            }
            
            .safarget-download-btn:hover svg {
                transform: translateY(2px) !important;
            }
            
            .safarget-quality-menu {
                position: fixed !important;
                background: white !important;
                border-radius: 12px !important;
                box-shadow: 0 8px 32px rgba(0, 0, 0, 0.2) !important;
                min-width: 300px !important;
                max-height: 400px !important;
                overflow-y: auto !important;
                z-index: 10000 !important;
                display: none !important;
                border: 1px solid #e0e0e0 !important;
            }
            
            .safarget-menu-header {
                display: flex !important;
                justify-content: space-between !important;
                align-items: center !important;
                padding: 16px 20px !important;
                border-bottom: 1px solid #e0e0e0 !important;
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%) !important;
                color: white !important;
                border-radius: 12px 12px 0 0 !important;
            }
            
            .safarget-menu-header h3 {
                margin: 0 !important;
                font-size: 16px !important;
                font-weight: 600 !important;
            }
            
            .safarget-close-btn {
                background: rgba(255, 255, 255, 0.2) !important;
                border: none !important;
                color: white !important;
                font-size: 20px !important;
                width: 30px !important;
                height: 30px !important;
                border-radius: 50% !important;
                cursor: pointer !important;
                display: flex !important;
                align-items: center !important;
                justify-content: center !important;
                transition: background 0.3s ease !important;
            }
            
            .safarget-close-btn:hover {
                background: rgba(255, 255, 255, 0.3) !important;
            }
            
            .safarget-quality-options {
                padding: 8px 0 !important;
            }
            
            .safarget-option-header {
                padding: 12px 20px 8px !important;
                font-weight: 600 !important;
                color: #333 !important;
                border-bottom: 1px solid #f0f0f0 !important;
                background: #f8f9fa !important;
                font-size: 14px !important;
            }
            
            .safarget-quality-option {
                display: flex !important;
                justify-content: space-between !important;
                align-items: center !important;
                padding: 12px 20px !important;
                border-bottom: 1px solid #f0f0f0 !important;
                transition: background 0.3s ease !important;
            }
            
            .safarget-quality-option:hover {
                background: #f8f9fa !important;
            }
            
            .quality-info {
                display: flex !important;
                flex-direction: column !important;
                gap: 4px !important;
            }
            
            .quality-label {
                font-weight: 600 !important;
                color: #333 !important;
                font-size: 14px !important;
            }
            
            .quality-type {
                font-size: 12px !important;
                color: #666 !important;
            }
            
            .safarget-quality-option .download-btn {
                background: linear-gradient(135deg, #2ed573 0%, #17c0eb 100%) !important;
                color: white !important;
                border: none !important;
                border-radius: 6px !important;
                padding: 6px 16px !important;
                font-size: 12px !important;
                font-weight: 500 !important;
                cursor: pointer !important;
                transition: all 0.3s ease !important;
            }
            
            .safarget-quality-option .download-btn:hover {
                transform: translateY(-1px) !important;
                box-shadow: 0 2px 8px rgba(46, 213, 115, 0.3) !important;
            }
            
            .safarget-notification {
                position: fixed !important;
                top: 20px !important;
                right: 20px !important;
                background: white !important;
                border-radius: 8px !important;
                padding: 16px 20px !important;
                box-shadow: 0 4px 16px rgba(0, 0, 0, 0.1) !important;
                border-left: 4px solid #2ed573 !important;
                z-index: 10001 !important;
                transform: translateX(400px) !important;
                transition: transform 0.3s ease !important;
                font-size: 14px !important;
                max-width: 300px !important;
            }
            
            .safarget-notification-show {
                transform: translateX(0) !important;
            }
            
            .safarget-notification-error {
                border-left-color: #ff4757 !important;
            }
            
            .safarget-notification-success {
                border-left-color: #2ed573 !important;
            }
        `;
        
        const styleSheet = document.createElement('style');
        styleSheet.id = 'safarget-youtube-styles';
        styleSheet.textContent = styles;
        document.head.appendChild(styleSheet);
        
        console.log('🎨 Styles injected');
    }
    
    // أداة Debug للتطوير - للمساعدة في حل مشاكل YouTube
    function debugYouTubeDOM() {
        console.log('🔍 === YouTube DOM DEBUG ===');
        console.log('📍 Current URL:', window.location.href);
        console.log('📍 Video ID:', getVideoId());
        console.log('📍 Page ready state:', document.readyState);
        
        console.log('🎯 Searching for potential targets:');
        const debugSelectors = [
            '#top-level-buttons-computed',
            'ytd-menu-renderer',
            '#actions',
            '[class*="ytd-video-primary-info"]',
            '[class*="ytd-watch-metadata"]',
            '[class*="ytd-menu-renderer"]'
        ];
        
        debugSelectors.forEach(selector => {
            const elements = document.querySelectorAll(selector);
            console.log(`  ${selector}: ${elements.length} found`);
            if (elements.length > 0) {
                console.log(`    First element:`, elements[0]);
            }
        });
        
        // فحص إذا كان الزر أو الأيقونة موجودة
        const existingButton = document.getElementById('safarget-youtube-download');
        const existingIcon = document.getElementById('safarget-floating-icon');
        console.log('🔲 SafarGet button exists:', !!existingButton);
        console.log('🎯 SafarGet floating icon exists:', !!existingIcon);
        
        console.log('🔍 === END DEBUG ===');
    }
    
    // إضافة أمر Debug للوحة التحكم
    window.debugSafarGet = debugYouTubeDOM;
    
    // تشغيل debug تلقائياً في البداية
    setTimeout(() => {
        debugYouTubeDOM();
    }, 3000);
    
    // بدء التهيئة
    initialize();
    
})();
