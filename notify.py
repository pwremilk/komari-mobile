import os, time, urllib.request, urllib.parse
tok, chat = os.environ.get("TG_TOKEN", ""), os.environ.get("TG_CHAT", "")
if not tok:
    raise SystemExit("no NANOMUSE_TG_TOKEN secret")
st = os.environ.get("STATUS", "?")
run = os.environ.get("RUN_URL", "")
commit = (os.environ.get("COMMIT") or "")[:7]
name = os.environ.get("IPA_FILE", "?")
sz = 0
p = os.path.join(os.getcwd(), name)
if os.path.exists(p):
    sz = os.path.getsize(p) / 1e6
if os.environ.get("QUEUE") == "1":
    msg = ("🚦 <b>Komari-Mobile iOS16 构建已入队</b>\n"
           "🔖 commit %s\n"
           "⏳ macOS runner 排队+编译约 10-25 分钟，完成后另发结果通知\n"
           "🔗 %s") % (commit, run)
elif st == "success":
    msg = ("✅ <b>Komari-Mobile iOS16 编译完成（未签名）</b>\n"
           "📦 %s（%.1f MB）\n"
           "🔖 commit %s\n"
           "📥 下载：运行页 → Artifacts → Komari-Mobile-ios16-unsigned\n"
           "🔗 %s\n"
           "ℹ️ 未签名 ipa 需 TrollStore / 自签后安装") % (name, sz, commit, run)
else:
    msg = ("🔴 <b>Komari-Mobile iOS16 编译失败</b>（%s）\n"
           "🔖 commit %s\n🔗 %s") % (st, commit, run)
for i in range(15):
    try:
        req = urllib.request.Request(
            "https://api.telegram.org/bot%s/sendMessage" % tok,
            data=urllib.parse.urlencode(
                {"chat_id": chat, "text": msg, "parse_mode": "HTML"}).encode())
        urllib.request.urlopen(req, timeout=15)
        print("notified")
        break
    except Exception as e:
        print("retry", i, e)
        time.sleep(8)
