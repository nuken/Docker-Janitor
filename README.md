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
