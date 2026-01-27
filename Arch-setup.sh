
1|#!/bin/bash
2|#############################################################################
3|# Script de Instalação e Configuração do Hyprland para Arch Linux
4|# Versão: 2.0 | Licença: GNU GPL v3.0
5|#############################################################################
6|
7|set -euo pipefail
8|
9|# Variáveis globais
10|readonly SCRIPT_NAME="Arch Hyprland Setup"
11|readonly VERSION="2.0"
12|readonly LOG_FILE="/var/log/arch-setup-install.log"
13|readonly BACKUP_DIR="$HOME/.config-backup-$(date +%Y%m%d_%H%M%S)"
14|readonly MIN_DISK_SPACE_GB=5
15|
16|# Cores
17|readonly RED='33[0;31m'
18|readonly GREEN='33[0;32m'
19|readonly YELLOW='33[1;33m'
20|readonly BLUE='33[0;34m'
21|readonly MAGENTA='33[0;35m'
22|readonly CYAN='33[0;36m'
23|readonly NC='33[0m'
24|readonly BOLD='33[1m'
25|
26|# Variáveis de controle
27|INSTALL_INTEL=false
28|INSTALL_NVIDIA=false
29|INSTALL_AMD=false
30|KEYBOARD_LAYOUT="br"
31|
32|#############################################################################
33|# Funções Utilitárias
34|#############################################################################
35|
36|print_success() {
37|    echo -e "${GREEN}✓${NC} $1"
38|    log_message "SUCCESS: $1"
39|}
40|
41|print_error() {
42|    echo -e "${RED}✗${NC} $1" >&2
43|    log_message "ERROR: $1"
44|}
45|
46|print_warning() {
47|    echo -e "${YELLOW}⚠${NC} $1"
48|    log_message "WARNING: $1"
49|}
50|
51|print_info() {
52|    echo -e "${BLUE}ℹ${NC} $1"
53|    log_message "INFO: $1"
54|}
55|
56|print_header() {
57|    echo -e "\n${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
58|    echo -e "${BOLD}${CYAN}  $1${NC}"
59|    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
60|}
61|
62|log_message() {
63|    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | sudo tee -a "$LOG_FILE" > /dev/null 2>&1 || true
64|}
65|
66|cleanup() {
67|    local exit_code=$?
68|    if [ $exit_code -ne 0 ]; then
69|        print_error "Script interrompido com erro (código: $exit_code)"
70|        print_warning "Logs em: $LOG_FILE"
71|        [ -d "$BACKUP_DIR" ] && print_info "Backup em: $BACKUP_DIR"
72|    fi
73|}
74|
75|trap cleanup EXIT
76|
77|check_root() {
78|    if [ "$EUID" -eq 0 ]; then
79|        print_error "Não execute como root! O script pedirá sudo quando necessário."
80|        exit 1
81|    fi
82|}
83|
84|check_arch() {
85|    if [ ! -f /etc/arch-release ]; then
86|        print_error "Este script é apenas para Arch Linux!"
87|        exit 1
88|    fi
89|    print_success "Sistema Arch Linux detectado"
90|}
91|
92|check_sudo() {
93|    if ! sudo -v; then
94|        print_error "Este script requer privilégios sudo"
95|        exit 1
96|    fi
97|    print_success "Permissões sudo verificadas"
98|    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
99|}
100|
101|check_disk_space() {
102|    local available_space=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
103|    if [ "$available_space" -lt "$MIN_DISK_SPACE_GB" ]; then
104|        print_error "Espaço insuficiente! Necessário: ${MIN_DISK_SPACE_GB}GB | Disponível: ${available_space}GB"
105|        exit 1
106|    fi
107|    print_success "Espaço em disco suficiente (${available_space}GB disponível)"
108|}
109|
110|detect_hardware() {
111|    print_info "Detectando hardware do sistema..."
112|    local has_intel=false has_nvidia=false has_amd=false
113|    
114|    lspci | grep -i "VGA.*Intel" > /dev/null 2>&1 && has_intel=true && print_info "GPU Intel detectada"
115|    lspci | grep -i "VGA.*NVIDIA\|3D.*NVIDIA" > /dev/null 2>&1 && has_nvidia=true && print_info "GPU NVIDIA detectada"
116|    lspci | grep -i "VGA.*AMD\|VGA.*ATI" > /dev/null 2>&1 && has_amd=true && print_info "GPU AMD detectada"
117|    
118|    echo "$has_intel $has_nvidia $has_amd"
119|}
120|
121|backup_config() {
122|    if [ -d "$HOME/.config/hypr" ] || [ -d "$HOME/.config/kitty" ]; then
123|        print_info "Fazendo backup das configurações existentes..."
124|        mkdir -p "$BACKUP_DIR"
125|        [ -d "$HOME/.config/hypr" ] && cp -r "$HOME/.config/hypr" "$BACKUP_DIR/" 2>/dev/null || true
126|        [ -d "$HOME/.config/kitty" ] && cp -r "$HOME/.config/kitty" "$BACKUP_DIR/" 2>/dev/null || true
127|        print_success "Backup criado em: $BACKUP_DIR"
128|    fi
129|}
130|
131|ask_drivers() {
132|    print_header "Seleção de Drivers Gráficos"
133|    local detection=$(detect_hardware)
134|    local has_intel=$(echo "$detection" | awk '{print $1}')
135|    local has_nvidia=$(echo "$detection" | awk '{print $2}')
136|    local has_amd=$(echo "$detection" | awk '{print $3}')
137|    
138|    echo ""
139|    echo "Quais drivers você deseja instalar?"
140|    echo ""
141|    
142|    if [ "$has_intel" = "true" ]; then
143|        read -p "$(echo -e ${GREEN}✓${NC}) Instalar drivers Intel? [S/n]: " response
144|    else
145|        read -p "Instalar drivers Intel? [s/N]: " response
146|    fi
147|    response=${response:-$( [ "$has_intel" = "true" ] && echo "s" || echo "n" )}
148|    [[ "$response" =~ ^[Ss]$ ]] && INSTALL_INTEL=true
149|    
150|    if [ "$has_nvidia" = "true" ]; then
151|        read -p "$(echo -e ${GREEN}✓${NC}) Instalar drivers NVIDIA? [S/n]: " response
152|    else
153|        read -p "Instalar drivers NVIDIA? [s/N]: " response
154|    fi
155|    response=${response:-$( [ "$has_nvidia" = "true" ] && echo "s" || echo "n" )}
156|    [[ "$response" =~ ^[Ss]$ ]] && INSTALL_NVIDIA=true
157|    
158|    if [ "$has_amd" = "true" ]; then
159|        read -p "$(echo -e ${GREEN}✓${NC}) Instalar drivers AMD? [S/n]: " response
160|    else
161|        read -p "Instalar drivers AMD? [s/N]: " response
162|    fi
163|    response=${response:-$( [ "$has_amd" = "true" ] && echo "s" || echo "n" )}
164|    [[ "$response" =~ ^[Ss]$ ]] && INSTALL_AMD=true
165|    
166|    echo ""
167|    print_info "Drivers selecionados:"
168|    $INSTALL_INTEL && echo "  • Intel"
169|    $INSTALL_NVIDIA && echo "  • NVIDIA"
170|    $INSTALL_AMD && echo "  • AMD"
171|    
172|    if ! $INSTALL_INTEL && ! $INSTALL_NVIDIA && ! $INSTALL_AMD; then
173|        print_warning "Nenhum driver selecionado! Hyprland pode não funcionar corretamente."
174|    fi
175|}
176|
177|ask_keyboard_layout() {
178|    print_header "Configuração do Teclado"
179|    echo "Layouts: 1) br  2) us  3) pt  4) es  5) Outro"
180|    echo ""
181|    read -p "Escolha o layout [1]: " choice
182|    choice=${choice:-1}
183|    
184|    case $choice in
185|        1) KEYBOARD_LAYOUT="br" ;;
186|        2) KEYBOARD_LAYOUT="us" ;;
187|        3) KEYBOARD_LAYOUT="pt" ;;
188|        4) KEYBOARD_LAYOUT="es" ;;
189|        5) read -p "Digite o código (ex: de, fr): " custom_layout; KEYBOARD_LAYOUT="$custom_layout" ;;
190|        *) print_warning "Opção inválida, usando 'br'"; KEYBOARD_LAYOUT="br" ;;
191|    esac
192|    print_success "Layout selecionado: $KEYBOARD_LAYOUT"
193|}
194|
195|#############################################################################
196|# Funções de Instalação
197|#############################################################################
198|
199|install_base_packages() {
200|    print_header "Instalando Pacotes Base"
201|    local packages=("hyprland" "waybar" "wofi" "kitty" "swww" "wl-clipboard" "curl" "pipewire" "pipewire-pulse")
202|    
203|    print_info "Atualizando repositórios..."
204|    sudo pacman -Sy --noconfirm
205|    
206|    print_info "Instalando pacotes base..."
207|    for package in "${packages[@]}"; do
208|        if sudo pacman -S --noconfirm "$package"; then
209|            print_success "Instalado: $package"
210|        else
211|            print_error "Falha ao instalar: $package"
212|            return 1
213|        fi
214|    done
215|    print_success "Pacotes base instalados!"
216|}
217|
218|install_intel_drivers() {
219|    $INSTALL_INTEL || return 0
220|    print_header "Instalando Drivers Intel"
221|    local packages=("intel-media-driver" "libva-intel-driver" "vulkan-intel")
222|    for package in "${packages[@]}"; do
223|        sudo pacman -S --noconfirm "$package" && print_success "Instalado: $package" || print_warning "Não instalado: $package"
224|    done
225|    print_success "Drivers Intel instalados!"
226|}
227|
228|install_nvidia_drivers() {
229|    $INSTALL_NVIDIA || return 0
230|    print_header "Instalando Drivers NVIDIA"
231|    local packages=("nvidia" "nvidia-utils" "nvidia-settings")
232|    for package in "${packages[@]}"; do
233|        sudo pacman -S --noconfirm "$package" || { print_error "Falha ao instalar: $package"; return 1; }
234|        print_success "Instalado: $package"
235|    done
236|    
237|    print_info "Configurando módulos NVIDIA..."
238|    sudo bash -c "cat > /etc/modprobe.d/nvidia.conf << 'EOF'
239|options nvidia-drm modeset=1
240|options nvidia NVreg_PreserveVideoMemoryAllocations=1
241|options nvidia NVreg_TemporaryFilePath=/var/tmp
242|options nvidia NVreg_DynamicPowerManagement=0x02
243|EOF"
244|    print_success "Drivers NVIDIA configurados!"
245|}
246|
247|install_amd_drivers() {
248|    $INSTALL_AMD || return 0
249|    print_header "Instalando Drivers AMD"
250|    local packages=("xf86-video-amdgpu" "vulkan-radeon" "libva-mesa-driver" "mesa-vdpau")
251|    for package in "${packages[@]}"; do
252|        sudo pacman -S --noconfirm "$package" && print_success "Instalado: $package" || print_warning "Não instalado: $package"
253|    done
254|    print_success "Drivers AMD instalados!"
255|}
256|
257|configure_hyprland() {
258|    print_header "Configurando Hyprland"
259|    mkdir -p "$HOME/.config/hypr"
260|    
261|    local env_vars=""
262|    $INSTALL_INTEL && env_vars+="env = LIBVA_DRIVER_NAME,i965\nenv = __GLX_VENDOR_LIBRARY_NAME,intel\n"
263|    $INSTALL_NVIDIA && env_vars+="env = LIBVA_DRIVER_NAME,nvidia\nenv = __GLX_VENDOR_LIBRARY_NAME,nvidia\nenv = WLR_NO_HARDWARE_CURSORS,1\n"
264|    $INSTALL_AMD && env_vars+="env = LIBVA_DRIVER_NAME,radeonsi\n"
265|    
266|    cat > "$HOME/.config/hypr/hyprland.conf" << EOF
267|# Configuração do Hyprland - Gerado: $(date '+%Y-%m-%d %H:%M:%S')
268|autogenerated = 0
269|monitor=,highrr,auto,1
270|
271|# Variáveis de ambiente
272|$(echo -e "$env_vars")
273|
274|\$terminal = kitty
275|\$menu = wofi --show drun
276|
277|exec-once = swww-daemon
278|exec-once = waybar
279|
280|general {
281|    gaps_in = 5
282|    gaps_out = 10
283|    border_size = 3
284|    col.active_border = rgb(009c3b) rgb(ffdf00) 45deg
285|    col.inactive_border = rgba(595959aa)
286|    layout = dwindle
287|}
288|
289|decoration {
290|    rounding = 10
291|    blur {
292|        enabled = true
293|        size = 3
294|        passes = 1
295|    }
296|    drop_shadow = true
297|    shadow_range = 4
298|    shadow_render_power = 3
299|}
300|
301|animations {
302|    enabled = true
303|    bezier = myBezier, 0.05, 0.9, 0.1, 1.05
304|    animation = windows, 1, 7, myBezier
305|    animation = windowsOut, 1, 7, default, popin 80%
306|    animation = border, 1, 10, default
307|    animation = fade, 1, 7, default
308|    animation = workspaces, 1, 6, default
309|}
310|
311|dwindle {
312|    pseudotile = true
313|    preserve_split = true
314|}
315|
316|input {
317|    kb_layout = $KEYBOARD_LAYOUT
318|    follow_mouse = 1
319|    touchpad {
320|        natural_scroll = true
321|    }
322|}
323|
324|gestures {
325|    workspace_swipe = true
326|}
327|
328|# Atalhos principais
329|bind = SUPER, Return, exec, \$terminal
330|bind = SUPER, Q, killactive,
331|bind = SUPER SHIFT, E, exit,
332|bind = SUPER, D, exec, \$menu
333|bind = SUPER, F, fullscreen,
334|bind = SUPER, V, togglefloating,
335|
336|# Navegação
337|bind = SUPER, left, movefocus, l
338|bind = SUPER, right, movefocus, r
339|bind = SUPER, up, movefocus, u
340|bind = SUPER, down, movefocus, d
341|
342|# Movimentação
343|bind = SUPER SHIFT, left, movewindow, l
344|bind = SUPER SHIFT, right, movewindow, r
345|bind = SUPER SHIFT, up, movewindow, u
346|bind = SUPER SHIFT, down, movewindow, d
347|
348|# Workspaces
349|bind = SUPER, 1, workspace, 1
350|bind = SUPER, 2, workspace, 2
351|bind = SUPER, 3, workspace, 3
352|bind = SUPER, 4, workspace, 4
353|bind = SUPER, 5, workspace, 5
354|bind = SUPER, 6, workspace, 6
355|bind = SUPER, 7, workspace, 7
356|bind = SUPER, 8, workspace, 8
357|bind = SUPER, 9, workspace, 9
358|bind = SUPER, 0, workspace, 10
359|
360|bind = SUPER SHIFT, 1, movetoworkspace, 1
361|bind = SUPER SHIFT, 2, movetoworkspace, 2
362|bind = SUPER SHIFT, 3, movetoworkspace, 3
363|bind = SUPER SHIFT, 4, movetoworkspace, 4
364|bind = SUPER SHIFT, 5, movetoworkspace, 5
365|bind = SUPER SHIFT, 6, movetoworkspace, 6
366|bind = SUPER SHIFT, 7, movetoworkspace, 7
367|bind = SUPER SHIFT, 8, movetoworkspace, 8
368|bind = SUPER SHIFT, 9, movetoworkspace, 9
369|bind = SUPER SHIFT, 0, movetoworkspace, 10
370|
371|# Mouse
372|bindm = SUPER, mouse:272, movewindow
373|bindm = SUPER, mouse:273, resizewindow
374|bind = SUPER, mouse_down, workspace, e+1
375|bind = SUPER, mouse_up, workspace, e-1
376|EOF
377|    print_success "Configuração do Hyprland criada!"
378|}
379|
380|configure_kitty() {
381|    print_header "Configurando Kitty Terminal"
382|    mkdir -p "$HOME/.config/kitty"
383|    
384|    cat > "$HOME/.config/kitty/kitty.conf" << 'EOF'
385|# Configuração do Kitty - Gerado automaticamente
386|background_opacity 0.85
387|confirm_os_window_close 0
388|font_family JetBrains Mono
389|font_size 11.0
390|cursor_shape block
391|scrollback_lines 10000
392|copy_on_select yes
393|
394|# Tema Tokyo Night
395|foreground #dddddd
396|background #1a1b26
397|cursor #c0caf5
398|color0 #15161e
399|color1 #f7768e
400|color2 #9ece6a
401|color3 #e0af68
402|color4 #7aa2f7
403|color5 #bb9af7
404|color6 #7dcfff
405|color7 #a9b1d6
406|color8 #414868
407|color9 #f7768e
408|color10 #9ece6a
409|color11 #e0af68
410|color12 #7aa2f7
411|color13 #bb9af7
412|color14 #7dcfff
413|color15 #c0caf5
414|EOF
415|    print_success "Configuração do Kitty criada!"
416|}
417|
418|configure_network() {
419|    print_header "Configurando NetworkManager"
420|    sudo mkdir -p /etc/NetworkManager/conf.d/
421|    echo -e "[device]\nwifi.backend=iwd" | sudo tee /etc/NetworkManager/conf.d/wifi_backend.conf > /dev/null
422|    print_success "NetworkManager configurado!"
423|}
424|
425|install_liquorix() {
426|    print_header "Instalando Kernel Liquorix"
427|    print_warning "O kernel Liquorix será instalado via script remoto."
428|    read -p "Deseja continuar? [s/N]: " response
429|    [[ ! "$response" =~ ^[Ss]$ ]] && { print_info "Instalação do Liquorix pulada."; return 0; }
430|    
431|    print_info "Baixando script do Liquorix..."
432|    if ! curl -fsSL 'https://liquorix.net/install-liquorix.sh' -o /tmp/install-liquorix.sh; then
433|        print_error "Falha ao baixar script"
434|        return 1
435|    fi
436|    
437|    if sudo bash /tmp/install-liquorix.sh; then
438|        print_success "Kernel Liquorix instalado!"
439|        rm -f /tmp/install-liquorix.sh
440|    else
441|        print_error "Falha na instalação do Liquorix"
442|        rm -f /tmp/install-liquorix.sh
443|        return 1
444|    fi
445|}
446|
447|configure_bootloader() {
448|    print_header "Configurando Bootloader"
449|    
450|    if $INSTALL_NVIDIA; then
451|        sudo cp /etc/mkinitcpio.conf /etc/mkinitcpio.conf.backup
452|        if ! grep -q "nvidia" /etc/mkinitcpio.conf; then
453|            sudo sed -i 's/MODULES=(\(.*\))/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm \1)/' /etc/mkinitcpio.conf
454|            print_success "Módulos NVIDIA adicionados"
455|        fi
456|    fi
457|    
458|    if $INSTALL_INTEL; then
459|        if ! grep -q "i915" /etc/mkinitcpio.conf; then
460|            sudo sed -i 's/MODULES=(\(.*\))/MODULES=(i915 \1)/' /etc/mkinitcpio.conf
461|            print_success "Módulos Intel adicionados"
462|        fi
463|    fi
464|    
465|    print_info "Regenerando initramfs..."
466|    sudo mkinitcpio -P && print_success "Initramfs regenerado!" || { print_error "Falha ao regenerar initramfs"; return 1; }
467|    
468|    if [ -f /boot/grub/grub.cfg ]; then
469|        print_info "Atualizando GRUB..."
470|        sudo grub-mkconfig -o /boot/grub/grub.cfg && print_success "GRUB atualizado!" || print_error "Falha ao atualizar GRUB"
471|    fi
472|}
473|
474|enable_services() {
475|    print_header "Habilitando Serviços"
476|    for service in iwd NetworkManager; do
477|        sudo systemctl enable "$service" 2>/dev/null && print_success "Habilitado: $service" || print_warning "Não habilitado: $service"
478|    done
479|}
480|
481|#############################################################################
482|# Função Principal
483|#############################################################################
484|
485|main() {
486|    clear
487|    echo -e "${BOLD}${MAGENTA}"
488|    echo "╔════════════════════════════════════════════════════════════╗"
489|    echo "║        🚀 Instalador Hyprland para Arch Linux 🚀         ║"
490|    echo "║                    Versão $VERSION                           ║"
491|    echo "╚════════════════════════════════════════════════════════════╝"
492|    echo -e "${NC}\n"
493|    
494|    print_header "Verificações de Pré-requisitos"
495|    check_root
496|    check_arch
497|    check_sudo
498|    check_disk_space
499|    
500|    sudo touch "$LOG_FILE"
501|    log_message "=== Iniciando instalação do Hyprland ==="
502|    
503|    echo ""
504|    print_warning "Este script irá instalar e configurar o Hyprland."
505|    echo "  • Instalação de pacotes do sistema"
506|    echo "  • Configuração de drivers gráficos"
507|    echo "  • Criação de arquivos de configuração"
508|    echo ""
509|    read -p "Deseja continuar? [s/N]: " response
510|    [[ ! "$response" =~ ^[Ss]$ ]] && { print_info "Instalação cancelada."; exit 0; }
511|    
512|    backup_config
513|    ask_keyboard_layout
514|    ask_drivers
515|    
516|    echo ""
517|    print_warning "Iniciando instalação..."
518|    sleep 2
519|    
520|    install_base_packages
521|    install_intel_drivers
522|    install_nvidia_drivers
523|    install_amd_drivers
524|    configure_hyprland
525|    configure_kitty
526|    configure_network
527|    install_liquorix
528|    configure_bootloader
529|    enable_services
530|    
531|    print_header "✓ Instalação Concluída!"
532|    echo -e "${GREEN}${BOLD}"
533|    echo "╔════════════════════════════════════════════════════════════╗"
534|    echo "║          🎉 Instalação concluída com sucesso! 🎉          ║"
535|    echo "╚════════════════════════════════════════════════════════════╝"
536|    echo -e "${NC}\n"
537|    
538|    print_success "Hyprland instalado com sucesso!"
539|    print_info "Configurações: ~/.config/hypr/ e ~/.config/kitty/"
540|    [ -d "$BACKUP_DIR" ] && print_info "Backup: $BACKUP_DIR"
541|    print_info "Logs: $LOG_FILE"
542|    
543|    echo ""
544|    print_warning "Para aplicar as alterações, reinicie o sistema."
545|    echo ""
546|    read -p "Deseja reiniciar agora? [s/N]: " reboot_response
547|    
548|    if [[ "$reboot_response" =~ ^[Ss]$ ]]; then
549|        print_info "Reiniciando em 5 segundos..."
550|        sleep 5
551|        sudo systemctl reboot
552|    else
553|        print_info "Reinicie manualmente: ${CYAN}sudo systemctl reboot${NC}"
554|        echo ""
555|        print_info "Após reiniciar, execute: ${CYAN}Hyprland${NC}"
556|    fi
557|}
558|
559|main "$@"
560|
