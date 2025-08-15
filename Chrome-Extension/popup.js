// SafarGet Multilingual Popup Script
document.addEventListener('DOMContentLoaded', function() {
    console.log('🌍 SafarGet Multilingual Popup loading...');
    
    // نظام الترجمة
    const translations = {
        en: {
            subtitle: "Download Manager",
            status: {
                connected: "Connected",
                disconnected: "Disconnected"
            },
            interception: "Interception",
            keyboard_hint: "Press Space to toggle"
        },
        ar: {
            subtitle: "مدير التحميلات",
            status: {
                connected: "متصل",
                disconnected: "غير متصل"
            },
            interception: "الاعتراض",
            keyboard_hint: "اضغط مسافة للتبديل"
        }
    };
    
    // العناصر
    const statusDot = document.getElementById('statusDot');
    const statusText = document.getElementById('statusText');
    const toggleSection = document.getElementById('toggleSection');
    const toggleIcon = document.getElementById('toggleIcon');
    const modernToggle = document.getElementById('modernToggle');
    const languageToggle = document.getElementById('languageToggle');
    
    // الحالة الحالية
    let isConnected = false;
    let isInterceptionEnabled = true;
    let currentLanguage = 'en';
    
    // تحديد اللغة حسب النظام
    function detectSystemLanguage() {
        const systemLang = navigator.language || navigator.userLanguage;
        console.log('🌍 System language detected:', systemLang);
        
        // فحص اللغات العربية
        const arabicLanguages = ['ar', 'ar-SA', 'ar-EG', 'ar-AE', 'ar-MA', 'ar-IQ', 'ar-KW', 'ar-LY', 'ar-TN', 'ar-OM', 'ar-YE', 'ar-SY', 'ar-JO', 'ar-LB', 'ar-PS', 'ar-BH', 'ar-QA', 'ar-DZ', 'ar-MR', 'ar-SD'];
        
        if (arabicLanguages.some(lang => systemLang.toLowerCase().startsWith(lang))) {
            return 'ar';
        }
        
        return 'en'; // الافتراضي
    }
    
    // تطبيق الترجمة
    function applyTranslations(lang) {
        currentLanguage = lang;
        const t = translations[lang];
        
        // تحديث جميع العناصر المترجمة
        document.querySelectorAll('[data-i18n]').forEach(element => {
            const key = element.getAttribute('data-i18n');
            const keys = key.split('.');
            let value = t;
            
            for (const k of keys) {
                value = value && value[k];
            }
            
            if (value) {
                element.textContent = value;
            }
        });
        
        // تحديث اتجاه النص
        document.body.className = lang === 'ar' ? 'rtl' : 'ltr';
        document.documentElement.lang = lang;
        
        // تحديث زر اللغة
        languageToggle.textContent = lang === 'ar' ? 'ع' : 'EN';
        
        // حفظ اللغة المختارة
        chrome.storage.sync.set({ selectedLanguage: lang });
        
        console.log('🔄 Language applied:', lang);
    }
    
    // تبديل اللغة
    function toggleLanguage() {
        const newLang = currentLanguage === 'en' ? 'ar' : 'en';
        applyTranslations(newLang);
        
        // تأثير تغيير اللغة
        document.body.style.transform = 'rotateY(180deg)';
        setTimeout(() => {
            document.body.style.transform = 'rotateY(0deg)';
        }, 300);
    }
    
    // تهيئة اللغة
    function initializeLanguage() {
        chrome.storage.sync.get(['selectedLanguage'], result => {
            let language;
            
            if (result.selectedLanguage) {
                // استخدم اللغة المحفوظة
                language = result.selectedLanguage;
                console.log('💾 Using saved language:', language);
            } else {
                // اكتشف لغة النظام
                language = detectSystemLanguage();
                console.log('🔍 Using detected language:', language);
            }
            
            applyTranslations(language);
        });
    }
    
    // تهيئة الإعدادات الافتراضية
    function initializeSettings() {
        chrome.storage.sync.get(['interceptDownloads'], result => {
            if (result.interceptDownloads === undefined) {
                chrome.storage.sync.set({ interceptDownloads: true }, () => {
                    console.log('✅ Default interception enabled');
                    isInterceptionEnabled = true;
                    updateToggleState();
                });
            } else {
                isInterceptionEnabled = result.interceptDownloads;
                updateToggleState();
            }
        });
    }
    
    // فحص حالة الاتصال
    function checkConnection() {
        chrome.runtime.sendMessage({ type: 'checkConnection' }, response => {
            const newConnectionState = response && response.connected;
            
            if (isConnected !== newConnectionState) {
                isConnected = newConnectionState;
                updateConnectionStatus();
            }
        });
    }
    
    // تحديث حالة الاتصال
    function updateConnectionStatus() {
        statusDot.classList.remove('connected', 'disconnected');
        
        if (isConnected) {
            statusDot.classList.add('connected');
            statusText.textContent = translations[currentLanguage].status.connected;
            
            // تأثير نجاح الاتصال
            document.body.style.filter = 'brightness(1.1)';
            setTimeout(() => {
                document.body.style.filter = 'brightness(1)';
            }, 300);
        } else {
            statusDot.classList.add('disconnected');
            statusText.textContent = translations[currentLanguage].status.disconnected;
            
            // تأثير فقدان الاتصال - لكن لا نعطل المفتاح
            document.body.style.filter = 'brightness(0.9)';
            setTimeout(() => {
                document.body.style.filter = 'brightness(1)';
            }, 300);
        }
    }
    
    // تحديث حالة مفتاح التبديل
    function updateToggleState() {
        modernToggle.classList.toggle('active', isInterceptionEnabled);
        
        if (isInterceptionEnabled) {
            toggleIcon.textContent = '⚡';
            toggleIcon.style.background = 'linear-gradient(135deg, #2ed573, #17c0eb)';
        } else {
            toggleIcon.textContent = '⏸️';
            toggleIcon.style.background = 'linear-gradient(135deg, #ff4757, #ff3742)';
        }
        
        // تأثير تغيير الحالة
        toggleIcon.style.transform = 'scale(1.1) rotate(10deg)';
        setTimeout(() => {
            toggleIcon.style.transform = 'scale(1) rotate(0deg)';
        }, 200);
    }
    
    // حفظ إعداد الاعتراض
    function saveInterceptionSetting(enabled) {
        chrome.storage.sync.set({ interceptDownloads: enabled }, () => {
            console.log('💾 Interception setting saved:', enabled);
            isInterceptionEnabled = enabled;
            updateToggleState();
            
            // تأثير الحفظ
            const originalBg = document.body.style.background;
            document.body.style.background = enabled ? 
                'linear-gradient(135deg, #2ed573 0%, #17c0eb 100%)' : 
                'linear-gradient(135deg, #ff4757 0%, #ff3742 100%)';
            
            setTimeout(() => {
                document.body.style.background = originalBg || 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)';
            }, 400);
        });
    }
    
    // إنشاء تأثير Ripple
    function createRipple(event, element) {
        const rect = element.getBoundingClientRect();
        const size = Math.max(rect.width, rect.height);
        const x = event.clientX - rect.left - size / 2;
        const y = event.clientY - rect.top - size / 2;
        
        const ripple = document.createElement('div');
        ripple.className = 'ripple';
        ripple.style.cssText = `
            width: ${size}px;
            height: ${size}px;
            left: ${x}px;
            top: ${y}px;
            position: absolute;
            border-radius: 50%;
            background: rgba(255,255,255,0.4);
            transform: scale(0);
            animation: ripple 0.6s linear;
            pointer-events: none;
        `;
        
        element.style.position = 'relative';
        element.appendChild(ripple);
        
        setTimeout(() => {
            if (ripple.parentNode) {
                ripple.remove();
            }
        }, 600);
    }
    
    // معالجة النقر على زر اللغة
    languageToggle.addEventListener('click', function(e) {
        e.stopPropagation();
        
        // تأثير النقر
        this.style.transform = 'scale(0.9) rotate(15deg)';
        setTimeout(() => {
            this.style.transform = 'scale(1) rotate(0deg)';
        }, 150);
        
        toggleLanguage();
    });
    
    // معالجة النقر على مفتاح التبديل
    toggleSection.addEventListener('click', function(e) {
        // إنشاء تأثير ripple
        createRipple(e, this);
        
        // تبديل الحالة - يعمل دائماً حتى لو لم يكن متصل
        const newState = !isInterceptionEnabled;
        saveInterceptionSetting(newState);
        
        // تأثير تأكيد النقر
        this.style.transform = 'scale(0.98)';
        setTimeout(() => {
            this.style.transform = 'scale(1)';
        }, 100);
        
        // إظهار رسالة إذا لم يكن متصل
        if (!isConnected && newState) {
            console.log('⚠️ Interception enabled but not connected to SafarGet - files will be stored locally');
        }
    });
    
    // تأثيرات الـ hover - تعمل دائماً
    toggleSection.addEventListener('mouseenter', function() {
        this.style.transform = 'translateY(-1px) scale(1.01)';
    });
    
    toggleSection.addEventListener('mouseleave', function() {
        this.style.transform = 'translateY(0) scale(1)';
    });
    
    // مراقبة تغييرات الإعدادات
    chrome.storage.onChanged.addListener((changes) => {
        if (changes.interceptDownloads) {
            isInterceptionEnabled = changes.interceptDownloads.newValue;
            updateToggleState();
        }
        if (changes.selectedLanguage) {
            applyTranslations(changes.selectedLanguage.newValue);
        }
    });
    
    // اختصارات لوحة المفاتيح
    document.addEventListener('keydown', function(e) {
        if (e.code === 'Space') {
            e.preventDefault();
            toggleSection.click();
        } else if (e.code === 'KeyL' && (e.ctrlKey || e.metaKey)) {
            e.preventDefault();
            languageToggle.click();
        }
    });
    
    // فحص دوري للاتصال (كل 2 ثانية)
    setInterval(checkConnection, 2000);
    
    // التهيئة الأولية
    initializeLanguage(); // تهيئة اللغة أولاً
    initializeSettings();
    checkConnection();
    
    // تأثير تحميل أولي
    document.body.style.opacity = '0';
    document.body.style.transform = 'scale(0.95)';
    document.body.style.transition = 'all 0.3s ease';
    
    setTimeout(() => {
        document.body.style.opacity = '1';
        document.body.style.transform = 'scale(1)';
    }, 100);
    
    // تحديث الترجمات عند تغيير حالة الاتصال
    const originalUpdateConnectionStatus = updateConnectionStatus;
    updateConnectionStatus = function() {
        originalUpdateConnectionStatus.call(this);
        // إعادة تطبيق الترجمات للحالة الجديدة
        statusText.textContent = isConnected ? 
            translations[currentLanguage].status.connected : 
            translations[currentLanguage].status.disconnected;
    };
    
    console.log('🌍✨ SafarGet Multilingual Popup ready!');
});
