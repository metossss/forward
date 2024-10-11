from flask import Flask, render_template, request, redirect, url_for, session, jsonify
import subprocess
import os
import re

app = Flask(__name__)
app.secret_key = os.urandom(24)

# Import credentials
import config

CONFIG_FILE = "/etc/bind/named.conf.options"
ALLOWED_IPS_FILE = "/etc/bind/allowed-ips.acl"

@app.route("/")
def index():
    if "logged_in" not in session:
        return redirect(url_for("login"))
    return render_template("index.html")

@app.route("/login", methods=["GET", "POST"])
def login():
    if request.method == "POST":
        if (request.form["username"] == config.ADMIN_USERNAME and
            request.form["password"] == config.ADMIN_PASSWORD):
            session["logged_in"] = True
            return redirect(url_for("index"))
    return render_template("login.html")

@app.route("/logout")
def logout():
    session.pop("logged_in", None)
    return redirect(url_for("login"))

@app.route("/api/status")
def get_status():
    if "logged_in" not in session:
        return jsonify({"error": "Unauthorized"}), 401

    try:
        status = subprocess.run(["systemctl", "is-active", "named"], capture_output=True, text=True).stdout.strip()
    except Exception:
        status = "inactive"
    
    with open(CONFIG_FILE, "r") as f:
        config_content = f.read()
    
    dns_servers = re.findall(r"(\d+\.\d+\.\d+\.\d+)", config_content)
    
    mode = "Custom"
    if dns_servers == ["178.22.122.100", "185.51.200.2"]:
        mode = "Shekan"
    elif dns_servers == ["10.202.10.10", "10.202.10.11"]:
        mode = "Radar"
    elif dns_servers == ["10.202.10.202", "10.202.10.102"]:
        mode = "Anti403"
    
    ip_restriction = "allow-query { allowed_ips; };" in config_content
    
    with open(ALLOWED_IPS_FILE, "r") as f:
        allowed_ips = [line.strip().rstrip(";") for line in f if line.strip() and not line.startswith("acl") and line.strip() != "}"]

    return jsonify({
        "status": status,
        "mode": mode,
        "dns_servers": dns_servers,
        "ip_restriction": ip_restriction,
        "allowed_ips": allowed_ips
    })

@app.route("/api/set_dns", methods=["POST"])
def set_dns():
    if "logged_in" not in session:
        return jsonify({"error": "Unauthorized"}), 401

    mode = request.json["mode"]
    if mode == "custom":
        custom_dns = request.json.get("custom_dns", [])
        if not custom_dns or len(custom_dns) == 0:
            return jsonify({"error": "Custom DNS servers are required"}), 400
        dns_servers = " ".join(custom_dns)
        cmd = ["sudo", "dnsforwarder", "set", "custom"]
    else:
        cmd = ["sudo", "dnsforwarder", "set", mode]

    try:
        if mode == "custom":
            process = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            stdout, stderr = process.communicate(input=f"{dns_servers}\n\n")
        else:
            process = subprocess.run(cmd, capture_output=True, text=True, check=True)
            stdout, stderr = process.stdout, process.stderr

        if process.returncode != 0:
            return jsonify({"error": f"Failed to set DNS: {stderr}"}), 500
        return jsonify({"message": f"DNS set to {mode} mode successfully"})
    except subprocess.CalledProcessError as e:
        return jsonify({"error": f"Failed to set DNS: {e.stderr}"}), 500
    except Exception as e:
        return jsonify({"error": f"An unexpected error occurred: {str(e)}"}), 500

@app.route("/api/toggle_ip_restriction", methods=["POST"])
def toggle_ip_restriction():
    if "logged_in" not in session:
        return jsonify({"error": "Unauthorized"}), 401

    try:
        with open(CONFIG_FILE, "r") as f:
            config_content = f.read()
        
        current_status = "allow-query { allowed_ips; };" in config_content
        
        action = "disable" if current_status else "enable"
        result = subprocess.run(["sudo", "dnsforwarder", action, "iplimit"], capture_output=True, text=True)
        
        if result.returncode != 0:
            return jsonify({"error": f"Failed to {action} IP restriction: {result.stderr}"}), 500

        new_status = not current_status
        return jsonify({"message": f"IP restriction {'enabled' if new_status else 'disabled'} successfully", "ip_restriction": new_status})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route("/api/update_allowed_ips", methods=["POST"])
def update_allowed_ips():
    if "logged_in" not in session:
        return jsonify({"error": "Unauthorized"}), 401

    ips = request.json["ips"]
    try:
        with open(ALLOWED_IPS_FILE, "w") as f:
            f.write('acl "allowed_ips" {\n')
            for ip in ips:
                f.write(f"    {ip};\n")
            f.write("};\n")
        
        subprocess.run(["sudo", "systemctl", "restart", "named"], check=True)
        return jsonify({"message": "Allowed IPs updated successfully"})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route("/api/toggle", methods=["POST"])
def toggle_service():
    if "logged_in" not in session:
        return jsonify({"error": "Unauthorized"}), 401

    action = request.json.get("action")
    if action not in ["start", "stop", "restart"]:
        return jsonify({"success": False, "error": "Invalid action"}), 400

    try:
        result = subprocess.run(["sudo", "dnsforwarder", action], capture_output=True, text=True, check=True)
        return jsonify({"success": True, "message": f"Service {action}ed successfully"})
    except subprocess.CalledProcessError as e:
        return jsonify({"success": False, "error": f"Failed to {action} service: {e.stderr}"}), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
