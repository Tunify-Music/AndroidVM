FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    qemu-system-x86 \
    qemu-utils \
    novnc \
    websockify \
    wget \
    curl \
    net-tools \
    unzip \
    python3 \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /data /iso /novnc

RUN wget https://github.com/novnc/noVNC/archive/refs/heads/master.zip -O /tmp/novnc.zip && \
    unzip /tmp/novnc.zip -d /tmp && \
    mv /tmp/noVNC-master/* /novnc && \
    rm -rf /tmp/novnc.zip /tmp/noVNC-master

# Direct download link for Android-x86 (9.0 Pie)
ENV ISO_URL="https://archive.org/download/sjarb_android_9.0r2/android-x86_64-9.0-r2.iso"

RUN echo '#!/bin/bash\n\
set -e\n\
\n\
# Check for KVM support\n\
if [ -e /dev/kvm ]; then\n\
  echo "✅ KVM acceleration available"\n\
  KVM_ARG="-enable-kvm"\n\
  CPU_ARG="host"\n\
  MEMORY="4G"\n\
  SMP_CORES=4\n\
else\n\
  echo "⚠️  KVM not available - using slower emulation mode"\n\
  KVM_ARG=""\n\
  CPU_ARG="qemu64"\n\
  MEMORY="2G"\n\
  SMP_CORES=2\n\
fi\n\
\n\
# Download ISO if needed\n\
if [ ! -f "/iso/os.iso" ]; then\n\
  echo "📥 Downloading Android-x86 ISO..."\n\
  wget -q --show-progress "$ISO_URL" -O "/iso/os.iso"\n\
fi\n\
\n\
# Create disk image if not exists (32GB is plenty for Android)\n\
if [ ! -f "/data/disk.qcow2" ]; then\n\
  echo "💽 Creating 32GB virtual disk..."\n\
  qemu-img create -f qcow2 "/data/disk.qcow2" 32G\n\
fi\n\
\n\
# Android-specific boot parameters\n\
BOOT_ORDER="-boot order=c,menu=on"\n\
if [ ! -s "/data/disk.qcow2" ] || [ $(stat -c%s "/data/disk.qcow2") -lt 1048576 ]; then\n\
  echo "🚀 First boot - installing Android from ISO"\n\
  BOOT_ORDER="-boot order=d,menu=on"\n\
fi\n\
\n\
echo "⚙️ Starting Android VM with ${SMP_CORES} CPU cores and ${MEMORY} RAM"\n\
\n\
# Start QEMU with Android-compatible architecture settings\n\
qemu-system-x86_64 \\\n\
  $KVM_ARG \\\n\
  -machine q35,accel=kvm:tcg \\\n\
  -cpu $CPU_ARG \\\n\
  -m $MEMORY \\\n\
  -smp $SMP_CORES \\\n\
  -vga std \\\n\
  -usb -device usb-tablet \\\n\
  $BOOT_ORDER \\\n\
  -drive file=/data/disk.qcow2,format=qcow2 \\\n\
  -drive file=/iso/os.iso,media=cdrom \\\n\
  -netdev user,id=net0,hostfwd=tcp::5555-:5555 \\\n\
  -device e1000,netdev=net0 \\\n\
  -display vnc=:0 \\\n\
  -name "Android_VM" &\n\
\n\
# Start noVNC\n\
sleep 5\n\
websockify --web /novnc 6080 localhost:5900 &\n\
\n\
echo "===================================================="\n\
echo "🌐 Connect via Web Browser: http://localhost:6080"\n\
echo "🔌 Connect via ADB (Android Debug Bridge): localhost:5555"\n\
echo "❗ First boot instruction: Select 'Installation - Install Android-x86 to harddisk'"\n\
echo "===================================================="\n\
\n\
tail -f /dev/null\n' > /start.sh && chmod +x /start.sh

VOLUME ["/data", "/iso"]
EXPOSE 6080 5555
CMD ["/start.sh"]
