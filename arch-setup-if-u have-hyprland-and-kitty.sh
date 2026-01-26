#!/bin/bash
echo dont need mkdir
sudo pacman -S --noconfirm swww waybar wofi wl-clipboard curl pipewire pipewire-pulse intel-media-driver libva-intel-driver nvidia

rfkill unblock all
cat << 'EOF' > ~/.config/hypr/hyprland.conf
monitor=,highrr,auto,1

$terminal = kitty
$menu = wofi --show drun

exec-once = swww-daemon
exec-once = swww img 
exec-once = waybar
general {
    gaps_in = 5
    gaps_out = 10
    border_size = 3
    col.active_border = rgb(009c3b) rgb(ffdf00) 45deg
    col.inactive_border = rgba(595959aa)
}

decoration {
    rounding = 10
    blur {
        enabled = true
        size = 3
    }
}
animations {
    enabled = true
    bezier = myBezier, 0.05, 0.9, 0.1, 1.05
    animation = windows, 1, 7, myBezier
    animation = windowsOut, 1, 7, default, popin 80%
    animation = border, 1, 10, default
    animation = fade, 1, 7, default
    animation = workspaces, 1, 6, default
}
bind = SUPER, Return, exec, $terminal
bind = SUPER SHIFT, Q, killactive,
bind = SUPER SHIFT, E, exit,
bind = SUPER, D, exec, $menu
bind = SUPER, left, movefocus, l
bind = SUPER, right, movefocus, r
bind = SUPER, up, movefocus, u
bind = SUPER, down, movefocus, d

input {
    kb_layout = br
    touchpad {
        natural_scroll = true
    }
}
EOF
echo "background_opacity 0.8" > ~/.config/kitty/kitty.conf
echo "confirm_os_window_close 0" >> ~/.config/kitty/kitty.conf

sudo systemctl enable NetworkManager
sudo pacman -S curl
curl -S 'https://liquorix.net' | sudo bash
sudo grub-mkconfig -o /boot/grub/grub.cfg
sudo pacman -S --noconfirm nvidia nvidia-utils nvidia-settings lib32-nvidia-utils
sudo pacman -S --noconfirm nvidia-prime
#!/bin/bash

sudo bash -c "cat << 'EOF' > /etc/modprobe.d/nvidia.conf
options nvidia-drm modeset=1
options nvidia NVreg_PreserveVideoMemoryAllocations=1
options nvidia NVreg_TemporaryFilePath=/var/tmp
EOF
sed -i '/monitor=,highrr,auto,1/a env = LIBVA_DRIVER_NAME,intel\nenv = __GLX_VENDOR_LIBRARY_NAME,intel\nenv = WLR_NO_HARDWARE_CURSORS,1' ~/.config/hypr/hyprland.conf

sudo sed -i 's/MODULES=(/MODULES=(i915 nvidia nvidia_modeset nvidia_uvm nvidia_drm /' /etc/mkinitcpio.conf
sudo mkinitcpio -P
echo 'options nvidia NVreg_DynamicPowerManagement=0x02' | sudo tee -a /etc/modprobe.d/nvidia.conf
echo 'config instaled you finnaly a brazil patriot restarting the arch linux'
sudo systemctl enable iwd
sudo systemctl enable NetworkManager
sudo pacman -Sy
sudo reboot
