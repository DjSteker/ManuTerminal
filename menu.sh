#!/bin/bash
# Archivo de configuración
CONFIG_FILE="programas.txt"

# Verificar si existe el archivo de configuración
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Creando archivo de configuración de ejemplo: $CONFIG_FILE"
    sleep 0.40
    cat > "$CONFIG_FILE" << EOF
firefox
gedit
calculator
htop
nautilus
vlc
gimp
code
sublime
terminal
EOF
    echo "Archivo creado. Edítalo para agregar tus programas."
    sleep 2
fi

# Leer programas del archivo
mapfile -t programas < "$CONFIG_FILE"

# Verificar si hay programas
if [[ ${#programas[@]} -eq 0 ]]; then
    echo "Error: El archivo $CONFIG_FILE está vacío. Añade al menos un programa."
    exit 1
fi

# --- Funciones de Mouse ---
enable_mouse_reporting() {
    echo -ne '\e[?1000h\e[?1006h'
}
disable_mouse_reporting() {
    echo -ne '\e[?1006l\e[?1000l'
}

# Desactivar eco y poner terminal en modo raw
stty -echo -icanon min 1 time 0 2>/dev/null

# Restaurar terminal al salir
function restore_tty {
    disable_mouse_reporting
    stty sane 2>/dev/null
    clear
    echo "Saliendo del launcher..."
    sleep 0.40
}
trap restore_tty EXIT

# --- Variables ---
declare -i filas_disponibles
declare -i cols_disponibles
declare -i num_programas
declare -i cuadros_por_fila
declare -i num_filas_cuadros
declare -i filas_visibles_cuadros
declare -i offset_fila=0
declare -i cuadro_alto=3
declare -i cuadro_ancho
declare -i max_len
declare -i seleccion=1
busqueda=""
declare -i last_type_time=0
programas_filtrados=()

# Preparar lista según búsqueda
function preparar_programas {
    programas_filtrados=()
    if [ -z "$busqueda" ]; then
        programas_filtrados=("${programas[@]}")
    else
        for p in "${programas[@]}"; do
            if [[ "${p,,}" == *"${busqueda}"* ]]; then
                programas_filtrados+=("$p")
            fi
        done
    fi
    num_programas=${#programas_filtrados[@]}
    if (( num_programas == 0 )); then
        seleccion=0
        return
    fi

    max_len=0
    for p in "${programas_filtrados[@]}"; do
        (( ${#p} > max_len )) && max_len=${#p}
    done

    cuadro_ancho=$((max_len + 8))
    if (( cuadro_ancho < 20 )); then cuadro_ancho=20; fi
    if (( cuadro_ancho > 40 )); then cuadro_ancho=40; fi

    # Ajuste: Validar selección después de filtrar
    if (( seleccion > num_programas )); then seleccion=num_programas; fi
    if (( seleccion < 1 )); then seleccion=1; fi
}

# Calcular dimensiones dinámicas
function calcular_dimensiones {
    filas_disponibles=$(tput lines)
    cols_disponibles=$(tput cols)
    cuadros_por_fila=$(( cols_disponibles / (cuadro_ancho + 4) ))
    if (( cuadros_por_fila == 0 )); then cuadros_por_fila=1; fi
    if (( num_programas < cuadros_por_fila )); then
        cuadros_por_fila=$num_programas
    fi
    num_filas_cuadros=$(( (num_programas + cuadros_por_fila - 1) / cuadros_por_fila ))
    filas_visibles_cuadros=$(( (filas_disponibles - 10) / (cuadro_alto + 2) ))
    if (( filas_visibles_cuadros < 1 )); then filas_visibles_cuadros=1; fi
    
    # Ajustar offset_fila para no salirse de los límites
    if (( offset_fila + filas_visibles_cuadros > num_filas_cuadros )); then
        offset_fila=$(( num_filas_cuadros - filas_visibles_cuadros ))
    fi
    if (( offset_fila < 0 )); then offset_fila=0; fi
}

# Ajustar offset según selección (garantiza que la selección esté visible)
function ajustar_offset {
    if (( num_programas == 0 )); then return; fi
    local fila_seleccion=$(( (seleccion - 1) / cuadros_por_fila ))
    if (( fila_seleccion < offset_fila )); then
        offset_fila=$fila_seleccion
    elif (( fila_seleccion >= offset_fila + filas_visibles_cuadros )); then
        offset_fila=$(( fila_seleccion - filas_visibles_cuadros + 1 ))
    fi
}

# Detectar clic en cuadro
function detectar_clic_cuadro() {
    local click_x=$1
    local click_y=$2
    for (( i=0; i<num_programas; i++ )); do
        local fila_relativa=$(( i / cuadros_por_fila ))
        local disp_fila=$(( fila_relativa - offset_fila ))
        if (( disp_fila < 0 || disp_fila >= filas_visibles_cuadros )); then continue; fi
        local col_relativa=$(( i % cuadros_por_fila ))
        local fila_cuadro=$(( 5 + disp_fila * (cuadro_alto + 2) ))
        local col_cuadro=$(( 4 + col_relativa * (cuadro_ancho + 4) ))
        if (( click_y >= fila_cuadro && click_y <= fila_cuadro + cuadro_alto && 
              click_x >= col_cuadro && click_x <= col_cuadro + cuadro_ancho )); then
            return $((i + 1))
        fi
    done
    return 0
}

# Dibujar cuadro
function dibujar_cuadro {
    local num=$1
    local programa="${programas_filtrados[$((num-1))]}"
    local i=$(( num - 1 ))
    local fila_relativa=$(( i / cuadros_por_fila ))
    local disp_fila=$(( fila_relativa - offset_fila ))
    if (( disp_fila < 0 || disp_fila >= filas_visibles_cuadros )); then return; fi
    local col_relativa=$(( i % cuadros_por_fila ))
    local fila_cuadro=$(( 5 + disp_fila * (cuadro_alto + 2) ))
    local col_cuadro=$(( 4 + col_relativa * (cuadro_ancho + 4) ))

    tput cup "$fila_cuadro" "$col_cuadro"
    if (( num == seleccion )); then
        tput setab 2; tput setaf 7
        printf "┌%s┐" "$(printf '─%.0s' $(seq 1 $((cuadro_ancho - 2))))"
        tput cup "$((fila_cuadro+1))" "$col_cuadro"
        printf "│ %- $((cuadro_ancho - 4))s │" "► ${programa:0:$((cuadro_ancho - 4))} ◄"
        tput cup "$((fila_cuadro+2))" "$col_cuadro"
        printf "└%s┘" "$(printf '─%.0s' $(seq 1 $((cuadro_ancho - 2))))"
    else
        tput setab 0; tput setaf 4
        printf "┌%s┐" "$(printf '─%.0s' $(seq 1 $((cuadro_ancho - 2))))"
        tput cup "$((fila_cuadro+1))" "$col_cuadro"
        printf "│ %- $((cuadro_ancho - 4))s │" "${programa:0:$((cuadro_ancho - 4))}"
        tput cup "$((fila_cuadro+2))" "$col_cuadro"
        printf "└%s┘" "$(printf '─%.0s' $(seq 1 $((cuadro_ancho - 2))))"
    fi
    tput sgr0
}

# Dibujar menú
function dibujar_menu {
    preparar_programas
    calcular_dimensiones
    ajustar_offset  # Asegura que la selección esté siempre visible
    clear
    tput cup 2 $(( (cols_disponibles - 25) / 2 ))
    tput bold; tput setaf 6
    printf "═══ LAUNCHER DE PROGRAMAS ═══"
    tput sgr0

    if (( num_programas == 0 )); then
        tput cup 10 10; tput setaf 1
        printf "No hay programas coincidentes con la búsqueda."
        tput sgr0
    else
        # Dibujar solo los cuadros visibles
        local primer_programa=$(( offset_fila * cuadros_por_fila + 1 ))
        local ultimo_programa=$(( (offset_fila + filas_visibles_cuadros) * cuadros_por_fila ))
        if (( ultimo_programa > num_programas )); then
            ultimo_programa=$num_programas
        fi
        for (( i=primer_programa; i<=ultimo_programa; i++ )); do
            dibujar_cuadro $i
        done
    fi

    # Indicadores de más arriba/abajo
    if (( offset_fila > 0 )); then
        tput cup 4 $((cols_disponibles/2 - 4)); tput setaf 3
        echo "▲ Más arriba"
    fi
    if (( offset_fila + filas_visibles_cuadros < num_filas_cuadros )); then
        tput cup $((filas_disponibles - 6)) $((cols_disponibles/2 - 4)); tput setaf 3
        echo "▼ Más abajo"
    fi

    tput cup $(( filas_disponibles - 4 )) 4; tput setaf 3
    printf "Usa flechas/rueda mouse • Enter/Clic ejecutar • Escribe para buscar • Ctrl+C/Q salir"
    tput sgr0

    if [ -n "$busqueda" ]; then
        tput cup $(( filas_disponibles - 3 )) 4; tput setaf 5
        printf "Búsqueda: %s" "$busqueda"
        tput sgr0
    fi
    if (( num_programas > 0 )); then
        tput cup $(( filas_disponibles - 2 )) 4; tput setaf 2
        printf "Programa seleccionado: %s" "${programas_filtrados[$((seleccion-1))]}"
        tput sgr0
    fi
}

# Trap para resize
trap 'dibujar_menu' WINCH

# Ejecutar programa
function ejecutar_programa {
    if (( num_programas == 0 )); then return; fi
    local programa="${programas_filtrados[$((seleccion-1))]}"
    clear; tput cup 10 20; tput bold; tput setaf 2
    printf "Ejecutando: %s" "$programa"; tput sgr0
    echo
    if command -v "$programa" &> /dev/null; then
        sleep 0.30; echo "Iniciando $programa..."
        "$programa" &
        sleep 2
    else
        echo "Programa no encontrado: $programa"
        echo "Presiona Enter para continuar..."
        read -r
    fi
    dibujar_menu
}

# Inicializar y activar mouse
dibujar_menu
enable_mouse_reporting

# Bucle principal
while true; do
    IFS= read -rsn1 key1
    redraw=false
    if [[ "$key1" == $'\x1b' ]]; then
        IFS= read -rsn1 -t 0.1 next_char
        if [[ "$next_char" == "[" ]]; then
            IFS= read -rsn1 -t 0.1 third_char
            if [[ "$third_char" == "<" ]]; then
                mouse_data=""
                while read -r -s -n1 -t 0.1 data_char; do
                    mouse_data+="$data_char"
                    if [[ "$data_char" == 'M' || "$data_char" == 'm' ]]; then
                        if [[ "$data_char" == 'M' ]]; then
                            data_part="${mouse_data%[Mm]}"
                            IFS=';' read -r button x_coord y_coord <<< "$data_part"
                            
                            # Lógica para el scroll con la rueda del mouse (fuerza selección visible)
                            if (( button == 64 )); then  # Rueda arriba
                                if (( offset_fila > 0 )); then
                                    (( offset_fila-- ))
                                    seleccion=$(( offset_fila * cuadros_por_fila + 1 ))
                                    if (( seleccion > num_programas )); then seleccion=num_programas; fi
                                    redraw=true
                                fi
                            elif (( button == 65 )); then # Rueda abajo
                                if (( offset_fila + filas_visibles_cuadros < num_filas_cuadros )); then
                                    (( offset_fila++ ))
                                    seleccion=$(( offset_fila * cuadros_por_fila + 1 ))
                                    if (( seleccion > num_programas )); then seleccion=num_programas; fi
                                    redraw=true
                                fi
                            elif (( button == 0 )); then # Clic izquierdo
                                detectar_clic_cuadro "$x_coord" "$y_coord"
                                cuadro_clickeado=$?
                                if (( cuadro_clickeado > 0 )); then
                                    if (( cuadro_clickeado == seleccion )); then
                                        ejecutar_programa
                                    else
                                        seleccion=$cuadro_clickeado
                                        redraw=true
                                    fi
                                fi
                            fi
                            unset IFS
                        fi
                        break
                    fi
                done
            else
                case "$third_char" in
                    "A") # Flecha arriba
                        if (( seleccion > cuadros_por_fila )); then 
                            (( seleccion -= cuadros_por_fila ))
                            ajustar_offset  # Ajuste inmediato para consistencia
                            redraw=true
                        fi
                        ;;
                    "B") # Flecha abajo
                        if (( seleccion <= num_programas - cuadros_por_fila )); then 
                            (( seleccion += cuadros_por_fila ))
                            ajustar_offset  # Ajuste inmediato para consistencia
                            redraw=true
                        fi
                        ;;
                    "C") # Flecha derecha
                        if (( seleccion < num_programas )); then 
                            (( seleccion++ ))
                            ajustar_offset  # Ajuste inmediato para consistencia
                            redraw=true
                        fi
                        ;;
                    "D") # Flecha izquierda
                        if (( seleccion > 1 )); then 
                            (( seleccion-- ))
                            ajustar_offset  # Ajuste inmediato para consistencia
                            redraw=true
                        fi
                        ;;
                esac
            fi
        fi
    elif [[ "$key1" =~ [a-zA-Z0-9_-] ]]; then
        current_time=$(date +%s)
        if (( current_time - last_type_time > 1 )); then busqueda=""; fi
        busqueda+="${key1,,}"
        last_type_time=$current_time
        seleccion=1
        offset_fila=0
        redraw=true
    elif [[ "$key1" == $'\x7f' ]]; then
        if [ -n "$busqueda" ]; then
            busqueda=${busqueda%?}
            last_type_time=$(date +%s)
            seleccion=1
            offset_fila=0
            redraw=true
        fi
    elif [[ "$key1" == $'\x0a' ]] || [[ "$key1" == 'e' ]] || [[ "$key1" == 'E' ]]; then
        ejecutar_programa
    elif [[ "$key1" == $'\x03' ]] || [[ "$key1" == 'q' ]] || [[ "$key1" == 'Q' ]]; then
        break
    fi

    # Redibujar si es necesario
    if $redraw; then
        dibujar_menu
    fi
done
