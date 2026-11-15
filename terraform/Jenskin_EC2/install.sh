# =====================================================
# 1. Update system and install prerequisites
# =====================================================

apt-get update -y

apt-get install -y \
    wget \
    curl \
    gnupg \
    ca-certificates \
    apt-transport-https \
    lsb-release \
    fontconfig

mkdir -p /etc/apt/keyrings
mkdir -p /usr/share/keyrings

# =====================================================
# 2. Install Java 21 - Eclipse Temurin
# =====================================================

echo "===== Installing Java 21 ====="

curl -fsSL https://packages.adoptium.net/artifactory/api/gpg/key/public \
    -o /etc/apt/keyrings/adoptium.asc

CODENAME=$(. /etc/os-release && echo "$VERSION_CODENAME")

echo "deb [signed-by=/etc/apt/keyrings/adoptium.asc] https://packages.adoptium.net/artifactory/deb ${CODENAME} main" \
    > /etc/apt/sources.list.d/adoptium.list

apt-get update -y

apt-get install -y temurin-21-jdk

java --version

# =====================================================
# 3. Install Jenkins LTS
# =====================================================

echo "===== Installing Jenkins ====="

curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key \
    -o /etc/apt/keyrings/jenkins-keyring.asc

echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" \
    > /etc/apt/sources.list.d/jenkins.list

apt-get update -y

apt-get install -y jenkins

systemctl enable jenkins
systemctl start jenkins

# =====================================================
# 4. Install Docker
# =====================================================

echo "===== Installing Docker ====="

apt-get update -y

apt-get install -y docker.io

systemctl enable --now docker

# Add Ubuntu user to Docker group
usermod -aG docker ubuntu

# Add Jenkins user to Docker group
usermod -aG docker jenkins

# Restart Jenkins to apply Docker group membership
systemctl restart jenkins

# =====================================================
# 5. Configure Linux kernel for SonarQube
# =====================================================

echo "===== Configuring SonarQube requirements ====="

cat > /etc/sysctl.d/99-sonarqube.conf <<EOF
vm.max_map_count=524288
fs.file-max=131072
EOF

sysctl --system

# =====================================================
# 6. Run SonarQube as Docker Container
# =====================================================

echo "===== Starting SonarQube ====="

docker volume create sonar_data
docker volume create sonar_extensions
docker volume create sonar_logs

if ! docker ps -a --format '{{.Names}}' | grep -qx sonar; then

    docker run -d \
        --name sonar \
        --restart unless-stopped \
        -p 9000:9000 \
        --ulimit nofile=131072:131072 \
        --ulimit nproc=8192:8192 \
        -v sonar_data:/opt/sonarqube/data \
        -v sonar_extensions:/opt/sonarqube/extensions \
        -v sonar_logs:/opt/sonarqube/logs \
        sonarqube:lts-community

else
    echo "SonarQube container already exists."
    docker start sonar || true
fi

# =====================================================
# 7. Install Trivy
# =====================================================

echo "===== Installing Trivy ====="

curl -fsSL https://aquasecurity.github.io/trivy-repo/deb/public.key \
    | gpg --dearmor --yes -o /usr/share/keyrings/trivy.gpg

echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb ${CODENAME} main" \
    > /etc/apt/sources.list.d/trivy.list

apt-get update -y

apt-get install -y trivy
