// YouTube Video Detector and Quality Extractor - النسخة المحسنة
(function() {
    'use strict';
    
    let currentVideoUrl = null;
    let floatingButton = null;
    let qualityMenu = null;
    let isExtractingQualities = false;
    
    // Create floating button
    function createFloatingButton() {
        if (floatingButton) return floatingButton;
        
        floatingButton = document.createElement('div');
        floatingButton.id = 'safarget-youtube-button';
        floatingButton.innerHTML = `
            <img src="${chrome.runtime.getURL('icon-48.png')}" alt="SafarGet" style="width: 32px; height: 32px; border-radius: 6px;">
            <span class="tooltip">Download with SafarGet</span>
        `;
        
        // CSS for button and menu
        const style = document.createElement('style');
        style.textContent = `
            #safarget-youtube-button {
                position: fixed !important;
                top: 80px !important;
                right: 20px !important;
                width: 48px !important;
                height: 48px !important;
                background: rgba(102, 126, 234, 0.9) !important;
                border-radius: 12px !important;
                cursor: pointer !important;
                z-index: 2147483647 !important;
                display: flex !important;
                align-items: center !important;
                justify-content: center !important;
                box-shadow: 0 4px 12px rgba(0,0,0,0.3) !important;
                transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1) !important;
                opacity: 0 !important;
                transform: scale(0.8) !important;
                backdrop-filter: blur(8px) !important;
                border: 2px solid rgba(255, 255, 255, 0.2) !important;
            }
            
            #safarget-youtube-button.show {
                opacity: 1 !important;
                transform: scale(1) !important;
            }
            
            #safarget-youtube-button:hover {
                background: rgba(102, 126, 234, 1) !important;
                transform: scale(1.1) !important;
                box-shadow: 0 6px 16px rgba(0,0,0,0.4) !important;
            }
            
            #safarget-youtube-button .tooltip {
                position: absolute !important;
                bottom: -40px !important;
                left: 50% !important;
                transform: translateX(-50%) !important;
                background: rgba(18, 18, 18, 0.9) !important;
                color: white !important;
                padding: 8px 12px !important;
                border-radius: 6px !important;
                font-size: 12px !important;
                white-space: nowrap !important;
                opacity: 0 !important;
                pointer-events: none !important;
                transition: opacity 0.3s !important;
                font-family: -apple-system, BlinkMacSystemFont, sans-serif !important;
            }
            
            #safarget-youtube-button:hover .tooltip {
                opacity: 1 !important;
            }
            
            #safarget-quality-menu {
                position: fixed !important;
                top: 136px !important;
                right: 20px !important;
                background: rgba(15, 23, 42, 0.85) !important;
                backdrop-filter: blur(16px) !important;
                border-radius: 12px !important;
                padding: 6px 0 !important;
                min-width: 220px !important;
                max-height: 320px !important;
                overflow: hidden !important;
                z-index: 2147483647 !important;
                box-shadow: 0 8px 32px rgba(0,0,0,0.4) !important;
                opacity: 0 !important;
                transform: translateY(-10px) scale(0.95) !important;
                transition: all 0.25s cubic-bezier(0.4, 0, 0.2, 1) !important;
                pointer-events: none !important;
                border: 1px solid rgba(255,255,255,0.15) !important;
            }
            
            #safarget-quality-menu.show {
                opacity: 1 !important;
                transform: translateY(0) scale(1) !important;
                pointer-events: all !important;
            }
            
            #safarget-quality-menu .menu-header {
                padding: 12px 16px !important;
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%) !important;
                color: white !important;
                font-weight: 600 !important;
                font-size: 14px !important;
                border-bottom: 1px solid rgba(255,255,255,0.12) !important;
                text-align: center !important;
                border-radius: 12px 12px 0 0 !important;
                font-family: -apple-system, BlinkMacSystemFont, sans-serif !important;
            }
            
            #safarget-quality-menu .menu-content {
                max-height: 280px !important;
                overflow-y: auto !important;
                padding: 4px 0 !important;
            }
            
            #safarget-quality-menu .safarget-option-header {
                padding: 6px 12px 4px !important;
                color: rgba(102, 126, 234, 0.9) !important;
                font-weight: 600 !important;
                font-size: 11px !important;
                text-transform: uppercase !important;
                letter-spacing: 0.5px !important;
                border-bottom: 1px solid rgba(102, 126, 234, 0.2) !important;
                margin: 2px 4px 4px !important;
                background: rgba(102, 126, 234, 0.1) !important;
                border-radius: 4px !important;
                font-family: -apple-system, BlinkMacSystemFont, sans-serif !important;
            }
            
            #safarget-quality-menu .menu-content::-webkit-scrollbar {
                width: 6px !important;
            }
            
            #safarget-quality-menu .menu-content::-webkit-scrollbar-track {
                background: rgba(255,255,255,0.05) !important;
            }
            
            #safarget-quality-menu .menu-content::-webkit-scrollbar-thumb {
                background: rgba(102, 126, 234, 0.6) !important;
                border-radius: 3px !important;
            }
            
            #safarget-quality-menu .quality-item {
                padding: 8px 12px !important;
                color: white !important;
                cursor: pointer !important;
                transition: all 0.2s ease !important;
                display: flex !important;
                justify-content: space-between !important;
                align-items: center !important;
                font-size: 12px !important;
                border-bottom: 1px solid rgba(255,255,255,0.08) !important;
                margin: 1px 4px !important;
                border-radius: 6px !important;
                font-family: -apple-system, BlinkMacSystemFont, sans-serif !important;
            }
            
            #safarget-quality-menu .quality-item:last-child {
                border-bottom: none !important;
            }
            
            #safarget-quality-menu .quality-item:hover {
                background: rgba(102, 126, 234, 0.3) !important;
                transform: translateX(-3px) !important;
            }
            
            #safarget-quality-menu .quality-item.video-quality:hover {
                background: rgba(102, 126, 234, 0.25) !important;
            }
            
            #safarget-quality-menu .quality-item.audio-quality:hover {
                background: rgba(234, 102, 165, 0.25) !important;
            }
            
            #safarget-quality-menu .quality-label {
                font-weight: 600 !important;
                display: flex !important;
                align-items: center !important;
                gap: 8px !important;
            }
            
            #safarget-quality-menu .quality-badge {
                background: rgba(102, 126, 234, 0.5) !important;
                color: #e0f2fe !important;
                padding: 3px 8px !important;
                border-radius: 5px !important;
                font-size: 10px !important;
                font-weight: 500 !important;
                text-transform: uppercase !important;
            }
            
            #safarget-quality-menu .quality-info {
                font-size: 11px !important;
                color: rgba(255,255,255,0.7) !important;
                display: flex !important;
                align-items: center !important;
                gap: 6px !important;
            }
            
            #safarget-quality-menu .loading {
                text-align: center !important;
                padding: 24px 16px !important;
                color: white !important;
                display: flex !important;
                flex-direction: column !important;
                align-items: center !important;
                gap: 12px !important;
                font-size: 13px !important;
                font-family: -apple-system, BlinkMacSystemFont, sans-serif !important;
            }
            
            #safarget-quality-menu .loading-spinner {
                width: 32px !important;
                height: 32px !important;
                border: 3px solid rgba(255,255,255,0.2) !important;
                border-top-color: #667eea !important;
                border-radius: 50% !important;
                animation: spin 0.8s linear infinite !important;
            }
            
            @keyframes spin {
                to { transform: rotate(360deg) !important; }
            }
            
            #safarget-quality-menu .loading {
                text-align: center !important;
                padding: 24px 16px !important;
                color: white !important;
                display: flex !important;
                flex-direction: column !important;
                align-items: center !important;
                gap: 12px !important;
                font-size: 13px !important;
                font-family: -apple-system, BlinkMacSystemFont, sans-serif !important;
            }
            
            #safarget-quality-menu .loading-spinner {
                width: 32px !important;
                height: 32px !important;
                border: 3px solid rgba(255,255,255,0.2) !important;
                border-top-color: #667eea !important;
                border-radius: 50% !important;
                animation: spin 0.8s linear infinite !important;
            }
            
            #safarget-quality-menu .error {
                text-align: center !important;
                padding: 20px 16px !important;
                color: #fca5a5 !important;
                font-size: 13px !important;
                line-height: 1.4 !important;
                font-family: -apple-system, BlinkMacSystemFont, sans-serif !important;
            }
            
            .safarget-notification {
                position: fixed !important;
                bottom: 20px !important;
                right: 20px !important;
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%) !important;
                color: white !important;
                padding: 16px 24px !important;
                border-radius: 10px !important;
                box-shadow: 0 6px 24px rgba(0,0,0,0.3) !important;
                z-index: 2147483647 !important;
                font-size: 14px !important;
                font-weight: 500 !important;
                display: flex !important;
                align-items: center !important;
                gap: 12px !important;
                animation: slideInRight 0.3s ease-out !important;
                font-family: -apple-system, BlinkMacSystemFont, sans-serif !important;
                border: 1px solid rgba(255, 255, 255, 0.2) !important;
            }
            
            @keyframes slideInRight {
                from { transform: translateX(100%); opacity: 0; }
                to { transform: translateX(0); opacity: 1; }
            }
            
            @keyframes slideOutRight {
                from { transform: translateX(0); opacity: 1; }
                to { transform: translateX(100%); opacity: 0; }
            }
        `;
        document.head.appendChild(style);
        
        // Create quality menu
        qualityMenu = document.createElement('div');
        qualityMenu.id = 'safarget-quality-menu';
        qualityMenu.innerHTML = `
            <div class="menu-header">SafarGet - Download Options</div>
            <div class="menu-content"></div>
        `;
        floatingButton.appendChild(qualityMenu);
        
        // Handle button click with ripple effect
        floatingButton.addEventListener('click', function(e) {
            e.stopPropagation();
            const ripple = document.createElement('div');
            ripple.className = 'ripple';
            ripple.style.cssText = `
                position: absolute !important;
                width: 100% !important;
                height: 100% !important;
                border-radius: 50% !important;
                background: rgba(255,255,255,0.3) !important;
                transform: scale(0) !important;
                animation: rippleEffect 0.6s ease-out !important;
            `;
            floatingButton.appendChild(ripple);
            setTimeout(() => ripple.remove(), 600);
            
            handleButtonClick();
        });
        
        // Close menu when clicking outside
        document.addEventListener('click', function(e) {
            if (!floatingButton.contains(e.target)) {
                qualityMenu.classList.remove('show');
            }
        });
        
        return floatingButton;
    }
    
    // Handle button click
    async function handleButtonClick() {
        if (isExtractingQualities) return;
        
        if (qualityMenu.classList.contains('show')) {
            qualityMenu.classList.remove('show');
            return;
        }
        
        isExtractingQualities = true;
        qualityMenu.querySelector('.menu-content').innerHTML = `
            <div class="loading">
                <div class="loading-spinner"></div>
                <div>Extracting video qualities...</div>
            </div>
        `;
        qualityMenu.classList.add('show');
        
        try {
            // استخراج الجودات باستخدام yt-dlp
            let retries = 3;
            let response = null;
            
            while (retries > 0) {
                response = await chrome.runtime.sendMessage({
                    type: 'extractYouTubeQualities',
                    url: currentVideoUrl
                });
                
                if (response.success && response.qualities && response.qualities.length > 0) {
                    break;
                }
                retries--;
                await new Promise(resolve => setTimeout(resolve, 1000));
            }
            
            isExtractingQualities = false;
            
            if (response && response.success && response.qualities) {
                if (response.fallback) {
                    console.log('⚠️ Using fallback qualities - app may not support quality extraction');
                }
                displayExtractedQualities(response.qualities);
            } else {
                const errorMessage = response && response.error ? response.error : 'Failed to extract qualities. Please try again.';
                showError(errorMessage);
            }
        } catch (error) {
            isExtractingQualities = false;
            console.error('YouTube extraction error:', error);
            showError('Connection error. Ensure SafarGet is running and try again.');
        }
    }
    
    // Display extracted qualities from yt-dlp
    function displayExtractedQualities(qualities) {
        const menuContent = qualityMenu.querySelector('.menu-content');
        menuContent.innerHTML = '';
        
        // Separate video and audio qualities
        const videoQualities = qualities.filter(q => q.has_video !== false);
        const audioQualities = qualities.filter(q => q.has_video === false);
        
        // Sort video qualities by resolution
        const sortedVideoQualities = videoQualities.sort((a, b) => {
            const resA = parseInt(a.resolution) || 0;
            const resB = parseInt(b.resolution) || 0;
            return resB - resA;
        });
        
        // Add video qualities header
        if (sortedVideoQualities.length > 0) {
            const videoHeader = document.createElement('div');
            videoHeader.className = 'safarget-option-header';
            videoHeader.textContent = '📹 Video Quality';
            menuContent.appendChild(videoHeader);
            
            // Add video qualities
            sortedVideoQualities.forEach(quality => {
                const item = document.createElement('div');
                item.className = 'quality-item video-quality';
                
                let label = quality.resolution || quality.format || 'Unknown';
                let badges = [];
                
                if (quality.fps && quality.fps > 30) {
                    badges.push(`${quality.fps}fps`);
                }
                if (parseInt(quality.resolution) >= 2160) {
                    badges.push('4K');
                } else if (parseInt(quality.resolution) >= 1440) {
                    badges.push('2K');
                } else if (parseInt(quality.resolution) >= 1080) {
                    badges.push('HD');
                }
                
                let info = [];
                if (quality.ext) info.push(quality.ext.toUpperCase());
                if (quality.filesize) info.push(formatFileSize(quality.filesize));
                
                item.innerHTML = `
                    <div class="quality-label">
                        <span>📹 ${label}</span>
                        ${badges.map(b => `<span class="quality-badge">${b}</span>`).join('')}
                    </div>
                    <div class="quality-info">${info.join(' • ') || 'Video + Audio'}</div>
                `;
                
                item.addEventListener('click', () => {
                    downloadQuality(quality);
                });
                
                menuContent.appendChild(item);
            });
        }
        
        // Add audio-only option
        if (audioQualities.length > 0 || sortedVideoQualities.length > 0) {
            // Add separator
            const separator = document.createElement('div');
            separator.style.cssText = `
                height: 1px !important;
                background: rgba(255,255,255,0.1) !important;
                margin: 8px 12px !important;
            `;
            menuContent.appendChild(separator);
            
            const audioHeader = document.createElement('div');
            audioHeader.className = 'safarget-option-header';
            audioHeader.textContent = '🎵 Audio Only';
            menuContent.appendChild(audioHeader);
            
            const audioItem = document.createElement('div');
            audioItem.className = 'quality-item audio-quality';
            audioItem.innerHTML = `
                <div class="quality-label">
                    <span>🎧 Audio Only</span>
                    <span class="quality-badge">MP3</span>
                </div>
                <div class="quality-info">Best available audio</div>
            `;
            audioItem.addEventListener('click', () => {
                downloadAudioOnly();
            });
            menuContent.appendChild(audioItem);
        }
    }
    
    // Show error message
    function showError(message) {
        qualityMenu.querySelector('.menu-content').innerHTML = `
            <div class="error">${message}</div>
        `;
    }
    
    // Format file size
    function formatFileSize(bytes) {
        if (!bytes) return '';
        const sizes = ['B', 'KB', 'MB', 'GB'];
        const i = Math.floor(Math.log(bytes) / Math.log(1024));
        return Math.round(bytes / Math.pow(1024, i) * 100) / 100 + ' ' + sizes[i];
    }
    
    // Download specific quality
    function downloadQuality(quality) {
        const videoTitle = document.querySelector('h1.title yt-formatted-string')?.textContent || 
                         document.querySelector('#container h1')?.textContent || 
                         document.querySelector('h1')?.textContent || 
                         'YouTube Video';
        
        // تحديد جودة دقيقة بالـ format ID المحدد - بدون تخمين
        let simpleQuality = 'best';
        
        if (quality.resolution) {
            const height = parseInt(quality.resolution);
            if (height >= 2160) {
                // 4K - format IDs محددة
                simpleQuality = `313+140/315+140/401+140/best[height=2160]`;
            } else if (height >= 1440) {
                // 2K - format IDs محددة
                simpleQuality = `271+140/308+140/best[height=1440]`; 
            } else if (height >= 1080) {
                // 1080p - format IDs محددة
                simpleQuality = `137+140/299+140/best[height=1080]`;
            } else if (height >= 720) {
                // 720p - format IDs محددة ومضبوطة
                simpleQuality = `136+140/298+140/22/best[height=720]`;
            } else if (height >= 480) {
                // 480p - format IDs محددة ومضبوطة
                simpleQuality = `135+140/244+140/18/best[height=480]`;
            } else if (height >= 360) {
                // 360p - format IDs محددة
                simpleQuality = `134+140/243+140/18/best[height=360]`;
            } else {
                // 240p
                simpleQuality = `133+140/242+140/17/best[height=240]`;
            }
        }
        
        console.log('🎬 Using simplified quality:', simpleQuality, 'for', quality.resolution);
        
        chrome.runtime.sendMessage({
            type: 'downloadYouTube',
            url: currentVideoUrl,
            quality: simpleQuality,
            title: videoTitle.trim(),
            resolution: quality.resolution,
            ext: quality.ext || 'mp4'
        }, response => {
            if (response && response.success) {
                showNotification(`Download started! 🚀 (${quality.resolution})`);
                console.log(`✅ YouTube download started: ${quality.resolution} with format: ${simpleQuality}`);
            } else {
                const error = response && response.error ? response.error : 'Failed to start download';
                showNotification(`Error: ${error}`);
                console.error(`❌ YouTube download failed: ${error} for quality: ${quality.resolution}`);
            }
        });
        
        qualityMenu.classList.remove('show');
    }
    
    // Download audio only
    function downloadAudioOnly() {
        const videoTitle = document.querySelector('h1.title yt-formatted-string')?.textContent || 
                         document.querySelector('#container h1')?.textContent || 
                         document.querySelector('h1')?.textContent || 
                         'YouTube Audio';
        
        console.log('🎵 Using audio-only quality: bestaudio');
        
        chrome.runtime.sendMessage({
            type: 'downloadYouTube',
            url: currentVideoUrl,
            quality: 'bestaudio',
            title: videoTitle.trim(),
            audioOnly: true
        }, response => {
            if (response && response.success) {
                showNotification('Audio download started! 🎵');
            } else {
                const error = response && response.error ? response.error : 'Failed to start audio download';
                showNotification(`Error: ${error}`);
            }
        });
        
        qualityMenu.classList.remove('show');
    }
    
    // Display simple download options
    function displaySimpleOptions() {
        const menuContent = qualityMenu.querySelector('.menu-content');
        menuContent.innerHTML = '';
        
        // Add header for video qualities
        const videoHeader = document.createElement('div');
        videoHeader.className = 'safarget-option-header';
        videoHeader.textContent = '📹 Video Quality';
        menuContent.appendChild(videoHeader);
        
        // Video options - full quality list
        const videoQualities = [
            { label: 'Best Quality', quality: 'best', badge: 'BEST', icon: '⭐' },
            { label: '4K (2160p)', quality: 'best[height<=2160]', badge: '4K', icon: '🎬' },
            { label: '1440p QHD', quality: 'best[height<=1440]', badge: '2K', icon: '📺' },
            { label: '1080p Full HD', quality: 'best[height<=1080]', badge: 'FHD', icon: '📹' },
            { label: '720p HD', quality: 'best[height<=720]', badge: 'HD', icon: '📽️' },
            { label: '480p', quality: 'best[height<=480]', badge: '480p', icon: '📱' }
        ];
        
        videoQualities.forEach(option => {
            const item = document.createElement('div');
            item.className = 'quality-item video-quality';
            item.innerHTML = `
                <div class="quality-label">
                    <span>${option.icon} ${option.label}</span>
                    <span class="quality-badge">${option.badge}</span>
                </div>
                <div class="quality-info">Video + Audio</div>
            `;
            
            item.addEventListener('click', () => {
                downloadWithQuality(option.quality, 'video', option.label);
            });
            
            menuContent.appendChild(item);
        });
        
        // Add separator
        const separator = document.createElement('div');
        separator.style.cssText = `
            height: 1px !important;
            background: rgba(255,255,255,0.1) !important;
            margin: 8px 12px !important;
        `;
        menuContent.appendChild(separator);
        
        // Add header for audio
        const audioHeader = document.createElement('div');
        audioHeader.className = 'safarget-option-header';
        audioHeader.textContent = '🎵 Audio Only';
        menuContent.appendChild(audioHeader);
        
        // Audio only options - simplified
        const audioQualities = [
            { label: 'Audio Only', quality: 'bestaudio', badge: 'MP3', icon: '🎧' }
        ];
        
        audioQualities.forEach(option => {
            const item = document.createElement('div');
            item.className = 'quality-item audio-quality';
            item.innerHTML = `
                <div class="quality-label">
                    <span>${option.icon} ${option.label}</span>
                    <span class="quality-badge">${option.badge}</span>
                </div>
                <div class="quality-info">MP3 / M4A</div>
            `;
            
            item.addEventListener('click', () => {
                downloadWithQuality(option.quality, 'audio', option.label);
            });
            
            menuContent.appendChild(item);
        });
    }
    

    
    // Show notification
    function showNotification(message) {
        const notification = document.createElement('div');
        notification.className = 'safarget-notification';
        notification.innerHTML = `
            <svg width="20" height="20" viewBox="0 0 20 20" fill="none">
                <path d="M10 0C4.5 0 0 4.5 0 10s4.5 10 10 10 10-4.5 10-10S15.5 0 10 0zm-1 15l-5-5 1.41-1.41L9 12.17l7.59-7.59L18 6l-9 9z" fill="white"/>
            </svg>
            <span>${message}</span>
        `;
        document.body.appendChild(notification);
        
        setTimeout(() => {
            notification.style.animation = 'slideOutRight 0.3s ease-out';
            setTimeout(() => notification.remove(), 300);
        }, 3000);
    }
    
    // Monitor video presence
    function checkForVideo() {
        // Check if we're on YouTube
        const isYouTube = window.location.hostname.includes('youtube.com') || 
                         window.location.hostname.includes('youtu.be');
        
        if (!isYouTube) {
            if (floatingButton) {
                floatingButton.remove();
                floatingButton = null;
                currentVideoUrl = null;
            }
            return;
        }
        
        // Get video ID from URL
        let videoId = new URLSearchParams(window.location.search).get('v');
        if (!videoId && window.location.pathname.includes('/embed/')) {
            videoId = window.location.pathname.split('/embed/')[1]?.split('/')[0];
        }
        if (!videoId && window.location.pathname.includes('/shorts/')) {
            videoId = window.location.pathname.split('/shorts/')[1]?.split('/')[0];
        }
        if (!videoId) {
            const meta = document.querySelector('meta[itemprop="videoId"]');
            if (meta) videoId = meta.content;
        }
        
        // Check for video element
        const videoElement = document.querySelector('video.html5-main-video') || 
                           document.querySelector('video');
        
        if (videoId && videoElement) {
            const newUrl = `https://www.youtube.com/watch?v=${videoId}`;
            
            if (newUrl !== currentVideoUrl) {
                currentVideoUrl = newUrl;
                console.log('🎥 Detected YouTube video:', newUrl);
                
                if (!floatingButton) {
                    floatingButton = createFloatingButton();
                }
                
                if (!document.body.contains(floatingButton)) {
                    document.body.appendChild(floatingButton);
                    setTimeout(() => {
                        if (floatingButton) {
                            floatingButton.classList.add('show');
                            console.log('✅ YouTube download button shown');
                        }
                    }, 200);
                }
            }
        } else if (floatingButton && floatingButton.parentNode) {
            floatingButton.classList.remove('show');
            setTimeout(() => {
                if (floatingButton && floatingButton.parentNode) {
                    floatingButton.remove();
                    floatingButton = null;
                    currentVideoUrl = null;
                    console.log('🗑️ Removed YouTube button');
                }
            }, 300);
        }
    }
    
    // Observe page changes
    const observer = new MutationObserver(() => {
        checkForVideo();
    });
    
    // Start observing
    if (document.body) {
        observer.observe(document.body, {
            childList: true,
            subtree: true,
            attributes: true,
            attributeFilter: ['src', 'class', 'id']
        });
        checkForVideo();
    } else {
        document.addEventListener('DOMContentLoaded', () => {
            observer.observe(document.body, {
                childList: true,
                subtree: true,
                attributes: true,
                attributeFilter: ['src', 'class', 'id']
            });
            checkForVideo();
        });
    }
    
    // Monitor URL changes for YouTube SPA
    let lastUrl = location.href;
    const urlObserver = new MutationObserver(() => {
        const url = location.href;
        if (url !== lastUrl) {
            lastUrl = url;
            console.log('🔄 URL changed:', url);
            setTimeout(checkForVideo, 500);
            setTimeout(checkForVideo, 1500);
        }
    });
    
    urlObserver.observe(document, { subtree: true, childList: true });
    
    // Initial and periodic checks
    checkForVideo();
    const periodicChecker = setInterval(() => {
        const isYouTube = window.location.hostname.includes('youtube.com') || 
                         window.location.hostname.includes('youtu.be');
        if (isYouTube) {
            checkForVideo();
        }
    }, 2000);
    
    // Cleanup
    window.addEventListener('beforeunload', () => {
        observer.disconnect();
        urlObserver.disconnect();
        clearInterval(periodicChecker);
    });
    
})();
