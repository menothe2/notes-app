# Contributing Guide

## 1. Prerequisites

Install these if you don't have them:
- [Git](https://git-scm.com)
- [Node.js](https://nodejs.org) (v18+)
- [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)

---

## 2. Get AWS Access

Ask the repo owner to:
1. Go to **IAM → Users → Create user**
2. Attach **AmazonS3FullAccess** + **CloudFrontFullAccess** (deploy-only) or **AdministratorAccess** (full access)
3. Create an access key and send it to you securely

Then run:
```bash
aws configure
# Access Key ID:     <paste key>
# Secret Access Key: <paste secret>
# Default region:    us-east-1
# Output format:     json
```

---

## 3. Clone and Set Up Locally

```bash
git clone https://github.com/menothe2/notes-app.git
cd notes-app

# Install frontend dependencies
cd frontend && npm install && cd ..

# Install Java 17
mkdir -p ~/java
curl -L "https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.10%2B7/OpenJDK17U-jdk_x64_mac_hotspot_17.0.10_7.tar.gz" -o ~/java/jdk17.tar.gz
tar -xzf ~/java/jdk17.tar.gz -C ~/java

# Install Maven
curl -L "https://archive.apache.org/dist/maven/maven-3/3.9.6/binaries/apache-maven-3.9.6-bin.tar.gz" -o ~/java/maven.tar.gz
tar -xzf ~/java/maven.tar.gz -C ~/java
```

Add to `~/.zshrc` (or `~/.bashrc`) so these persist across terminal sessions:
```bash
export JAVA_HOME=~/java/jdk-17.0.10+7/Contents/Home
export PATH=$JAVA_HOME/bin:~/java/apache-maven-3.9.6/bin:$PATH
```
Then reload: `source ~/.zshrc`

---

## 4. Run Locally

Open **two terminals**:

**Terminal 1 — Backend:**
```bash
cd notes-app/backend
mvn spring-boot:run
# Runs on http://localhost:8080
```

**Terminal 2 — Frontend:**
```bash
cd notes-app/frontend
npm run dev
# Runs on http://localhost:5173
```

Open **http://localhost:5173** in your browser.

---

## 5. Make Changes and Push

```bash
git checkout -b your-feature-name     # create a branch
# ... make your changes ...
git add <files>
git commit -m "describe what you changed"
git push origin your-feature-name
```

Then open a PR on GitHub, or if pushing directly to main:
```bash
git checkout main
git pull
git merge your-feature-name
git push origin main
```

---

## 6. Deploy

**Frontend only** (React changes):
```bash
cd notes-app/frontend
VITE_API_URL="" npm run build
aws s3 sync dist/ s3://notes-app-frontend-886418435218 --delete --cache-control "public,max-age=31536000,immutable" --exclude "index.html" --region us-east-1
aws s3 cp dist/index.html s3://notes-app-frontend-886418435218/index.html --cache-control "no-cache,no-store,must-revalidate" --region us-east-1
aws cloudfront create-invalidation --distribution-id E2OTPYY4F051SO --paths "/*"
```
Live in ~2 minutes at **https://daod9jxngemwy.cloudfront.net**

**Backend only** (Java changes) — requires the `notes-app.pem` key from the repo owner:
```bash
cd notes-app
bash deploy/02-deploy-backend.sh
```

**Both frontend and backend:**
```bash
bash deploy/02-deploy-backend.sh
bash deploy/03-deploy-frontend.sh
```

---

## Key Info

| | |
|---|---|
| **Repo** | https://github.com/menothe2/notes-app |
| **Live app** | https://daod9jxngemwy.cloudfront.net |
| **Backend** | http://32.192.233.241:8080 |
| **EC2 SSH key** | Ask repo owner for `notes-app.pem` |
| **SSH into server** | `ssh -i notes-app.pem ec2-user@32.192.233.241` |
| **View server logs** | `sudo journalctl -u notes -f` |
