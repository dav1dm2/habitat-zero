"""Export a review floor plan from the saved Godot scene, without changing it."""
from pathlib import Path
import re
from PIL import Image, ImageDraw, ImageFont

PROJECT = Path(__file__).resolve().parents[3]
SOURCE = PROJECT / "scenes/levels/attis_interior.tscn"
OUT = PROJECT / "docs/visuals/planta-instalacoes-reformulada.png"
scene = SOURCE.read_text()
meshes = {}
for match in re.finditer(r'\[sub_resource type="BoxMesh" id="([^"]+)"\]\n(.*?)(?=\n\[|\Z)', scene, re.S):
    size = re.search(r'size = Vector3\(([^)]+)\)', match[2])
    if size:
        meshes[match[1]] = tuple(map(float, size[1].split(',')))
nodes = {}
for block in re.split(r'(?m)^\[node ', scene)[1:]:
    header, _, body = block.partition('\n')
    name = re.search(r'name="([^"]+)"', header)
    parent = re.search(r'parent="([^"]+)"', header)
    if not name:
        continue
    if not parent:
        key, parent_key = "", None
    else:
        parent_key = "" if parent[1] == "." else parent[1]
        key = (parent_key + "/" if parent_key else "") + name[1]
    transform = re.search(r'transform = Transform3D\(([^)]+)\)', body)
    position = re.search(r'position = Vector3\(([^)]+)\)', body)
    xyz = tuple(map(float, transform[1].split(',')))[-3:] if transform else tuple(map(float, position[1].split(','))) if position else (0, 0, 0)
    ancestor = nodes.get(parent_key, {}).get("xyz", (0, 0, 0))
    xyz = tuple(a + b for a, b in zip(xyz, ancestor))
    mesh = re.search(r'mesh = SubResource\("([^"]+)"\)', body)
    nodes[key] = {"xyz": xyz, "mesh": meshes.get(mesh[1]) if mesh else None}

image = Image.new("RGB", (760, 1020), "#f4f5f1")
draw = ImageDraw.Draw(image)
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
def font(size):
    return ImageFont.truetype(FONT, size)
def point(x, z):
    return (380 + x * 26, 62 + (z + 18) * 26)
def label(words, x, z, size=18, fill="#243b40"):
    draw.multiline_text(point(x, z), words, font=font(size), anchor="mm", align="center", fill=fill, spacing=5)
def rect(x, z, w, d, fill, outline=None, width=1):
    draw.rectangle([point(x, z), point(x + w, z + d)], fill=fill, outline=outline, width=width)

draw.text((380, 24), "ATTIS / INSTALAÇÕES REFORMULADAS", font=font(21), anchor="mm", fill="#243b40")
floors = [
    ("Estrutura/RecepcaoCompacta/Piso/Visual", "#e1e8e4"),
    ("Estrutura/CorredorCentral/Piso/Visual", "#d4dfda"),
    ("Estrutura/Almoxarifado/Piso/Visual", "#e1e8e4"),
    ("Estrutura/AlojamentoCompacto/Piso/Visual", "#e1e8e4"),
    ("Estrutura/Laboratorio/Piso/Visual", "#d9e6e9"),
    ("Estrutura/RecargaSegura/Piso/Visual", "#d7e5d9"),
    ("Estrutura/SalaDeMaquinas/Piso/Visual", "#eee0c7"),
    ("CorredorDosHabitats/Piso/Visual", "#d4dfda"),
]
for name, color in floors:
    node = nodes[name]
    x, _, z = node["xyz"]
    w, _, d = node["mesh"]
    rect(x-w/2, z-d/2, w, d, color)
for key, node in nodes.items():
    mesh = node["mesh"]
    if mesh and mesh[1] >= 3 and (key.startswith("Estrutura/") or key.startswith("CorredorDosHabitats/")):
        x, _, z = node["xyz"]
        rect(x-mesh[0]/2, z-mesh[2]/2, mesh[0], mesh[2], "#435450")
for name in ["PortaHabitat1", "PortaHabitat2", "DoorExit/Porta"]:
    # The entry mesh is a direct resource; prefab geometry is not required here.
    key = name + "/Visual" if name != "DoorExit/Porta" else name
    node = nodes.get(key)
    if node and node["mesh"]:
        x, _, z = node["xyz"]
        w, _, d = node["mesh"]
        rect(x-w/2, z-d/2, w, d, "#6a878b", "#243b40", 2)
label("HABITAT 1", -6, -17.3, 17)
label("HABITAT 2 / FECHADO", 6, -17.3, 15)
label("5 · CORREDOR DOS HABITATS", 0, -14, 17)
label("7 · Máquinas", -5.8, -6.4, 18)
label("Radiação contida nesta sala", -5.8, -5.35, 12)
label("6 · Recarga", -6, -.3, 18)
label("Área segura", -6, .7, 13)
label("3 · Laboratório", 6, -.5, 17)
label("2 · Almoxarifado", -4.8, 5.0, 16)
label("Depósito pessoal", -4.8, 6.1, 13)
label("4 · Aloj.\nBeliche (2)\n4 × 4,4 m", 3.8, 5.2, 14)
label("1 · Recepção\n5,4 × 4,8 m", 0, 11.4, 16)
label("Floresta de Attis / entrada", 0, 15.3, 17)
panel = nodes["PowerPanel"]["xyz"]
px, py = point(panel[0], panel[2])
draw.rectangle((px-10, py-7, px+10, py+7), fill="#b58a39", outline="#435450", width=2)
label("Fusível", panel[0]+.2, panel[2]+1.0, 12)
bx, bz = nodes["Buzzy"]["xyz"][0], nodes["Buzzy"]["xyz"][2]
px, py = point(bx, bz)
draw.ellipse((px-8, py-8, px+8, py+8), fill="#698f9b")
draw.text((px, py), "B", fill="white", font=font(10), anchor="mm")
draw.text((380, 978), "Planta derivada da cena salva · B: Buzzy · sem teto e sem mobiliário decorativo", font=font(12), anchor="mm", fill="#51625e")
OUT.parent.mkdir(parents=True, exist_ok=True)
image.save(OUT)
print(OUT)
