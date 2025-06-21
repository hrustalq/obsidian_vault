# SSH Key Setup Guide for Remote Deployment

This guide will help you set up SSH keys for secure remote server access and GitHub Actions deployment.

## Table of Contents
1. [Generate SSH Key Pair](#generate-ssh-key-pair)
2. [Set Up Server Access](#set-up-server-access)
3. [Configure GitHub Secrets](#configure-github-secrets)
4. [Test SSH Connection](#test-ssh-connection)
5. [Security Best Practices](#security-best-practices)
6. [Troubleshooting](#troubleshooting)

## Generate SSH Key Pair

### On Your Local Machine

1. **Generate a new SSH key pair** (recommended: Ed25519):
   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/obsidian_deploy -C "obsidian-deployment-key"
   ```

   **Alternative (RSA - if Ed25519 not supported):**
   ```bash
   ssh-keygen -t rsa -b 4096 -f ~/.ssh/obsidian_deploy -C "obsidian-deployment-key"
   ```

2. **When prompted:**
   - **Enter file location**: Press Enter to accept default or specify custom path
   - **Enter passphrase**: Leave empty for automated deployment (or use for extra security)

3. **Two files will be created:**
   - `~/.ssh/obsidian_deploy` (private key - keep secret!)
   - `~/.ssh/obsidian_deploy.pub` (public key - safe to share)

### View Your Keys

```bash
# View public key (this goes on your server)
cat ~/.ssh/obsidian_deploy.pub

# View private key (this goes in GitHub secrets)
cat ~/.ssh/obsidian_deploy
```

## Set Up Server Access

### Option 1: Manual Setup

1. **Copy public key to your server:**
   ```bash
   ssh-copy-id -i ~/.ssh/obsidian_deploy.pub username@your-server-ip
   ```

2. **Or manually add to server:**
   ```bash
   # On your server
   mkdir -p ~/.ssh
   chmod 700 ~/.ssh
   
   # Add your public key to authorized_keys
   echo "your-public-key-content" >> ~/.ssh/authorized_keys
   chmod 600 ~/.ssh/authorized_keys
   ```

### Option 2: Using SCP

```bash
# Copy public key to server
scp ~/.ssh/obsidian_deploy.pub username@your-server-ip:~/

# SSH to server and set up
ssh username@your-server-ip
mkdir -p ~/.ssh
cat ~/obsidian_deploy.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
chmod 700 ~/.ssh
rm ~/obsidian_deploy.pub
```

## Configure GitHub Secrets

### 1. Go to Your Repository Settings
- Navigate to: `Settings > Secrets and variables > Actions`

### 2. Add Required Secrets

Click "New repository secret" for each:

| Secret Name | Value | Description |
|-------------|-------|-------------|
| `SSH_HOST` | `your-server-ip` | Server IP address or domain |
| `SSH_USERNAME` | `username` | SSH username on server |
| `SSH_KEY` | `private key content` | Content of `~/.ssh/obsidian_deploy` |
| `SSH_PORT` | `22` | SSH port (optional, defaults to 22) |
| `DEPLOY_PATH` | `/path/to/app` | Path where app is deployed on server |

### 3. Example SSH_KEY Secret Value

Copy the **entire content** of your private key:
```bash
cat ~/.ssh/obsidian_deploy
```

The secret should include the full key:
```
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAA...
...your private key content...
-----END OPENSSH PRIVATE KEY-----
```

### 4. SSL Certificate Secrets (Optional but Recommended)

For HTTPS support, add your SSL certificates:

| Secret Name | Content | How to Get |
|-------------|---------|------------|
| `SSL_CERT` | Full certificate content | `cat /path/to/certificate.crt` |
| `SSL_KEY` | Private key content | `cat /path/to/private.key` |

**For Let's Encrypt users:**
```bash
# Copy certificate content
cat /etc/letsencrypt/live/yourdomain.com/fullchain.pem

# Copy private key content  
cat /etc/letsencrypt/live/yourdomain.com/privkey.pem
```

**Important:** Include the full content with headers like `-----BEGIN CERTIFICATE-----`

### 5. Other Optional Environment Secrets

Add these if you want to override defaults:
- `COUCHDB_PASSWORD` (required)
- `COUCHDB_USER` (optional)
- `PUID`, `PGID`, `UMASK`, `TZ` (optional)

## Test SSH Connection

### From Your Local Machine

```bash
# Test SSH connection
ssh -i ~/.ssh/obsidian_deploy username@your-server-ip

# Test with specific port
ssh -i ~/.ssh/obsidian_deploy -p 22 username@your-server-ip

# Test non-interactive commands
ssh -i ~/.ssh/obsidian_deploy username@your-server-ip "ls -la"
```

### Test Deployment Commands

```bash
# Test Docker commands work on server
ssh -i ~/.ssh/obsidian_deploy username@your-server-ip "docker --version"
ssh -i ~/.ssh/obsidian_deploy username@your-server-ip "docker-compose --version"

# Test make commands work
ssh -i ~/.ssh/obsidian_deploy username@your-server-ip "cd /path/to/app && make help"
```

## Security Best Practices

### 1. SSH Configuration

Create/edit `~/.ssh/config` on your local machine:
```bash
Host obsidian-server
    HostName your-server-ip
    User username
    IdentityFile ~/.ssh/obsidian_deploy
    Port 22
    StrictHostKeyChecking yes
```

Then connect with: `ssh obsidian-server`

### 2. Server Hardening

On your server, edit `/etc/ssh/sshd_config`:
```bash
# Disable password authentication
PasswordAuthentication no

# Disable root login
PermitRootLogin no

# Change default port (optional)
Port 2222

# Allow only specific users
AllowUsers username
```

Restart SSH service:
```bash
sudo systemctl restart ssh
```

### 3. Firewall Setup

```bash
# Ubuntu/Debian
sudo ufw allow ssh
sudo ufw allow 5984  # CouchDB port
sudo ufw enable

# CentOS/RHEL
sudo firewall-cmd --permanent --add-service=ssh
sudo firewall-cmd --permanent --add-port=5984/tcp
sudo firewall-cmd --reload
```

## Troubleshooting

### Common Issues

1. **Permission Denied (publickey)**
   ```bash
   # Check key permissions
   chmod 600 ~/.ssh/obsidian_deploy
   chmod 644 ~/.ssh/obsidian_deploy.pub
   
   # Check server authorized_keys
   chmod 600 ~/.ssh/authorized_keys
   chmod 700 ~/.ssh
   ```

2. **Connection Timeout**
   ```bash
   # Test connectivity
   ping your-server-ip
   telnet your-server-ip 22
   ```

3. **Key Not Working**
   ```bash
   # Verbose SSH for debugging
   ssh -vvv -i ~/.ssh/obsidian_deploy username@your-server-ip
   ```

4. **GitHub Actions Failing**
   - Check secret names match exactly
   - Ensure private key includes BEGIN/END lines
   - Verify server allows SSH connections from GitHub's IP ranges

### Debug Commands

```bash
# Check SSH agent
ssh-add -l

# Test key format
ssh-keygen -l -f ~/.ssh/obsidian_deploy

# Check server SSH logs
sudo tail -f /var/log/auth.log
```

## Next Steps

After setting up SSH keys:

1. **Test the connection** manually
2. **Add secrets** to GitHub repository
3. **Update the deployment workflow** to use your server
4. **Test deployment** with a test commit

## Example Deployment Workflow Update

```yaml
- name: Deploy to Server
  uses: appleboy/ssh-action@v0.1.7
  with:
    host: ${{ secrets.SSH_HOST }}
    username: ${{ secrets.SSH_USERNAME }}
    key: ${{ secrets.SSH_KEY }}
    port: ${{ secrets.SSH_PORT || 22 }}
    script: |
      cd ${{ secrets.DEPLOY_PATH }}
      git pull origin main
      export COUCHDB_PASSWORD="${{ secrets.COUCHDB_PASSWORD }}"
      export COUCHDB_USER="${{ secrets.COUCHDB_USER }}"
      make up
```

---

**⚠️ Security Warning**: Never commit private keys to your repository. Always use GitHub Secrets for sensitive information. 