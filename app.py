from flask import Flask, render_template_string, redirect, url_for, flash
import docker

app = Flask(__name__)
app.secret_key = 'supersecretkey'

try:
    client = docker.from_env()
except Exception as e:
    print(f"Error connecting to Docker: {e}")

# --- HTML TEMPLATE ---
HTML = """
<!DOCTYPE html>
<html>
<head>
    <title>Docker Janitor - Command Center</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background: #1e1e2e; color: #cdd6f4; margin: 0; padding: 20px; }
        .container { max-width: 1000px; margin: 0 auto; background: #313244; padding: 30px; border-radius: 12px; box-shadow: 0 4px 15px rgba(0,0,0,0.3); }
        h1 { color: #89b4fa; text-align: center; }

        /* Section Headers with Flexbox for inline buttons */
        .section-header { display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid #45475a; padding-bottom: 10px; margin-top: 30px; }
        .section-header h2 { color: #f5c2e7; margin: 0; border: none; padding: 0; }
        .section-actions { display: flex; gap: 10px; }

        table { width: 100%; border-collapse: collapse; margin-top: 15px; background: #181825; border-radius: 8px; overflow: hidden; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #313244; }
        th { background: #45475a; color: #fff; }
        tr:hover { background: #313244; }
        .empty-msg { padding: 15px; font-style: italic; color: #6c7086; text-align: center;}

        .protected { color: #a6e3a1; font-weight: bold; }
        .risk { color: #f38ba8; }
        .tag-dangling { color: #f9e2af; font-family: monospace; }
        .tag-named { color: #89dceb; font-family: monospace; }

        /* Global Top Buttons */
        .top-actions { display: flex; flex-wrap: wrap; gap: 10px; justify-content: center; margin-bottom: 20px; padding-bottom: 20px; border-bottom: 2px dashed #45475a;}

        .btn { padding: 10px 16px; border: none; border-radius: 6px; cursor: pointer; font-weight: bold; color: #1e1e2e; transition: 0.2s;}
        .btn:hover { opacity: 0.8; transform: translateY(-2px); }

        .btn-scan { background: #89b4fa; text-decoration: none; }
        .btn-con { background: #a6e3a1; }
        .btn-img-dangling { background: #fab387; }
        .btn-img-all { background: #eba0ac; }
        .btn-vol { background: #cba6f7; }
        .btn-build { background: #94e2d5; }
        .btn-log { background: #f5c2e7; }
        .btn-nuke { background: #f38ba8; }

        .flash { padding: 15px; margin-bottom: 20px; border-radius: 6px; background: #a6e3a1; color: #1e1e2e; text-align: center; font-weight: bold;}
    </style>
</head>
<body>

<div class="container">
    <h1>🐳 Docker Janitor Command Center</h1>

    <div class="top-actions">
        <a href="/" class="btn btn-scan">🔄 Rescan Dashboard</a>

        <form action="/prune_builds" method="post" style="display:inline;">
            <button class="btn btn-build">🏗️ Clear Build Cache</button>
        </form>

        <form action="/truncate_logs" method="post" style="display:inline;" onsubmit="return confirm('This will shrink all container logs to 0 bytes without stopping the containers. Proceed?');">
            <button class="btn btn-log">📄 Truncate Logs</button>
        </form>

        <form action="/prune_system" method="post" style="display:inline;" onsubmit="return confirm('WARNING: This deletes unprotected Containers, Networks, Images, and Build Cache. (Volumes are kept safe). Continue?');">
            <button class="btn btn-nuke">☢️ Nuke System</button>
        </form>
    </div>

    {% with messages = get_flashed_messages() %}
        {% if messages %}
            {% for message in messages %}
                <div class="flash">{{ message }}</div>
            {% endfor %}
        {% endif %}
    {% endwith %}

    <div class="section-header">
        <h2>🛑 Stopped Containers</h2>
        <div class="section-actions">
            <form action="/prune_containers" method="post">
                <button class="btn btn-con">📦 Prune Stopped Containers</button>
            </form>
        </div>
    </div>
    {% if containers %}
    <table>
        <tr><th>ID</th><th>Name</th><th>Status</th><th>Whitelist</th></tr>
        {% for c in containers %}
        <tr>
            <td>{{ c.short_id }}</td>
            <td>{{ c.name }}</td>
            <td>{{ c.status }}</td>
            <td>
                {% if c.labels.get('janitor.skip') == 'true' %}
                    <span class="protected">🛡️ Protected</span>
                {% else %}
                    <span class="risk">⚠️ Ready to Prune</span>
                {% endif %}
            </td>
        </tr>
        {% endfor %}
    </table>
    {% else %}
        <div class="empty-msg">No stopped containers found.</div>
    {% endif %}

    <div class="section-header">
        <h2>⛔ Unused Images</h2>
        <div class="section-actions">
            <form action="/prune_dangling_images" method="post">
                <button class="btn btn-img-dangling">🧹 Prune Dangling</button>
            </form>
            <form action="/prune_all_unused_images" method="post" onsubmit="return confirm('This deletes ALL images not currently attached to a container. Continue?');">
                <button class="btn btn-img-all">🚨 Prune ALL Unused</button>
            </form>
        </div>
    </div>
    {% if images %}
    <table>
        <tr><th>ID</th><th>Tag / Name</th><th>Type</th><th>Size</th><th>Whitelist</th></tr>
        {% for i in images %}
        <tr>
            <td>{{ i.short_id }}</td>
            <td>
                {% if i.is_dangling %}
                    <span class="tag-dangling">&lt;none&gt;:&lt;none&gt;</span>
                {% else %}
                    <span class="tag-named">{{ i.tag }}</span>
                {% endif %}
            </td>
            <td>
                {% if i.is_dangling %}
                    Dangling (Orphaned)
                {% else %}
                    Tagged (Downloaded)
                {% endif %}
            </td>
            <td>{{ i.size_mb }} MB</td>
             <td>
                {% if i.protected %}
                    <span class="protected">🛡️ Protected</span>
                {% else %}
                    <span class="risk">⚠️ Ready to Prune</span>
                {% endif %}
            </td>
        </tr>
        {% endfor %}
    </table>
    {% else %}
        <div class="empty-msg">No unused images found.</div>
    {% endif %}

    <div class="section-header">
        <h2>💿 Unused Volumes</h2>
        <div class="section-actions">
            <form action="/prune_volumes" method="post" onsubmit="return confirm('WARNING: Deleting volumes means PERMANENT DATA LOSS for any databases or files stored in them. Are you sure you want to delete all unattached volumes?');">
                <button class="btn btn-vol">💿 Prune Unused Volumes</button>
            </form>
        </div>
    </div>
    {% if volumes %}
    <table>
        <tr><th>Volume Name</th><th>Driver</th><th>Whitelist</th></tr>
        {% for v in volumes %}
        <tr>
            <td>{{ v.name }}</td>
            <td>{{ v.driver }}</td>
            <td>
                {% if v.protected %}
                    <span class="protected">🛡️ Protected</span>
                {% else %}
                    <span class="risk">⚠️ Ready to Prune</span>
                {% endif %}
            </td>
        </tr>
        {% endfor %}
    </table>
    {% else %}
        <div class="empty-msg">No unused volumes found.</div>
    {% endif %}
</div>
</body>
</html>
"""

@app.route('/')
def index():
    stopped_containers = client.containers.list(all=True, filters={'status': 'exited'})

    all_containers = client.containers.list(all=True)
    used_image_ids = {c.image.id for c in all_containers}
    all_images = client.images.list()

    unused_images_data = []
    for img in all_images:
        if img.id not in used_image_ids:
            is_dangling = len(img.tags) == 0
            display_tag = img.tags[0] if not is_dangling else "<none>:<none>"

            unused_images_data.append({
                'short_id': img.short_id,
                'tag': display_tag,
                'is_dangling': is_dangling,
                'size_mb': round(img.attrs['Size'] / 1000000, 2),
                'protected': img.labels.get('janitor.skip') == 'true'
            })

    dangling_volumes = client.volumes.list(filters={'dangling': True})
    unused_volumes_data = []
    for v in dangling_volumes:
        labels = v.attrs.get('Labels') or {}
        unused_volumes_data.append({
            'name': v.name,
            'driver': v.attrs.get('Driver', 'local'),
            'protected': labels.get('janitor.skip') == 'true'
        })

    return render_template_string(HTML, containers=stopped_containers, images=unused_images_data, volumes=unused_volumes_data)

@app.route('/prune_containers', methods=['POST'])
def prune_containers():
    try:
        stopped = client.containers.list(all=True, filters={'status': 'exited'})
        count = 0
        for c in stopped:
            if c.labels.get('janitor.skip') != 'true':
                c.remove()
                count += 1
        flash(f"✅ Removed {count} Stopped Containers.")
    except Exception as e:
        flash(f"❌ Error: {e}")
    return redirect(url_for('index'))

@app.route('/prune_dangling_images', methods=['POST'])
def prune_dangling_images():
    try:
        dangling = client.images.list(filters={'dangling': True})
        count = 0
        for img in dangling:
            if img.labels.get('janitor.skip') != 'true':
                client.images.remove(image=img.id, force=True)
                count += 1
        flash(f"✅ Removed {count} Dangling Images.")
    except Exception as e:
        flash(f"❌ Error: {e}")
    return redirect(url_for('index'))

@app.route('/prune_all_unused_images', methods=['POST'])
def prune_all_unused_images():
    try:
        all_containers = client.containers.list(all=True)
        used_image_ids = {c.image.id for c in all_containers}
        all_images = client.images.list()

        count = 0
        for img in all_images:
            if img.id not in used_image_ids and img.labels.get('janitor.skip') != 'true':
                client.images.remove(image=img.id, force=True)
                count += 1
        flash(f"🚨 Removed {count} Unused Images.")
    except Exception as e:
        flash(f"❌ Error: {e}")
    return redirect(url_for('index'))

@app.route('/prune_volumes', methods=['POST'])
def prune_volumes():
    try:
        dangling = client.volumes.list(filters={'dangling': True})
        count = 0
        for v in dangling:
            labels = v.attrs.get('Labels') or {}
            if labels.get('janitor.skip') != 'true':
                v.remove(force=True)
                count += 1
        flash(f"💾 Removed {count} Unused Volumes.")
    except Exception as e:
        flash(f"❌ Error: {e}")
    return redirect(url_for('index'))

@app.route('/prune_builds', methods=['POST'])
def prune_builds():
    try:
        deleted = client.api.prune_builds()
        space = deleted.get('SpaceReclaimed', 0) if deleted else 0
        flash(f"🏗️ Cleared Build Cache. Reclaimed {space} bytes.")
    except Exception as e:
        flash(f"❌ Error: {e}")
    return redirect(url_for('index'))

@app.route('/truncate_logs', methods=['POST'])
def truncate_logs():
    try:
        client.containers.run(
            image="alpine:latest",
            command='sh -c "find /var/lib/docker/containers/ -name \'*-json.log\' -type f -exec truncate -s 0 {} \\;"',
            volumes={'/var/lib/docker/containers': {'bind': '/var/lib/docker/containers', 'mode': 'rw'}},
            remove=True
        )
        flash(f"📄 Successfully truncated all container logs to 0 bytes.")
    except Exception as e:
        flash(f"❌ Error truncating logs: {e}")
    return redirect(url_for('index'))

@app.route('/prune_system', methods=['POST'])
def prune_system():
    try:
        stopped = client.containers.list(all=True, filters={'status': 'exited'})
        for c in stopped:
            if c.labels.get('janitor.skip') != 'true':
                c.remove()

        all_containers = client.containers.list(all=True)
        used_image_ids = {c.image.id for c in all_containers}
        all_images = client.images.list()
        for img in all_images:
            if img.id not in used_image_ids and img.labels.get('janitor.skip') != 'true':
                client.images.remove(image=img.id, force=True)

        client.networks.prune(filters={'label!': 'janitor.skip=true'})
        client.api.prune_builds()

        flash(f"☢️ System Nuked. Containers, Images, Networks, and Build Cache removed. (Volumes kept safe).")
    except Exception as e:
        flash(f"❌ Error: {e}")
    return redirect(url_for('index'))

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=5000)
