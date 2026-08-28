from PIL import Image
from pathlib import Path

folder = Path(r"assets\creatures\chapter_05_modern_world")
original = folder / "original"

for path in original.glob("*.png"):
    img = Image.open(path).convert("RGBA")

    pixels = img.load()
    width, height = img.size

    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]

            # 白色背景透明化
            if r >= 245 and g >= 245 and b >= 245:
                pixels[x, y] = (r, g, b, 0)

    output = folder / path.name
    img.save(output, "PNG")

    print(f"完成: {path.name}")

print("全部去背完成")