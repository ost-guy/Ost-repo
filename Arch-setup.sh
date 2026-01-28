```bash
#!/bin/bash
#############################################################################
# Script de Instalação e Configuração do Hyprland para Arch Linux
# Versão: 2.0 | Licença: GNU GPL v3.0
#############################################################################

set -euo pipefail

# Variáveis globais
readonly SCRIPT_NAME="Arch Hyprland Setup"
readonly VERSION="2.0"
readonly LOG_FILE="/var/log/arch-setup-install.log"
readonly BACKUP_DIR="$HOME/.config-backup-$(date +%Y%m%d_%H%M%S)"
readonly MIN_DISK_SPACE_GB=5

# Cores
readonly RED='33[0;31m'
readonly GREEN='33[0;32m'
readonly YELLOW='33[1;33m'
readonly BLUE='33[0;34m'
readonly MAGENTA='33[0;35m'
readonly CYAN='33[0;36m'
readonly NC='33[0m'
readonly BOLD='33[1m'

# Variáveis de controle
INSTALL_INTEL=false
INSTALL_NVIDIA=false
INSTALL_AMD=false
KEYBOARD_LAYOUT="br"

#############################################################################
# Funções Utilitárias
#############################################################################

print_success() {
    echo -e "${GREEN}✓${NC} $1"
    log_message "SUCCESS: $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1" >&2
    log_message "ERROR: $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
    log_message "WARNING: $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
    log_message "INFO: $1"
}

print_header() {
    echo -e "\n${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${CYAN}  $1${NC}"
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | sudo tee -a "$LOG_FILE" > /dev/null 2>&1 || true
}

cleanup() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        print_error "Script interrompido com erro (código: $exit_code)"
        print_warning "Logs em: $LOG_FILE"
        [ -d "$BACKUP_DIR" ] && print_info "Backup em: $BACKUP_DIR"
    fi
}

trap cleanup EXIT

check_root() {
    if [ "$EUID" -eq 0 ]; then
        print_error "Não execute como root! O script pedirá sudo quando necessário."
        exit 1
    fi
}

check_arch() {
    if [ ! -f /etc/arch-release ]; then
        print_error "Este script é apenas para Arch Linux!"
        exit 1
    fi
    print_success "Sistema Arch Linux detectado"
}

check_sudo() {
    if ! sudo -v; then
        print_error "Este script requer privilégios sudo"
        exit 1
    fi
    print_success "Permissões sudo verificadas"
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
}

check_disk_space() {
    local available_space=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$available_space" -lt "$MIN_DISK_SPACE_GB" ]; then
        print_error "Espaço insuficiente! Necessário: ${MIN_DISK_SPACE_GB}GB | Disponível: ${available_space}GB"
        exit 1
    fi
    print_success "Espaço em disco suficiente (${available_space}GB disponível)"
}

detect_hardware() {
    print_info "Detectando hardware do sistema..."
    local has_intel=false has_nvidia=false has_amd=false
    
    lspci | grep -i "VGA.*Intel" > /dev/null 2>&1 && has_intel=true && print_info "GPU Intel detectada"
    lspci | grep -i "VGA.*NVIDIA\|3D.*NVIDIA" > /dev/null 2>&1 && has_nvidia=true && print_info "GPU NVIDIA detectada"
    lspci | grep -i "VGA.*AMD\|VGA.*ATI" > /dev/null 2>&1 && has_amd=true && print_info "GPU AMD detectada"
    
    echo "$has_intel $has_nvidia $has_amd"
}

backup_config() {
    if [ -d "$HOME/.config/hypr" ] || [ -d "$HOME/.config/kitty" ]; then
        print_info "Fazendo backup das configurações existentes..."
        mkdir -p "$BACKUP_DIR"
        [ -d "$HOME/.config/hypr" ] && cp -r "$HOME/.config/hypr" "$BACKUP_DIR/" 2>/dev/null || true
        [ -d "$HOME/.config/kitty" ] && cp -r "$HOME/.config/kitty" "$BACKUP_DIR/" 2>/dev/null || true
        print_success "Backup criado em: $BACKUP_DIR"
    fi
}

ask_drivers() {
    print_header "Seleção de Drivers Gráficos"
    local detection=$(detect_hardware)
    local has_intel=$(echo "$detection" | awk '{print $1}')
    local has_nvidia=$(echo "$detection" | awk '{print $2}')
    local has_amd=$(echo "$detection" | awk '{print $3}')
    
    echo ""
    echo "Quais drivers você deseja instalar?"
    echo ""
    
    if [ "$has_intel" = "true" ]; then
        read -p "$(echo -e ${GREEN}✓${NC}) Instalar drivers Intel? [S/n]: " response
    else
        read -p "Instalar drivers Intel? [s/N]: " response
    fi
    response=${response:-$( [ "$has_intel" = "true" ] && echo "s" || echo "n" )}
    [[ "$response" =~ ^[Ss]$ ]] && INSTALL_INTEL=true
    
    if [ "$has_nvidia" = "true" ]; then
        read -p "$(echo -e ${GREEN}✓${NC}) Instalar drivers NVIDIA? [S/n]: " response
    else
        read -p "Instalar drivers NVIDIA? [s/N]: " response
    fi
    response=${response:-$( [ "$has_nvidia" = "true" ] && echo "s" || echo "n" )}
    [[ "$response" =~ ^[Ss]$ ]] && INSTALL_NVIDIA=true
    
    if [ "$has_amd" = "true" ]; then
        read -p "$(echo -e ${GREEN}✓${NC}) Instalar drivers AMD? [S/n]: " response
    else
        read -p "Instalar drivers AMD? [s/N]: " response
    fi
    response=${response:-$( [ "$has_amd" = "true" ] && echo "s" || echo "n" )}
    [[ "$response" =~ ^[Ss]$ ]] && INSTALL_AMD=true
    
    echo ""
    print_info "Drivers selecionados:"
    $INSTALL_INTEL && echo "  • Intel"
    $INSTALL_NVIDIA && echo "  • NVIDIA"
    $INSTALL_AMD && echo "  • AMD"
    
    if ! $INSTALL_INTEL && ! $INSTALL_NVIDIA && ! $INSTALL_AMD; then
        print_warning "Nenhum driver selecionado! Hyprland pode não funcionar corretamente."
    fi
}

ask_keyboard_layout() {
    print_header "Configuração do Teclado"
    echo "Layouts: 1) br  2) us  3) pt  4) es  5) Outro"
    echo ""
    read -p "Escolha o layout [1]: " choice
    choice=${choice:-1}
    
    case $choice in
        1) KEYBOARD_LAYOUT="br" ;;
        2) KEYBOARD_LAYOUT="us" ;;
        3) KEYBOARD_LAYOUT="pt" ;;
        4) KEYBOARD_LAYOUT="es" ;;
        5) read -p "Digite o código (ex: de, fr): " custom_layout; KEYBOARD_LAYOUT="$custom_layout" ;;
        *) print_warning "Opção inválida, usando 'br'"; KEYBOARD_LAYOUT="br" ;;
    esac
    print_success "Layout selecionado: $KEYBOARD_LAYOUT"
}

#############################################################################
# Funções de Instalação
#############################################################################

install_base_packages() {
    print_header "Instalando Pacotes Base"
    local packages=("hyprland" "waybar" "wofi" "kitty" "swww" "wl-clipboard" "curl" "pipewire" "pipewire-pulse")
    
    print_info "Atualizando repositórios..."
    sudo pacman -Sy --noconfirm
    
    print_info "Instalando pacotes base..."
    for package in "${packages[@]}"; do
        if sudo pacman -S --noconfirm "$package"; then
            print_success "Instalado: $package"
        else
            print_error "Falha ao instalar: $package"
            return 1
        fi
    done
    print_success "Pacotes base instalados!"
}

install_intel_drivers() {
    $INSTALL_INTEL || return 0
    print_header "Instalando Drivers Intel"
    local packages=("intel-media-driver" "libva-intel-driver" "vulkan-intel")
    for package in "${packages[@]}"; do
        sudo pacman -S --noconfirm "$package" && print_success "Instalado: $package" || print_warning "Não instalado: $package"
    done
    print_success "Drivers Intel instalados!"
}

install_nvidia_drivers() {
    $INSTALL_NVIDIA || return 0
    print_header "Instalando Drivers NVIDIA"
    local packages=("nvidia" "nvidia-utils" "nvidia-settings")
    for package in "${packages[@]}"; do
        sudo pacman -S --noconfirm "$package" || { print_error "Falha ao instalar: $package"; return 1; }
        print_success "Instalado: $package"
    done
    
    print_info "Configurando módulos NVIDIA..."
    sudo bash -c "cat > /etc/modprobe.d/nvidia.conf << 'EOF'
options nvidia-drm modeset=1
options nvidia NVreg_PreserveVideoMemoryAllocations=1
options nvidia NVreg_TemporaryFilePath=/var/tmp
options nvidia NVreg_DynamicPowerManagement=0x02
EOF"
    print_success "Drivers NVIDIA configurados!"
}

install_amd_drivers() {
    $INSTALL_AMD || return 0
    print_header "Instalando Drivers AMD"
    local packages=("xf86-video-amdgpu" "vulkan-radeon" "libva-mesa-driver" "mesa-vdpau")
    for package in "${packages[@]}"; do
        sudo pacman -S --noconfirm "$package" && print_success "Instalado: $package" || print_warning "Não instalado: $package"
    done
    print_success "Drivers AMD instalados!"
}

configure_hyprland() {
    print_header "Configurando Hyprland"
    mkdir -p "$HOME/.config/hypr"
    
    local env_vars=""
    $INSTALL_INTEL && env_vars+="env = LIBVA_DRIVER_NAME,i965\nenv = __GLX_VENDOR_LIBRARY_NAME,intel\n"
    $INSTALL_NVIDIA && env_vars+="env = LIBVA_DRIVER_NAME,nvidia\nenv = __GLX_VENDOR_LIBRARY_NAME,nvidia\nenv = WLR_NO_HARDWARE_CURSORS,1\n"
    $INSTALL_AMD && env_vars+="env = LIBVA_DRIVER_NAME,radeonsi\n"
    
    cat > "$HOME/.config/hypr/hyprland.conf" << EOF
# Configuração do Hyprland - Gerado: $(date '+%Y-%m-%d %H:%M:%S')
autogenerated = 0
monitor=,highrr,auto,1

# Variáveis de ambiente
$(echo -e "$env_vars")

\$terminal = kitty
\$menu = wofi --show drun

exec-once = swww-daemon
exec-once = waybar

general {
    gaps_in = 5
    gaps_out = 10
    border_size = 3
    col.active_border = rgb(009c3b) rgb(ffdf00) 45deg
    col.inactive_border = rgba(595959aa)
    layout = dwindle
}

decoration {
    rounding = 10
    blur {
        enabled = true
        size = 3
        passes = 1
    }
    drop_shadow = true
    shadow_range = 4
    shadow_render_power = 3
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

dwindle {
    pseudotile = true
    preserve_split = true
}

input {
    kb_layout = $KEYBOARD_LAYOUT
    follow_mouse = 1
    touchpad {
        natural_scroll = true
    }
}

gestures {
    workspace_swipe = true
}

# Atalhos principais
bind = SUPER, Return, exec, \$terminal
bind = SUPER, Q, killactive,
bind = SUPER SHIFT, E, exit,
bind = SUPER, D, exec, \$menu
bind = SUPER, F, fullscreen,
bind = SUPER, V, togglefloating,

# Navegação
bind = SUPER, left, movefocus, l
bind = SUPER, right, movefocus, r
bind = SUPER, up, movefocus, u
bind = SUPER, down, movefocus, d

# Movimentação
bind = SUPER SHIFT, left, movewindow, l
bind = SUPER SHIFT, right, movewindow, r
bind = SUPER SHIFT, up, movewindow, u
bind = SUPER SHIFT, down, movewindow, d

# Workspaces
bind = SUPER, 1, workspace, 1
bind = SUPER, 2, workspace, 2
bind = SUPER, 3, workspace, 3
bind = SUPER, 4, workspace, 4
bind = SUPER, 5, workspace, 5
bind = SUPER, 6, workspace, 6
bind = SUPER, 7, workspace, 7
bind = SUPER, 8, workspace, 8
bind = SUPER, 9, workspace, 9
bind = SUPER, 0, workspace, 10

bind = SUPER SHIFT, 1, movetoworkspace, 1
bind = SUPER SHIFT, 2, movetoworkspace, 2
bind = SUPER SHIFT, 3, movetoworkspace, 3
bind = SUPER SHIFT, 4, movetoworkspace, 4
bind = SUPER SHIFT, 5, movetoworkspace, 5
bind = SUPER SHIFT, 6, movetoworkspace, 6
bind = SUPER SHIFT, 7, movetoworkspace, 7
bind = SUPER SHIFT, 8, movetoworkspace, 8
bind = SUPER SHIFT, 9, movetoworkspace, 9
bind = SUPER SHIFT, 0, movetoworkspace, 10

# Mouse
bindm = SUPER, mouse:272, movewindow
bindm = SUPER, mouse:273, resizewindow
bind = SUPER, mouse_down, workspace, e+1
bind = SUPER, mouse_up, workspace, e-1
EOF
    print_success "Configuração do Hyprland criada!"
}

configure_kitty() {
    print_header "Configurando Kitty Terminal"
    mkdir -p "$HOME/.config/kitty"
    
    cat > "$HOME/.config/kitty/kitty.conf" << 'EOF'
# Configuração do Kitty - Gerado automaticamente
background_opacity 0.85
confirm_os_window_close 0
font_family JetBrains Mono
font_size 11.0
cursor_shape block
scrollback_lines 10000
copy_on_select yes

# Tema Tokyo Night
foreground #dddddd
background #1a1b26
cursor #c0caf5
color0 #15161e
color1 #f7768e
color2 #9ece6a
color3 #e0af68
color4 #7aa2f7
color5 #bb9af7
color6 #7dcfff
color7 #a9b1d6
color8 #414868
color9 #f7768e
color10 #9ece6a
color11 #e0af68
color12 #7aa2f7
color13 #bb9af7
color14 #7dcfff
color15 #c0caf5
EOF
    print_success "Configuração do Kitty criada!"
}

configure_network() {
    print_header "Configurando NetworkManager"
    sudo mkdir -p /etc/NetworkManager/conf.d/
    echo -e "[device]\nwifi.backend=iwd" | sudo tee /etc/NetworkManager/conf.d/wifi_backend.conf > /dev/null
    print_success "NetworkManager configurado!"
}

install_liquorix() {
    print_header "Instalando Kernel Liquorix"
    print_warning "O kernel Liquorix será instalado via script remoto."
    read -p "Deseja continuar? [s/N]: " response
    [[ ! "$response" =~ ^[Ss]$ ]] && { print_info "Instalação do Liquorix pulada."; return 0; }
    
    print_info "Baixando script do Liquorix..."
    if ! curl -fsSL 'https://liquorix.net/install-liquorix.sh' -o /tmp/install-liquorix.sh; then
        print_error "Falha ao baixar script"
        return 1
    fi
    
    if sudo bash /tmp/install-liquorix.sh; then
        print_success "Kernel Liquorix instalado!"
        rm -f /tmp/install-liquorix.sh
    else
        print_error "Falha na instalação do Liquorix"
        rm -f /tmp/install-liquorix.sh
        return 1
    fi
}

configure_bootloader() {
    print_header "Configurando Bootloader"
    
    if $INSTALL_NVIDIA; then
        sudo cp /etc/mkinitcpio.conf /etc/mkinitcpio.conf.backup
        if ! grep -q "nvidia" /etc/mkinitcpio.conf; then
            sudo sed -i 's/MODULES=(\(.*\))/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm \1)/' /etc/mkinitcpio.conf
            print_success "Módulos NVIDIA adicionados"
        fi
    fi
    
    if $INSTALL_INTEL; then
        if ! grep -q "i915" /etc/mkinitcpio.conf; then
            sudo sed -i 's/MODULES=(\(.*\))/MODULES=(i915 \1)/' /etc/mkinitcpio.conf
            print_success "Módulos Intel adicionados"
        fi
    fi
    
    print_info "Regenerando initramfs..."
    sudo mkinitcpio -P && print_success "Initramfs regenerado!" || { print_error "Falha ao regenerar initramfs"; return 1; }
    
    if [ -f /boot/grub/grub.cfg ]; then
        print_info "Atualizando GRUB..."
        sudo grub-mkconfig -o /boot/grub/grub.cfg && print_success "GRUB atualizado!" || print_error "Falha ao atualizar GRUB"
    fi
}

enable_services() {
    print_header "Habilitando Serviços"
    for service in iwd NetworkManager; do
        sudo systemctl enable "$service" 2>/dev/null && print_success "Habilitado: $service" || print_warning "Não habilitado: $service"
    done
}

#############################################################################
# Função Principal
#############################################################################

main() {
    clear
    echo -e "${BOLD}${MAGENTA}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║        🚀 Instalador Hyprland para Arch Linux 🚀         ║"
    echo "║                    Versão $VERSION                           ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}\n"
    
    print_header "Verificações de Pré-requisitos"
    check_root
    check_arch
    check_sudo
    check_disk_space
    
    sudo touch "$LOG_FILE"
    log_message "=== Iniciando instalação do Hyprland ==="
    
    echo ""
    print_warning "Este script irá instalar e configurar o Hyprland."
    echo "  • Instalação de pacotes do sistema"
    echo "  • Configuração de drivers gráficos"
    echo "  • Criação de arquivos de configuração"
    echo ""
    read -p "Deseja continuar? [s/N]: " response
    [[ ! "$response" =~ ^[Ss]$ ]] && { print_info "Instalação cancelada."; exit 0; }
    
    backup_config
    ask_keyboard_layout
    ask_drivers
    
    echo ""
    print_warning "Iniciando instalação..."
    sleep 2
    
    install_base_packages
    install_intel_drivers
    install_nvidia_drivers
    install_amd_drivers
    configure_hyprland
    configure_kitty
    configure_network
    install_liquorix
    configure_bootloader
    enable_services
    
    print_header "✓ Instalação Concluída!"
    echo -e "${GREEN}${BOLD}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║          🎉 Instalação concluída com sucesso! 🎉          ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}\n"
    
    print_success "Hyprland instalado com sucesso!"
    print_info "Configurações: ~/.config/hypr/ e ~/.config/kitty/"
    [ -d "$BACKUP_DIR" ] && print_info "Backup: $BACKUP_DIR"
    print_info "Logs: $LOG_FILE"
    
    echo ""
    print_warning "Para aplicar as alterações, reinicie o sistema."
    echo ""
    read -p "Deseja reiniciar agora? [s/N]: " reboot_response
    
    if [[ "$reboot_response" =~ ^[Ss]$ ]]; then
        print_info "Reiniciando em 5 segundos..."
        sleep 5
        sudo systemctl reboot
    else
        print_info "Reinicie manualmente: ${CYAN}sudo systemctl reboot${NC}"
        echo ""
        print_info "Após reiniciar, execute: ${CYAN}Hyprland${NC}"
    fi
}

main "$@"
```
