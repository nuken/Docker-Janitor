# 🐳 Docker Janitor Command Center

A lightweight, containerized web dashboard for managing and cleaning up Docker clutter.

Instead of relying on background cron jobs or running destructive CLI commands blindly, this Command Center provides a visual interface to safely manage stopped containers, unused images, orphaned volumes, build caches, and overgrown log files.


## ☰ Features

* **Organized Dashboard:** View lists of stopped containers, unused/dangling images, and orphaned volumes before you delete them.
* **Targeted Cleanup:** Action buttons are grouped by section, allowing you to prune specific resources (e.g., just dangling images, or just stopped containers).
* **💿 Volume Management:** Safely identify and delete unattached volumes to reclaim massive amounts of disk space.
* **🛠 Build Cache Clearing:** Flush hidden, intermediate build layers with a single click.
* **⏱ Zero-Downtime Log Truncation:** Shrinks overgrown container JSON log files to 0 bytes *without* needing to restart the running containers.
* **🛡️ Safety Whitelist:** Protect specific containers, images, and volumes from accidental deletion using Docker labels.

## 👻 How it Works: The "Ghost Worker" Architecture

To keep the Command Center lightweight and secure, it does not run heavy background processes.
* Standard cleanup commands are executed instantly via the Docker Engine API.
* For complex tasks like **Log Truncation**, the Janitor uses a "Ghost Worker" pattern. It spawns a microscopic Alpine Linux container, mounts the host's log directory, executes a `truncate` command on the files, and immediately self-destructs, leaving zero trace.


## 🔧 Project Structure

Ensure your `docker-janitor-ui` directory contains these three files:
1.  `app.py` (The Flask Web Application)
2.  `Dockerfile` (Build instructions for the Python environment)
3.  `docker-compose.yml` (Handles port mapping and socket mounting)

## ⚙️ Installation & Usage

You do not need to build this from source. The image is automatically built and hosted on the GitHub Container Registry.

1. **Create a `docker-compose.yml` file:**

Create a new folder on your machine, and save the following into a `docker-compose.yml` file:

```yaml
services:
  janitor-ui:
    image: ghcr.io/nuken/docker-janitor:latest
    container_name: docker-janitor
    restart: unless-stopped
    ports:
      - "5000:5000"
    volumes:
      # Required: Gives the Janitor permission to execute cleanup commands
      - /var/run/docker.sock:/var/run/docker.sock
```
2.  **Start the Command Center:**

Open your terminal in that folder and run:

```Bash
docker compose up -d
```

3.  **Access the Dashboard:**

Open your web browser and navigate to:

👉 http://localhost:5000 (or `http://<your-server-ip>:5000`)

## 🛡️ The Safety Whitelist (Protecting Important Data)

You can protect any container, image, or volume from being deleted (even if you hit the "Nuke System" button) by adding a specific label to it. Items with this label will appear in the UI with a **🛡️ Protected** badge.

**Label Key:** `janitor.skip`
**Label Value:** `true`

### Option A: In `docker-compose.yml` (Recommended)
Add the label to any service you want to protect:

```yaml
services:
  my-database:
    image: postgres:13
    labels:
      - "janitor.skip=true"

```

## 🗜️ WSL Disk Optimizer (Windows Only)

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
