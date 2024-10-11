# راهنمای کامل نصب و استفاده از DNS Forwarder

## مقدمه
این راهنما شما را در مراحل نصب، پیکربندی و استفاده از DNS Forwarder راهنمایی می‌کند. DNS Forwarder یک ابزار قدرتمند برای مدیریت و کنترل ترافیک DNS در شبکه شما است.

## پیش‌نیازها
- سرور لینوکس با نسخه اوبونتو 20 یا 22
- دسترسی root یا sudo به سرور
- اتصال اینترنت پایدار

## مراحل نصب

### 1. به‌روزرسانی سیستم
ابتدا سیستم خود را به‌روزرسانی کنید:

```bash
apt update -y && apt upgrade -y
```

### 2. دانلود و اجرای اسکریپت نصب
پس از به‌روزرسانی، اسکریپت نصب را دانلود و اجرا کنید:

```bash
curl -o install.sh https://raw.githubusercontent.com/smaghili/dnsforwarder/main/install.sh && chmod +x install.sh && ./install.sh
```

این دستور به طور خودکار تمامی پیش‌نیازها و پکیج‌های مورد نیاز را نصب می‌کند.

### 3. پیکربندی پنل مدیریت
در حین نصب، از شما خواسته می‌شود:

1. یک نام کاربری دلخواه وارد کنید و Enter بزنید.
2. یک رمز عبور دلخواه برای پنل مدیریت وارد کنید.

**توجه:** به دلایل امنیتی، رمز عبور هنگام تایپ نمایش داده نمی‌شود، اما در حال ثبت شدن است.

### 4. اتمام نصب
پس از اتمام نصب، پیامی مشابه زیر دریافت خواهید کرد:

```
Set your clients to use this server's IP as their primary DNS:
185.226.92.168
Access the web panel at: http://185.226.92.168:5000
Installation complete. You can now use 'dnsforwarder' command to control the DNS forwarder.
To manage IP restrictions, use:
  dnsforwarder enable iplimit     # To enable IP restriction
  dnsforwarder disable iplimit    # To disable IP restriction
  dnsforwarder allow <ip>         # To add an IP to the allowed list
  dnsforwarder deny <ip>          # To remove an IP from the allowed list
  dnsforwarder list               # To list allowed IPs
To uninstall DNS forwarder completely, use:
  dnsforwarder uninstall
Installation and configuration complete.
```

## استفاده از DNS Forwarder

پس از نصب، می‌توانید از دستور `dnsforwarder` برای مدیریت سرویس استفاده کنید. نحوه استفاده از این دستور به شرح زیر است:

```
root@None:~# dnsforwarder 
Usage: dnsforwarder {start|stop|restart|status|set {shekan|radar|anti403|custom}|allow <ip>|deny <ip>|list|enable iplimit|disable iplimit|uninstall}
```

### توضیح دستورات:

- `start`: سرویس DNS forwarder را شروع می‌کند.
- `stop`: سرویس DNS forwarder را متوقف می‌کند.
- `restart`: سرویس DNS forwarder را مجدداً راه‌اندازی می‌کند.
- `status`: وضعیت فعلی سرویس DNS forwarder را نمایش می‌دهد.
- `set`: تنظیمات DNS را تغییر می‌دهد:
  - `shekan`: از سرورهای DNS Shekan استفاده می‌کند.
  - `radar`: از سرورهای DNS Radar استفاده می‌کند.
  - `anti403`: از سرورهای DNS Anti403 استفاده می‌کند.
  - `custom`: به شما اجازه می‌دهد سرورهای DNS سفارشی خود را تنظیم کنید.
- `allow <ip>`: یک آدرس IP را به لیست مجاز اضافه می‌کند.
- `deny <ip>`: یک آدرس IP را از لیست مجاز حذف می‌کند.
- `list`: لیست IP های مجاز را نمایش می‌دهد.
- `enable iplimit`: محدودیت IP را فعال می‌کند.
- `disable iplimit`: محدودیت IP را غیرفعال می‌کند.
- `uninstall`: DNS forwarder را به طور کامل حذف می‌کند.

### مثال‌های کاربردی:

1. برای شروع سرویس:
   ```
   dnsforwarder start
   ```

2. برای تغییر تنظیمات DNS به Shekan:
   ```
   dnsforwarder set shekan
   ```

3. برای اضافه کردن یک IP به لیست مجاز:
   ```
   dnsforwarder allow 192.168.1.100
   ```

4. برای فعال کردن محدودیت IP:
   ```
   dnsforwarder enable iplimit
   ```

5. برای مشاهده وضعیت سرویس:
   ```
   dnsforwarder status
   ```

## دسترسی به پنل مدیریت وب

برای دسترسی به پنل مدیریت وب، از مرورگر خود به آدرس `http://IP-ADDRESS:5000` مراجعه کنید (IP-ADDRESS را با آدرس IP سرور خود جایگزین کنید). از نام کاربری و رمز عبوری که در زمان نصب تعیین کردید، استفاده کنید.

## نکات امنیتی

1. حتماً رمز عبور قوی برای پنل مدیریت انتخاب کنید.
2. در صورت نیاز، از محدودیت IP استفاده کنید تا فقط IP های مجاز بتوانند به سرویس دسترسی داشته باشند.
3. به طور منظم لاگ‌های سیستم را بررسی کنید.

## حذف کامل

اگر می‌خواهید DNS forwarder را به طور کامل حذف کنید، از دستور زیر استفاده کنید:

```bash
dnsforwarder uninstall
```

این دستور تمام تنظیمات و فایل‌های مربوط به DNS forwarder را حذف خواهد کرد.

## پشتیبانی

در صورت بروز هرگونه مشکل یا نیاز به راهنمایی بیشتر، لطفاً به مخزن GitHub پروژه مراجعه کنید یا با تیم پشتیبانی تماس بگیرید.

## نتیجه‌گیری

با استفاده از این راهنما، شما باید قادر به نصب، پیکربندی و استفاده از DNS Forwarder باشید. این ابزار می‌تواند به شما در مدیریت بهتر ترافیک DNS و بهبود امنیت شبکه کمک کند.
