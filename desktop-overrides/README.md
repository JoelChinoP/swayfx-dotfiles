# desktop-overrides

Archivos `.desktop` personalizados que anulan las entradas del sistema en
`/usr/share/applications/`. GNU Stow los enlaza en
`~/.local/share/applications/`, que tiene prioridad sobre el directorio global.

## Por qué existe

Las entradas del sistema tienen nombres en inglés, iconos incorrectos o
comandos de lanzamiento que no se ajustan a este entorno (SwayFX/Wayland).
En lugar de parchear `/usr/share/applications/` con `sudo`, se colocan
overrides en el directorio de usuario: XDG los prefiere automáticamente.

## Aplicar manualmente

```bash
# Desde la raíz del repo:
stow -R --no-folding --target "$HOME" -d . desktop-overrides
update-desktop-database ~/.local/share/applications/
```

El Stage 10 del instalador (`scripts/install/stages/10-final.sh`) hace esto
automáticamente junto con el resto de los paquetes Stow.

## Archivos incluidos

| Archivo                              | App                  | Cambio principal                              |
|--------------------------------------|----------------------|-----------------------------------------------|
| `brave-origin-beta.desktop`          | Brave Origin         | Lanza vía `swayfx-browser` con flags Wayland/VAAPI |
| `blueman-manager.desktop`            | Bluetooth            | Nombre en español, keywords en español        |
| `btop.desktop`                       | btop                 | Lanza dentro de Ghostty (`ghostty -e btop`)   |
| `com.brave.Origin.beta.desktop`      | Brave Origin (portal)| Override oculto para portal/default browser   |
| `com.mitchellh.ghostty.desktop`      | Ghostty              | `--gtk-single-instance=true`, nombre español  |
| `io.missioncenter.MissionCenter.desktop` | Mission Center   | Nombre en español, keywords en español        |
| `kvantummanager.desktop`             | Kvantum Manager      | Nombre en español                             |
| `mpv.desktop`                        | mpv                  | Modo pseudo-GUI + MimeTypes multimedia        |
| `network.cycles.wdisplays.desktop`   | wdisplays            | Nombre en español                             |
| `nm-connection-editor.desktop`       | Network Manager      | Nombre en español                             |
| `nwg-look.desktop`                   | nwg-look             | Nombre en español                             |
| `org.gnome.Calculator.desktop`       | Calculadora          | Nombre en español                             |
| `org.gnome.FileRoller.desktop`       | File Roller          | Nombre en español + MimeTypes comprimidos     |
| `org.gnome.Loupe.desktop`            | Loupe                | Nombre en español + MimeTypes imágenes        |
| `org.gnome.Nautilus.desktop`         | Nautilus             | `--new-window` + MimeType directorio          |
| `org.gnome.Papers.desktop`           | Papers               | Nombre en español + MimeTypes PDF/EPUB        |
| `org.gnome.TextEditor.desktop`       | Editor de Texto      | Nombre en español + MimeType texto            |
| `org.pulseaudio.pavucontrol.desktop` | pavucontrol          | Nombre en español                             |
| `satty.desktop`                      | satty                | Nombre en español                             |
| `vesktop.desktop`                    | Discord (Vesktop)    | Nombre en español, `StartupWMClass=Vesktop`   |

## Agregar un nuevo override

1. Copiar el `.desktop` original: `cp /usr/share/applications/foo.desktop desktop-overrides/.local/share/applications/`
2. Editar solo los campos necesarios.
3. Re-aplicar: `stow -R --no-folding --target "$HOME" -d . desktop-overrides && update-desktop-database ~/.local/share/applications/`
