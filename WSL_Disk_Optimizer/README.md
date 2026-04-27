# Docker Janitor: Windows WSL Toolkit

A companion PowerShell toolkit for Windows users running Docker Desktop via WSL2. 

While the main Docker Janitor web UI is excellent at cleaning up containers and images inside the Docker environment, it cannot control the underlying Windows host. This toolkit bridges that gap by providing system-level optimizations to reclaim lost disk space, boost file I/O speed, and prevent Docker from starving Windows of RAM and CPU.

## Features

This interactive script provides a menu with the following optimization tools:

### 1. Compact WSL Virtual Disk (Reclaim Space)
When you delete containers and images, the space is freed *inside* Linux, but the Windows virtual disk (`ext4.vhdx`) never shrinks automatically. 
* **What it does:** Safely shuts down Docker/WSL and uses a background `diskpart` process to compact the virtual disk, returning those gigabytes back to your Windows `C:\` drive.

### 2. Boost I/O Speed (Defender Exclusions)
Windows Defender scanning every read/write operation inside your containers creates massive performance bottlenecks, especially when using bind mounts.
* **What it does:** Adds targeted Windows Defender exclusions for your Docker virtual disk (`ext4.vhdx`) and the background processes (`com.docker.backend.exe`, `wsl.exe`) responsible for bridging the file systems.
* **Security Warning:** This trades security for speed. Defender will no longer scan your Docker disk for malware. If a container is compromised or you download a malicious image, Defender will not intervene.

### 3. Resource & Network Management (.wslconfig)
By default, WSL2 can consume all of your system's RAM and CPU, leading to system lockups. Furthermore, WSL's default NAT networking can cause localhost port-forwarding delays.
* **What it does:** Automatically detects your host system's hardware and generates an optimized `.wslconfig` file. It safely caps WSL to 50% of your total RAM and leaves 2 CPU cores free for Windows. On Windows 11, it also enables "Mirrored Networking" for significantly faster throughput.
* **Workload Warning:** Hard RAM limits prevent Windows starvation, but if you run exceptionally heavy container workloads (like compiling massive codebases), your containers could crash with Out-Of-Memory (OOM) errors. Mirrored networking may also break custom network bridges that rely on WSL's default IP architecture.

### 4. Undo / Revert Optimizations
Changed your mind? The toolkit includes a built-in rollback feature.
* **What it does:** Instantly removes the Defender exclusions and deletes the generated `.wslconfig` file, returning your system to its default state.

## How to Use

1. Navigate to the `WSL_Disk_Optimizer` directory on your Windows machine.
2. Right-click on the `Optimize-DockerWSL.ps1` file and select **Run with PowerShell**.
3. *Note: The script requires Administrator privileges to manage disks and Defender settings. If you are not running as Admin, it will automatically prompt you for permission and relaunch itself.*
4. Follow the interactive terminal menu to apply individual optimizations, apply them all at once, or revert previous changes.