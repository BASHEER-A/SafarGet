# 🔧 دليل التشخيص - SafarGet Extension

## 🚨 المشكلة: لا يعترض أي رابط

### 🔍 خطوات التشخيص:

#### 1️⃣ فتح صفحة الاختبار البسيطة
```bash
# افتح في Safari
open test-simple.html
```

#### 2️⃣ فتح Developer Console
- اضغط `Cmd + Option + I`
- انتقل إلى تبويب Console
- ابحث عن رسائل SafarGet

#### 3️⃣ التحقق من الرسائل المتوقعة:
```
🚀 SafarGet Extension Starting...
📊 Browser API Check:
  - browser.runtime: ✅ Available
  - safari.extension: ✅ Available
🎯 Download Permission Interceptor Active
✅ Download Permission Interceptor Ready
🧪 Running comprehensive system test...
✅ Test message sent successfully
```

#### 4️⃣ اختبار النقر على الروابط:
- انقر على أي رابط في صفحة الاختبار
- يجب أن ترى رسائل مثل:
```
🔍 Click detected on: A https://example.com/test.zip
🔗 Link clicked: https://example.com/test.zip
📥 Downloadable link detected: https://example.com/test.zip
✅ Intercepting download link: https://example.com/test.zip
🚀 SafarGet: Sending smart download request for: https://example.com/test.zip
```

## 🛠️ حلول المشاكل الشائعة:

### ❌ المشكلة: لا تظهر رسائل SafarGet
**الحل:**
1. تأكد من تفعيل الإضافة في Safari
2. اذهب إلى Safari → Preferences → Extensions
3. تأكد من تفعيل SafarGet Extension

### ❌ المشكلة: browser.runtime غير متوفر
**الحل:**
1. تأكد من تحديث manifest.json
2. أعد بناء الإضافة في Xcode
3. أعد تشغيل Safari

### ❌ المشكلة: لا يعترض الروابط المباشرة
**الحل:**
1. تحقق من دالة `isDownloadableLink`
2. تحقق من دالة `isDirectFileLink`
3. تأكد من أن معالج النقرات يعمل

### ❌ المشكلة: لا يعترض download attribute
**الحل:**
1. تحقق من معالج النقرات
2. تأكد من أن `link.hasAttribute('download')` يعمل
3. تحقق من `e.preventDefault()` و `e.stopPropagation()`

## 🧪 اختبارات إضافية:

### اختبار Alt+Click:
1. اضغط Alt (أو Option)
2. انقر على أي رابط
3. يجب أن يعترض التحميل

### اختبار download attribute:
1. انقر على رابط مع `download` attribute
2. يجب أن يعترض التحميل

### اختبار الروابط المباشرة:
1. انقر على رابط ينتهي بـ `.zip`, `.pdf`, `.mp4`, إلخ
2. يجب أن يعترض التحميل

## 📊 رسائل التشخيص:

### ✅ رسائل النجاح:
```
✅ Download request sent successfully
✅ Intercepting download link
✅ Test message sent successfully
✅ Comprehensive system test completed
```

### ❌ رسائل الخطأ:
```
❌ Error in isDownloadableLink
❌ Error sending download request
❌ Test message failed
❌ No messaging API available
```

## 🔧 إصلاحات سريعة:

### 1️⃣ إعادة تشغيل الإضافة:
```bash
# في Xcode
# Build → Clean Build Folder
# Build → Build
```

### 2️⃣ إعادة تشغيل Safari:
```bash
# أغلق Safari تماماً
# أعد فتح Safari
# تأكد من تفعيل الإضافة
```

### 3️⃣ فحص الأذونات:
```json
{
    "permissions": [
        "nativeMessaging",
        "tabs",
        "storage",
        "activeTab",
        "webRequest"
    ]
}
```

### 4️⃣ فحص manifest.json:
```json
{
    "web_accessible_resources": [{
        "resources": ["download-permission-interceptor.js"],
        "matches": ["*://*/*"]
    }]
}
```

## 📞 إذا لم تحل المشكلة:

### 1️⃣ جمع المعلومات:
- لقطة شاشة من Console
- محتوى manifest.json
- رسائل الخطأ

### 2️⃣ فحص الملفات:
- تأكد من وجود جميع الملفات
- تأكد من صحة الكود
- تأكد من عدم وجود أخطاء syntax

### 3️⃣ اختبار في صفحة مختلفة:
- جرب في موقع آخر
- جرب في وضع التصفح الخاص
- جرب في نافذة جديدة

---

## 🎯 الخلاصة:

إذا اتبعت هذه الخطوات ولم تحل المشكلة، فالمشكلة قد تكون في:
1. إعدادات Safari
2. إصدار macOS
3. تضارب مع إضافات أخرى
4. مشكلة في الكود نفسه

**🔧 تأكد من اختبار كل خطوة بعناية!**
