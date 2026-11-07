# dmgbuild settings for IAGO's DMG (ADR-0097). scripts/release.sh passes the paths with -D: app, readme, icon.
# The window is 660×400 with the background of scripts/dmg/background.html; the positions below are icon centres in
# that image, and must match it (the arrows sit between IAGO and Applicazioni, the instructions in the yellow band).
import os.path

app = defines["app"]  # noqa: F821 (dmgbuild provides `defines`)
readme = defines["readme"]  # noqa: F821

format = "UDZO"
filesystem = "HFS+"
files = [app, readme]
symlinks = {"Applicazioni": "/Applications"}
icon = defines["icon"]  # noqa: F821
background = defines["background"]  # noqa: F821
window_rect = ((200, 160), (660, 400))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
show_icon_preview = False
icon_size = 96
text_size = 13
icon_locations = {
    os.path.basename(app): (165, 150),
    "Applicazioni": (495, 150),
    os.path.basename(readme): (96, 306),
}
