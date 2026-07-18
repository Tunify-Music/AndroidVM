FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install core emulation dependencies and graphical pipeline tools
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

# Download stable noVNC build to patch mobile touch control crashes
RUN wget https://github.com/novnc/noVNC/archive/refs/tags/v1.5.0.zip -O /tmp/novnc.zip && \
    unzip /tmp/novnc.zip -d /tmp && \
    mv /tmp/noVNC-1.5.0/* /novnc && \
    rm -rf /tmp/novnc.zip /tmp/noVNC-1.5.0

# Android-x86 9.0 Pie (Stable Release)
ENV ISO_URL="https://archive.org/download/sjarb_android_9.0r2/android-x86_64-9.0-r2.iso"

# Generate internal launcher framework configuration script
RUN echo '#!/bin/bash\n\
set -e\n\
\n\
# 1. KVM Hardware Virtualization Check\n\
if [ -e /dev/kvm ]; then\n\
  echo "✅ KVM hardware acceleration is available"\n\
  KVM_ARG="-enable-kvm"\n\
  CPU_ARG="host"\n\
  MEMORY="2G"\n\
  SMP_CORES=2\n\
else\n\
  echo "⚠️ KVM not available - software emulation mode active"\n\
  KVM_ARG=""\n\
  CPU_ARG="qemu64"\n\
  SMP_CORES=1\n\
  \n\
  # 2. Smart Memory Allocator (Differentiates Render vs Cloud Shell limits)\n\
  TOTAL_SYS_KB=$(grep MemTotal /proc/meminfo | tr -s " " | cut -d" " -f2)\n\
  if [ "$TOTAL_SYS_KB" -lt 1500000 ]; then\n\
    echo "🚨 Low RAM detected (<1.5GB). Adjusting memory matrix for Render..."\n\
    MEMORY="300M"\n\
  else\n\
    echo "🚀 Standard RAM detected (>1.5GB). Adjusting memory matrix for Cloud Shell..."\n\
    MEMORY="1.5G"\n\
  fi\n\
fi\n\
\n\
# 3. Handle Installation ISO Deployment\n\
if [ ! -f "/iso/os.iso" ]; then\n\
  echo "📥 Downloading Operating System image pipeline..."\n\
  wget -q --show-progress "$ISO_URL" -O "/iso/os.iso"\n\
fi\n\
\n\
# 4. Storage Block Architecture Layout Creation\n\
if [ ! -f "/data/disk.qcow2" ]; then\n\
  echo "💽 Structuring virtual workspace filesystem block..."\n\
  qemu-img create -f qcow2 "/data/disk.qcow2" 16G\n\
fi\n\
\n\
# 5. Determine Boot Priority Paths\n\
BOOT_ORDER="-boot order=c,menu=on"\n\
if [ ! -s "/data/disk.qcow2" ] || [ $(stat -c%s "/data/disk.qcow2") -lt 1048576 ]; then\n\
  echo "🚀 First boot initialization: Mapping target to setup medium..."\n\
  BOOT_ORDER="-boot order=d,menu=on"\n\
fi\n\
\n\
echo "⚙️ Initializing Android Emulator instance (${SMP_CORES} Core, ${MEMORY} RAM)..."\n\
\n\
# 6. Execute QEMU Virtual Machine runtime layer\n\
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
sleep 5\n\
# 7. Bind interactive Web Engine proxy to network socket interface\n\
websockify --web /novnc 8080 localhost:5900 &\n\
\n\
echo "===================================================="\n\
echo "🌐 Cloud Core Processing Engine Fully Activated!"\n\
echo "===================================================="\n\
\n\
tail -f /dev/null\n' > /start.sh && chmod +x /start.sh

VOLUME ["/data", "/iso"]
EXPOSE 8080 5555
CMD ["/start.sh"]
