# Module 0: Set Up Your Kubernetes Lab 🛠️

> Do this once, before Module 1. By the end you'll have a real multi-node Kubernetes cluster running on your own laptop, for free.

⏱️ **Time:** 30–60 minutes (mostly downloads)
💰 **Cost:** free

---

## What You'll Install

| Tool | What it does | Required? |
|---|---|---|
| **Docker** | Runs containers. kind uses it to create the cluster's "machines" | ✅ Yes |
| **kubectl** | The command-line tool you use to talk to any Kubernetes cluster | ✅ Yes |
| **kind** | "Kubernetes IN Docker": creates a real cluster on your laptop | ✅ Yes |
| **Git** | Downloads this course repo | ✅ Yes |
| **Helm** | Package manager for Kubernetes (used in later modules) | ⭕ Optional for now |

### How they fit together

```
 You ──► kubectl ──► Kubernetes cluster (made by kind)
                         │
                         ├── techudaan-control-plane   ┐
                         ├── techudaan-worker          ├── each "node" is a Docker container
                         └── techudaan-worker2         ┘
                                     ▲
                                  Docker
```

---

## System Requirements

| | Minimum | Recommended |
|---|---|---|
| RAM | 8 GB | 16 GB |
| Free disk space | 15 GB | 30 GB |
| CPU | 2 cores, with **virtualization enabled** in BIOS | 4+ cores |
| OS | Windows 10/11 (64-bit), macOS 12+, or Ubuntu 22.04+ | Any of these |

> 💡 **No laptop, or too slow?** Use a free browser lab such as [Killercoda](https://killercoda.com/playgrounds) (free tier, with time limits) and skip to the course.

---

## Choose Your Path

| Your laptop | Go to |
|---|---|
| 🪟 Windows 10 / 11 | [Path A: Windows (WSL2)](#path-a-windows-wsl2) |
| 🍎 macOS (Intel or Apple Silicon) | [Path B: macOS](#path-b-macos) |
| 🐧 Linux (Ubuntu / Debian) | [Path C: Linux](#path-c-linux-ubuntu--debian) |

After your path, everyone continues at [Verify your setup](#verify-your-setup).

---

## Path A: Windows (WSL2)

On Windows, we work inside **WSL2** (Windows Subsystem for Linux). It gives you a real Ubuntu terminal, so every command in this course works exactly as written.

### A1. Install WSL2 with Ubuntu

Open **PowerShell as Administrator** (right-click → *Run as administrator*):

```powershell
wsl --install -d Ubuntu
```

**Restart** your computer when asked. After the restart, Ubuntu opens and asks you to create a **username and password**. Remember the password; you'll need it for `sudo`.

Check it's WSL **version 2**:

```powershell
wsl -l -v
```

✅ **Expected:** `Ubuntu   Running   2`

> ⚠️ Error mentioning **virtualization**? Restart, enter your BIOS/UEFI settings (usually `F2`, `F10` or `Del` at boot), and enable **Intel VT-x** or **AMD-V / SVM**.

### A2. Install Docker Desktop

1. Download **Docker Desktop for Windows** from [docker.com](https://www.docker.com/products/docker-desktop/) and install it. Keep **"Use WSL 2 instead of Hyper-V"** checked.
2. Open Docker Desktop → **Settings** → **Resources** → **WSL Integration** → turn on **Ubuntu** → **Apply & Restart**.
3. Optional, for 8 GB laptops: create `C:\Users\<you>\.wslconfig` with:

   ```ini
   [wsl2]
   memory=5GB
   processors=2
   ```

   Then run `wsl --shutdown` in PowerShell and reopen Ubuntu.

> ℹ️ Docker Desktop is free for personal use, education and small businesses. Check Docker's terms if you use it at a larger company.

### A3. Install kubectl, kind and Git inside Ubuntu

Open the **Ubuntu** app. From here on, **every command runs inside Ubuntu**, not PowerShell.

First check that Docker works from Ubuntu:

```bash
docker run --rm hello-world
```

✅ **Expected:** `Hello from Docker!`

Now follow the Linux steps from **[C2. Install kubectl](#c2-install-kubectl)** onwards (skip C1, because Docker Desktop already provides Docker).

---

## Path B: macOS

### B1. Install Homebrew (if you don't have it)

Open **Terminal** and check:

```bash
brew --version
```

If it says `command not found`, install Homebrew by following the one-line command on [brew.sh](https://brew.sh), then close and reopen Terminal.

### B2. Install Docker

**Option 1: Docker Desktop** (easiest)
Download **Docker Desktop for Mac** from [docker.com](https://www.docker.com/products/docker-desktop/). Choose **Apple Silicon** (M1/M2/M3/M4) or **Intel**, depending on your Mac ( → *About This Mac*). Open it once and wait until it says Docker is running.

**Option 2: Colima** (free and lightweight, no Docker Desktop needed)

```bash
brew install colima docker
colima start --cpu 2 --memory 4
```

Check it works:

```bash
docker run --rm hello-world
```

✅ **Expected:** `Hello from Docker!`

### B3. Install kubectl, kind and Git

```bash
brew install kubectl kind git
```

Then continue at [Verify your setup](#verify-your-setup).

---

## Path C: Linux (Ubuntu / Debian)

### C1. Install Docker Engine

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
```

Let your user run Docker without `sudo`:

```bash
sudo usermod -aG docker $USER
newgrp docker
```

Check it works:

```bash
docker run --rm hello-world
```

✅ **Expected:** `Hello from Docker!`

> 💡 `get.docker.com` is Docker's official convenience script. For other distributions, follow [docs.docker.com/engine/install](https://docs.docker.com/engine/install/).

### C2. Install kubectl

This downloads the latest stable version and verifies it isn't corrupted.

**For most laptops (x86_64 / AMD64):**

```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"
echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl kubectl.sha256
```

**For ARM64 machines:** replace both `amd64` with `arm64`.

> Not sure which you have? Run `uname -m`: `x86_64` means AMD64, `aarch64` means ARM64.

✅ **Expected:** `kubectl: OK` from the checksum step. Then:

```bash
kubectl version --client
```

### C3. Install kind

```bash
# For AMD64 / x86_64
[ $(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.33.0/kind-linux-amd64
# For ARM64
[ $(uname -m) = aarch64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.33.0/kind-linux-arm64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
```

```bash
kind version
```

✅ **Expected:** `kind v0.33.0 ...`

> 💡 Newer version out? Check the [kind quick start](https://kind.sigs.k8s.io/docs/user/quick-start/#installation) and change `v0.33.0` in the URL.

### C4. Install Git

```bash
sudo apt-get install -y git
git --version
```

---

## Verify Your Setup

### Option 1: Run the checker script

From the course repo:

```bash
git clone https://github.com/<your-org>/techudaan-kubernetes.git
cd techudaan-kubernetes
bash module-00-setup/check-setup.sh
```

✅ **Expected:** every line shows `[OK]`, ending with `You're ready for Module 1!`

### Option 2: Check by hand

```bash
docker version --format 'Docker {{.Server.Version}}'
kubectl version --client
kind version
git --version
```

Each command should print a version, with no errors.

---

## Create Your First Cluster 🎉

### 1. A single-node cluster (quick test)

```bash
kind create cluster --name hello
```

This downloads the node image the first time (around 1 GB), so it can take a few minutes.

✅ **Expected (end of output):**

```
✓ Ensuring node image (kindest/node:v1.x.x) 🖼
✓ Preparing nodes 📦
✓ Writing configuration 📜
✓ Starting control-plane 🕹️
✓ Installing CNI 🔌
✓ Installing StorageClass 💾
Set kubectl context to "kind-hello"
```

```bash
kubectl get nodes
```

✅ **Expected:** one node, `hello-control-plane`, with status `Ready`.

Delete it:

```bash
kind delete cluster --name hello
```

### 2. The course cluster (3 nodes)

This is the cluster used in every module:

```bash
kind create cluster --name techudaan --config module-01-architecture/kind-3node.yaml
kubectl get nodes
```

✅ **Expected:**

```
NAME                      STATUS   ROLES           AGE   VERSION
techudaan-control-plane   Ready    control-plane   1m    v1.x.x
techudaan-worker          Ready    <none>          1m    v1.x.x
techudaan-worker2         Ready    <none>          1m    v1.x.x
```

**You're ready for [Module 1: Kubernetes Architecture](../module-01-architecture/notes.md).** 🚀

---

## Quality-of-Life Setup (recommended)

### Tab completion and the `k` shortcut

Add these to your shell so you type less:

```bash
echo 'source <(kubectl completion bash)' >> ~/.bashrc
echo 'alias k=kubectl' >> ~/.bashrc
echo 'complete -o default -F __start_kubectl k' >> ~/.bashrc
source ~/.bashrc
```

> On macOS with zsh (the default), use `~/.zshrc` and `source <(kubectl completion zsh)` instead.

Now `k get po<TAB>` completes to `k get pods`.

### Optional: Helm (needed later in the course)

| OS | Command |
|---|---|
| macOS | `brew install helm` |
| Windows (in Ubuntu/WSL) or Linux | See [helm.sh/docs/intro/install](https://helm.sh/docs/intro/install/) |

```bash
helm version
```

### Recommended editor

[VS Code](https://code.visualstudio.com/) with these free extensions:
- **Kubernetes** (by Microsoft): browse your cluster, YAML hints
- **YAML** (by Red Hat): catches YAML mistakes as you type
- **WSL** (Windows only): open your Ubuntu files directly with `code .`

---

## Daily Commands Cheat Sheet

| Task | Command |
|---|---|
| Start the course cluster | `kind create cluster --name techudaan --config module-01-architecture/kind-3node.yaml` |
| List your kind clusters | `kind get clusters` |
| Which cluster is kubectl using? | `kubectl config current-context` |
| Switch to the course cluster | `kubectl config use-context kind-techudaan` |
| Delete the course cluster | `kind delete cluster --name techudaan` |
| Free up Docker disk space | `docker system prune` |

> 💡 kind clusters don't survive everything. If your laptop restarts and the cluster misbehaves, the fastest fix is to delete and recreate it. It takes about a minute.

---

## Troubleshooting 🧯

| Problem | Fix |
|---|---|
| `permission denied ... docker.sock` | Linux: run `sudo usermod -aG docker $USER`, then log out and back in (or `newgrp docker`) |
| `Cannot connect to the Docker daemon` | Docker isn't running. Start Docker Desktop (or `colima start`, or `sudo systemctl start docker`) |
| `docker: command not found` in WSL Ubuntu | Docker Desktop → Settings → Resources → **WSL Integration** → enable Ubuntu |
| `kind: command not found` / `kubectl: command not found` | The file isn't in your PATH. Re-run the `sudo mv` / `sudo install` step |
| WSL error about virtualization | Enable **VT-x / AMD-V** in BIOS; in Windows Features enable **Virtual Machine Platform** |
| `kind create cluster` hangs or fails on an 8 GB laptop | Close browsers and other apps; use 2 nodes (delete one `worker` line); on Windows, set `.wslconfig` memory |
| Nodes stay `NotReady` for over 2 minutes | Wait a little longer on the first run; otherwise delete and recreate the cluster |
| `ErrImagePull` / `toomanyrequests` | Docker Hub rate limit. Wait, or log in with `docker login` |
| Downloads fail on a college or office network | Proxy or firewall. Try a mobile hotspot, or ask IT to allow `dl.k8s.io`, `kind.sigs.k8s.io` and `registry.k8s.io` |
| `kubectl` talks to the wrong cluster | `kubectl config use-context kind-techudaan` |

Still stuck? Post the **exact command** and the **full error message** in the community channel.

---

## Uninstall (if you ever need to)

```bash
kind delete clusters --all
sudo rm /usr/local/bin/kind /usr/local/bin/kubectl   # Linux / WSL
brew uninstall kind kubectl                          # macOS
```

---

➡️ **Next:** [Module 1: Kubernetes Architecture](../module-01-architecture/notes.md)
