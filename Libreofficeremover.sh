sudo apt purge libreoffice-common -y 
echo if apt dont work will be used pacman if you use fedora rpm-ostree and dnf will be used
sudo pacman -Rns libreoffice-fresh libreoffice-still --noconfirm
echo trying fedora dnf and rpm-ostree but you cant see the errors
sudo dnf remove libreoffice-core -y 2>/dev/null
sudo rpm-ostree override remove libreoffice-core 2>/dev/null
