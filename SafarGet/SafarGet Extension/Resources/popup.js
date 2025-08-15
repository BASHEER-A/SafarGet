// 🚀 SafarGet Extension - Popup Script

document.addEventListener('DOMContentLoaded', function() {
    console.log('🚀 SafarGet Popup Loaded');
    
    // تحديث الإحصائيات
    updateStats();
    
    // إعداد الأحداث
    setupEventListeners();
    
    // تحديث الحالة
    updateStatus();
});

// 🔴 إعداد الأحداث
function setupEventListeners() {
    // فتح التطبيق
    document.getElementById('openApp').addEventListener('click', function() {
        console.log('Opening SafarGet App...');
        
        // استخدام URL Scheme
        const appUrl = 'safarget://open';
        
        // محاولة فتح التطبيق
        browser.tabs.create({ url: appUrl }).catch(() => {
            console.log('Could not open app URL');
            
            // عرض رسالة للمستخدم
            showNotification('Please open SafarGet App manually', 'info');
        });
    });
    
    // اختبار اكتشاف التحميل
    document.getElementById('testDownload').addEventListener('click', function() {
        console.log('Testing download detection...');
        
        // إرسال رسالة للـ background script
        browser.runtime.sendMessage({
            action: 'testDownload',
            url: 'https://example.com/test.zip'
        }).then(response => {
            if (response && response.success) {
                showNotification('Download detection test successful!', 'success');
            } else {
                showNotification('Download detection test failed', 'error');
            }
        }).catch(error => {
            console.error('Test failed:', error);
            showNotification('Test failed: ' + error.message, 'error');
        });
    });
    
    // مسح الإحصائيات
    document.getElementById('clearStats').addEventListener('click', function() {
        console.log('Clearing statistics...');
        
        browser.storage.local.set({
            downloadsCount: 0,
            pagesCount: 0,
            lastDetection: null
        }).then(() => {
            updateStats();
            showNotification('Statistics cleared!', 'success');
        }).catch(error => {
            console.error('Failed to clear stats:', error);
            showNotification('Failed to clear statistics', 'error');
        });
    });
}

// 🔴 تحديث الإحصائيات
function updateStats() {
    browser.storage.local.get(['downloadsCount', 'pagesCount', 'lastDetection']).then((result) => {
        const downloadsCount = result.downloadsCount || 0;
        const pagesCount = result.pagesCount || 0;
        const lastDetection = result.lastDetection || null;
        
        document.getElementById('downloadsCount').textContent = downloadsCount;
        document.getElementById('pagesCount').textContent = pagesCount;
        
        if (lastDetection) {
            const date = new Date(lastDetection);
            const now = new Date();
            const diff = now - date;
            
            let timeAgo;
            if (diff < 60000) { // أقل من دقيقة
                timeAgo = 'Just now';
            } else if (diff < 3600000) { // أقل من ساعة
                const minutes = Math.floor(diff / 60000);
                timeAgo = `${minutes} minute${minutes > 1 ? 's' : ''} ago`;
            } else if (diff < 86400000) { // أقل من يوم
                const hours = Math.floor(diff / 3600000);
                timeAgo = `${hours} hour${hours > 1 ? 's' : ''} ago`;
            } else {
                const days = Math.floor(diff / 86400000);
                timeAgo = `${days} day${days > 1 ? 's' : ''} ago`;
            }
            
            document.getElementById('lastDetection').textContent = timeAgo;
        } else {
            document.getElementById('lastDetection').textContent = 'Never';
        }
    }).catch(error => {
        console.error('Failed to load stats:', error);
    });
}

// 🔴 تحديث الحالة
function updateStatus() {
    // التحقق من حالة التطبيق
    checkAppStatus().then(isRunning => {
        const statusText = document.getElementById('statusText');
        const statusIndicator = document.querySelector('.status-indicator');
        
        if (isRunning) {
            statusText.textContent = 'App is running and ready';
            statusIndicator.style.background = '#00ff00';
        } else {
            statusText.textContent = 'App not running - click to open';
            statusIndicator.style.background = '#ffaa00';
        }
    }).catch(error => {
        console.error('Failed to check app status:', error);
        const statusText = document.getElementById('statusText');
        statusText.textContent = 'Status unknown';
    });
}

// 🔴 التحقق من حالة التطبيق
async function checkAppStatus() {
    try {
        // محاولة الاتصال بالتطبيق
        const response = await fetch('safarget://ping', { method: 'HEAD' });
        return true;
    } catch (error) {
        return false;
    }
}

// 🔴 عرض الإشعارات
function showNotification(message, type = 'info') {
    // إنشاء عنصر الإشعار
    const notification = document.createElement('div');
    notification.textContent = message;
    
    // تطبيق الأنماط
    Object.assign(notification.style, {
        position: 'fixed',
        top: '10px',
        right: '10px',
        padding: '10px 15px',
        borderRadius: '6px',
        color: 'white',
        fontSize: '12px',
        zIndex: '10000',
        maxWidth: '200px',
        wordWrap: 'break-word',
        animation: 'slideIn 0.3s ease'
    });
    
    // تحديد اللون حسب النوع
    switch (type) {
        case 'success':
            notification.style.background = '#00aa00';
            break;
        case 'error':
            notification.style.background = '#ff0000';
            break;
        case 'warning':
            notification.style.background = '#ffaa00';
            break;
        default:
            notification.style.background = '#0066aa';
    }
    
    // إضافة للصفحة
    document.body.appendChild(notification);
    
    // إزالة بعد 3 ثوان
    setTimeout(() => {
        notification.style.animation = 'slideOut 0.3s ease';
        setTimeout(() => {
            notification.remove();
        }, 300);
    }, 3000);
}

// 🔴 إضافة أنماط الرسوم المتحركة
function addAnimationStyles() {
    if (document.getElementById('popup-animations')) return;
    
    const style = document.createElement('style');
    style.id = 'popup-animations';
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

// 🔴 الاستماع للرسائل من Background Script
browser.runtime.onMessage.addListener((request, sender, sendResponse) => {
    console.log('📨 Popup message received:', request);
    
    switch (request.action) {
        case 'updateStats':
            updateStats();
            sendResponse({ success: true });
            break;
            
        case 'showNotification':
            showNotification(request.message, request.type);
            sendResponse({ success: true });
            break;
            
        default:
            sendResponse({ error: 'Unknown action' });
    }
});

// 🔴 تحديث دوري
setInterval(() => {
    updateStats();
    updateStatus();
}, 5000); // كل 5 ثوان

// إضافة أنماط الرسوم المتحركة
addAnimationStyles();

console.log('✅ SafarGet Popup Ready');


