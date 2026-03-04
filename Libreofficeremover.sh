sudo apt purge libreoffice-common -y 2>/dev/null
echo if apt dont work will be used pacman if you use fedora rpm-ostree and dnf will be used
sudo pacman -Rns libreoffice-fresh libreoffice-still --noconfirm 2>/dev/null
sudo dnf remove libreoffice-core -y 2>/dev/null
sudo rpm-ostree override remove libreoffice-core 2>/dev/null
