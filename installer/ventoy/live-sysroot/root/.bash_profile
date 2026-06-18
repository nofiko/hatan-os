# HATAN OS — تشغيل التثبيت تلقائياً عند أول دخول root
if [[ "$(tty)" == "/dev/tty1" ]] && [[ ! -f /tmp/.hatan-autoinstall-done ]]; then
    echo ""
    echo "  HATAN OS — بدء التثبيت التلقائي..."
    echo "  لا تطفئ الجهاز. قد يستغرق 30-60 دقيقة."
    echo ""
    /usr/local/bin/hatan-autoinstall.sh
fi
