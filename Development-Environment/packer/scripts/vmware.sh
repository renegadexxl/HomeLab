# Install Guest Additions
yum -y group install guest-agents

# Start daemon
systemctl enable --now vmtoolsd
